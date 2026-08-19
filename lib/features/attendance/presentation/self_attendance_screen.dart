import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:intl/intl.dart';
import 'package:dio/dio.dart';
import 'package:safe_device/safe_device.dart';
import 'package:timezone/timezone.dart' as tz;
import '../../../core/api/api_client.dart';
import '../../../core/storage/secure_storage_service.dart';
import '../data/attendance_repository.dart';
import 'package:school_erp_staff_app/shared/widgets/shimmer_loading.dart';
import 'attendance_providers.dart';

class SelfAttendanceScreen extends ConsumerStatefulWidget {
  const SelfAttendanceScreen({super.key});

  @override
  ConsumerState<SelfAttendanceScreen> createState() => _SelfAttendanceScreenState();
}

class _SelfAttendanceScreenState extends ConsumerState<SelfAttendanceScreen> {
  bool _isLoading = true;
  bool _isPunching = false;
  Map<String, dynamic>? _attendanceData;
  Map<String, dynamic>? _settingsData;
  String? _errorMessage;
  Timer? _timer;
  Duration _elapsedTime = Duration.zero;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _fetchStatus();
  }

  Future<void> _fetchStatus() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final dio = ref.read(apiClientProvider).dio;
      final response = await dio.get('/staff/self-attendance/status');

      if (response.statusCode == 200 && response.data['status'] == 'success') {
        dynamic rawData = response.data['data'];
        dynamic rawSettings = response.data['school_settings'];

        setState(() {
          _attendanceData = (rawData is Map<String, dynamic>) ? rawData : null;
          _settingsData = (rawSettings is Map<String, dynamic>) ? rawSettings : null;
          _isLoading = false;
        });
        _startTimerIfNeeded();
      } else {
        setState(() {
          _errorMessage = "Failed to load attendance status.";
          _isLoading = false;
        });
      }
    } catch (e) {
      if (e is DioException) {
        setState(() {
          _errorMessage = e.response?.data?['message'] ?? e.message ?? "Network Error";
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _startTimerIfNeeded() {
    _timer?.cancel();
    if (_attendanceData != null && _attendanceData!['punch_in_time'] != null && _attendanceData!['punch_out_time'] == null) {
      final punchInStr = _attendanceData!['punch_in_time'];
      if (punchInStr == null) return;

      // Compute elapsed time in UTC so it's correct even if the device clock is
      // in a different timezone than the school / server.
      final punchInUtc = DateTime.parse(punchInStr).toUtc();
      setState(() {
        _elapsedTime = DateTime.now().toUtc().difference(punchInUtc);
      });
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) return;
        setState(() {
          _elapsedTime = DateTime.now().toUtc().difference(punchInUtc);
        });
      });
    } else {
      if (mounted) {
        setState(() {
          _elapsedTime = Duration.zero;
        });
      }
    }
  }

  /// Formats a UTC ISO-8601 punch timestamp in the school's timezone (sent by
  /// the backend), falling back to the device timezone if it's unavailable.
  String _formatInSchoolTz(String? iso, {String pattern = 'hh:mm a'}) {
    if (iso == null) return '--:--';
    try {
      final utc = DateTime.parse(iso).toUtc();
      final tzName = _settingsData?['timezone'] as String?;
      if (tzName != null && tzName.isNotEmpty) {
        final location = tz.getLocation(tzName);
        return DateFormat(pattern).format(tz.TZDateTime.from(utc, location));
      }
      return DateFormat(pattern).format(utc.toLocal());
    } catch (_) {
      return '--:--';
    }
  }

  /// Returns false (and shows a message) if the device has Developer Options
  /// enabled or is rooted — both let users fake GPS / tamper with the app.
  Future<bool> _passesDeviceIntegrityCheck() async {
    try {
      final devModeOn = await SafeDevice.isDevelopmentModeEnable;
      final isRooted = await SafeDevice.isJailBroken;

      if (devModeOn || isRooted) {
        if (mounted) {
          final reason = isRooted
              ? 'a rooted device'
              : 'Developer Mode (Developer Options)';
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Attendance is blocked on $reason. Please turn it off in your phone settings and try again.'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ));
        }
        return false;
      }
      return true;
    } catch (_) {
      // If the integrity check itself can't run, don't hard-block the user;
      // the server still rejects mocked GPS as a backstop.
      return true;
    }
  }

  Future<bool> _handleLocationPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Location services are disabled. Please enable the services')));
      }
      return false;
    }
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Location permissions are denied')));
        }
        return false;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Location permissions are permanently denied, we cannot request permissions. Please open OS settings.')));
      }
      return false;
    }
    return true;
  }

  Future<void> _handlePunchAction() async {
    setState(() {
      _isPunching = true;
    });

    // Block punching from a tampered device — developer mode enabled or rooted.
    // These are on-device checks (no Play Services), so they also work on
    // sideloaded installs without the Play Store.
    if (!await _passesDeviceIntegrityCheck()) {
      setState(() { _isPunching = false; });
      return;
    }

    double? lat;
    double? lng;
    double? accuracy;
    bool isMocked = false;

    // Only fetch GPS if school requires it
    final geolocationEnabled = _settingsData?['geolocation_enabled'] ?? false;

    if (geolocationEnabled == 1 || geolocationEnabled == true || geolocationEnabled == '1') {
      final hasPermission = await _handleLocationPermission();
      if (!hasPermission) {
        setState(() { _isPunching = false; });
        return;
      }

      try {
        Position position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.best);

        // Block GPS spoofing via mock-location apps / developer "set location".
        if (position.isMocked) {
          setState(() { _isPunching = false; });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Mock/fake location detected. Please turn off developer location spoofing to punch.'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 4),
            ));
          }
          return;
        }

        lat = position.latitude;
        lng = position.longitude;
        accuracy = position.accuracy;
        isMocked = position.isMocked;
      } catch (e) {
        setState(() { _isPunching = false; });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Failed to get precise location.')));
        }
        return;
      }
    }

    try {
      final deviceUuid = await SecureStorageService().getDeviceUuid();
      final dio = ref.read(apiClientProvider).dio;
      final response = await dio.post('/staff/self-attendance/punch', data: {
        'latitude': lat,
        'longitude': lng,
        'accuracy': accuracy,
        'is_mocked': isMocked,
        'device_uuid': deviceUuid,
      });

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(response.data['message'] ?? 'Action Successful!'),
            backgroundColor: Colors.green,
          ));
        }
        _fetchStatus(); // Refresh the UI state
      }
    } catch (e) {
      if (e is DioException) {
        final errorMsg = e.response?.data?['message'] ?? 'API Error occurred';
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(errorMsg),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ));
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('An unexpected error occurred: $e'),
            backgroundColor: Colors.red,
          ));
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _isPunching = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('My Attendance'), centerTitle: true),
        body: SkeletonLoaders.dashboard(),
      );
    }

    // Determine current logical state
    bool isPunchedIn = _attendanceData != null;
    bool isPunchedOut = isPunchedIn && _attendanceData!['punch_out_time'] != null;
    
    String statusText = "Not Punched In";
    Color statusColor = Colors.grey;
    String actionLabel = "PUNCH IN";
    IconData actionIcon = Icons.login;
    Color actionColor = Colors.teal;
    bool actionDisabled = false;

    if (isPunchedOut) {
      statusText = "Completed for Today";
      statusColor = Colors.blue;
      actionLabel = "DONE";
      actionIcon = Icons.done_all;
      actionColor = Colors.grey;
      actionDisabled = true;
    } else if (isPunchedIn) {
      statusText = "Punched In";
      statusColor = Colors.green;
      actionLabel = "PUNCH OUT";
      actionIcon = Icons.logout;
      actionColor = Colors.orange;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Attendance'),
        centerTitle: true,
      ),
      body: _errorMessage != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(_errorMessage!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16)),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _fetchStatus,
                    child: const Text('Retry'),
                  )
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _fetchStatus,
              child: ListView(
                padding: const EdgeInsets.all(24.0),
                children: [
                  // Status Card
                  Container(
                    padding: const EdgeInsets.all(24.0),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        )
                      ],
                    ),
                    child: Column(
                      children: [
                        Text(
                          DateFormat('EEEE, MMMM d, y').format(DateTime.now()),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: Text(
                            statusText.toUpperCase(),
                            style: TextStyle(
                              color: statusColor,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        if (isPunchedIn && !isPunchedOut) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.blue.withOpacity(0.1)),
                            ),
                            child: Column(
                              children: [
                                const Text('CURRENT SHIFT TIME', style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                                const SizedBox(height: 8),
                                Text(
                                  '${_elapsedTime.inHours.toString().padLeft(2, '0')}:${(_elapsedTime.inMinutes % 60).toString().padLeft(2, '0')}:${(_elapsedTime.inSeconds % 60).toString().padLeft(2, '0')}',
                                  style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.blue, letterSpacing: 3, fontFamily: 'monospace'),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],
                        if (isPunchedIn) ...[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Punch In:', style: TextStyle(color: Colors.grey)),
                              Text(
                                _formatInSchoolTz(_attendanceData!['punch_in_time']),
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              )
                            ],
                          ),
                          const Divider(height: 24),
                        ],
                        if (isPunchedOut) ...[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Punch Out:', style: TextStyle(color: Colors.grey)),
                              Text(
                                _formatInSchoolTz(_attendanceData!['punch_out_time']),
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              )
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 48),

                  // Action Button
                  if (!actionDisabled)
                    Center(
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            height: 180,
                            width: 180,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: actionColor.withOpacity(0.1),
                            ),
                          ),
                          Container(
                            height: 150,
                            width: 150,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: actionColor.withOpacity(0.2),
                            ),
                          ),
                          Material(
                            color: actionColor,
                            shape: const CircleBorder(),
                            elevation: 8,
                            child: InkWell(
                              onTap: _isPunching ? null : _handlePunchAction,
                              customBorder: const CircleBorder(),
                              child: Container(
                                height: 120,
                                width: 120,
                                alignment: Alignment.center,
                                child: _isPunching
                                    ? const CircularProgressIndicator(color: Colors.white)
                                    : Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(actionIcon, size: 36, color: Colors.white),
                                          const SizedBox(height: 8),
                                          Text(
                                            actionLabel,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                        ],
                                      ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  if (actionDisabled)
                    const Center(
                      child: Text(
                        "You're all set for today!",
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                    
                  const SizedBox(height: 32),
                  
                  // Guidelines
                  if (_settingsData != null && !actionDisabled)
                    Card(
                      elevation: 0,
                      color: Colors.blue.withOpacity(0.05),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.info_outline, color: Colors.blue, size: 20),
                                SizedBox(width: 8),
                                Text('Attendance Guidelines', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                              ],
                            ),
                            const SizedBox(height: 12),
                            if ((_settingsData!['geolocation_enabled'] == 1 || _settingsData!['geolocation_enabled'] == true || _settingsData!['geolocation_enabled'] == '1'))
                              const Padding(
                                padding: EdgeInsets.only(bottom: 8.0),
                                child: Row(
                                  children: [
                                    Icon(Icons.location_on, size: 16, color: Colors.grey),
                                    SizedBox(width: 8),
                                    Expanded(child: Text('You must be within the school premises to punch in/out.', style: TextStyle(fontSize: 13))),
                                  ],
                                ),
                              ),
                            if (!isPunchedIn && _settingsData!['punch_in_start'] != null)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8.0),
                                child: Row(
                                  children: [
                                    const Icon(Icons.access_time, size: 16, color: Colors.grey),
                                    const SizedBox(width: 8),
                                    Expanded(child: Text('Allowed Punch In: ${DateFormat('hh:mm a').format(DateFormat('HH:mm').parse(_settingsData!['punch_in_start']))} - ${DateFormat('hh:mm a').format(DateFormat('HH:mm').parse(_settingsData!['punch_in_end']))}', style: const TextStyle(fontSize: 13))),
                                  ],
                                ),
                              ),
                            if (isPunchedIn && !isPunchedOut && _settingsData!['punch_out_start'] != null)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8.0),
                                child: Row(
                                  children: [
                                    const Icon(Icons.access_time, size: 16, color: Colors.grey),
                                    const SizedBox(width: 8),
                                    Expanded(child: Text('Allowed Punch Out: ${DateFormat('hh:mm a').format(DateFormat('HH:mm').parse(_settingsData!['punch_out_start']))} - ${DateFormat('hh:mm a').format(DateFormat('HH:mm').parse(_settingsData!['punch_out_end']))}', style: const TextStyle(fontSize: 13))),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}
