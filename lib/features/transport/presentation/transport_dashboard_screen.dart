import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../shared/widgets/main_scaffold.dart';
import 'transport_providers.dart';
import 'package:school_erp_staff_app/shared/widgets/shimmer_loading.dart';

class TransportDashboardScreen extends ConsumerStatefulWidget {
  const TransportDashboardScreen({super.key});

  @override
  ConsumerState<TransportDashboardScreen> createState() => _TransportDashboardScreenState();
}

class _TransportDashboardScreenState extends ConsumerState<TransportDashboardScreen> {
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(transportDashboardControllerProvider);
    final controller = ref.read(transportDashboardControllerProvider.notifier);

    return MainScaffold(
      title: 'Transport Management',
      body: RefreshIndicator(
        onRefresh: () => controller.fetchDashboardData(refresh: true),
        child: _buildBody(state, controller),
      ),
    );
  }

  Widget _buildBody(TransportDashboardState state, TransportDashboardController controller) {
    if (state.isLoading && state.data == null) {
      return SkeletonLoaders.dashboard();
    }

    if (state.errorMessage != null && state.data == null) {
      return ListView(
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.3),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.redAccent),
                const SizedBox(height: 16),
                Text(state.errorMessage!, style: const TextStyle(color: Colors.redAccent)),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => controller.fetchDashboardData(refresh: true),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ],
      );
    }

    if (state.data == null) {
      return const Center(child: Text('No data available.'));
    }

    final data = state.data!;

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSummaryCards(data),
          const SizedBox(height: 24),
          _buildVehicleInventoryTable(data),
          const SizedBox(height: 24),
          _buildLiveFleetTrackingPlaceholder(data),
          const SizedBox(height: 24),
          _buildRecentRouteAlerts(data),
        ],
      ),
    );
  }

  Widget _buildSummaryCards(Map<String, dynamic> data) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                title: 'Total Vehicles',
                value: '${data['totalVehicles']}',
                subtext: 'Fleet count',
                icon: Icons.directions_bus_outlined,
                color: Colors.indigo,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildStatCard(
                title: 'Active Routes',
                value: '${data['activeRoutes']}',
                subtext: 'Ongoing paths',
                icon: Icons.route_outlined,
                color: Colors.orange,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                title: 'Students',
                value: '${data['studentsUsingTransport']}',
                subtext: 'Using transport',
                icon: Icons.people_outline,
                color: Colors.purple,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildStatCard(
                title: 'On Duty',
                value: '${data['vehiclesOnDuty']}',
                subtext: 'Tracking enabled',
                icon: Icons.schedule_outlined,
                color: Colors.blue,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required String subtext,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withValues(alpha: 0.1), color.withValues(alpha: 0.02)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min, // Hug content vertically
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(icon, size: 14, color: color),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade800,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtext,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey.shade600,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildVehicleInventoryTable(Map<String, dynamic> data) {
    final inventory = data['inventoryVehicles'] as List<dynamic>? ?? [];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Vehicle Inventory & Status',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.grey.shade800),
              ),
              TextButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.add, size: 16, color: Colors.orange),
                label: const Text('Add', style: TextStyle(color: Colors.orange)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (inventory.isEmpty)
            Text('No vehicles found.', style: TextStyle(color: Colors.grey.shade500))
          else
            ...inventory.map((vehicle) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(vehicle['vehicle_number'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text('IN SERVICE', style: TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.person, size: 14, color: Colors.grey.shade500),
                          const SizedBox(width: 4),
                          Text(vehicle['driver_name'] ?? 'No Driver', style: TextStyle(color: Colors.grey.shade700, fontSize: 12)),
                          const Spacer(),
                          Icon(Icons.people, size: 14, color: Colors.grey.shade500),
                          const SizedBox(width: 4),
                          Text('${vehicle['capacity'] ?? 0} Seater', style: TextStyle(color: Colors.grey.shade700, fontSize: 12)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.route, size: 14, color: Colors.grey.shade500),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              vehicle['route_name'],
                              style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      )
                    ],
                  ),
                ),
              );
            }).toList(),
        ],
      ),
    );
  }

  Widget _buildLiveFleetTrackingPlaceholder(Map<String, dynamic> data) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Live Fleet Tracking',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.grey.shade800),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.circle, color: Colors.white, size: 8),
                      const SizedBox(width: 4),
                      Text('${data['vehiclesOnDuty']} Online', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                    ],
                  ),
                )
              ],
            ),
          ),
          SizedBox(
            height: 150,
            width: double.infinity,
            child: ClipRRect(
              borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(16), bottomRight: Radius.circular(16)),
              child: Builder(
                builder: (context) {
                  final locations = data['liveLocations'] as List<dynamic>? ?? [];
                  final points = <LatLng>[];
                  final markers = <Marker>[];

                  for (var loc in locations) {
                    final lat = double.tryParse(loc['latitude']?.toString() ?? '');
                    final lng = double.tryParse(loc['longitude']?.toString() ?? '');
                    if (lat != null && lng != null) {
                      final point = LatLng(lat, lng);
                      points.add(point);
                      markers.add(
                        Marker(
                          point: point,
                          width: 40,
                          height: 40,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade600,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.2),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: const Icon(Icons.directions_bus, color: Colors.white, size: 14),
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                  }

                  CameraFit? cameraFit;
                  LatLng initialCenter = const LatLng(21.2514, 81.6296);

                  if (points.isNotEmpty) {
                    if (points.length == 1) {
                      initialCenter = points.first;
                    } else {
                      cameraFit = CameraFit.bounds(
                        bounds: LatLngBounds.fromPoints(points),
                        padding: const EdgeInsets.all(24.0),
                      );
                    }
                  }

                  return FlutterMap(
                    options: MapOptions(
                      initialCenter: initialCenter,
                      initialZoom: 12.0,
                      initialCameraFit: cameraFit,
                      interactionOptions: const InteractionOptions(
                        flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                      ),
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.schoolerp.staffapp',
                      ),
                      if (markers.isNotEmpty)
                        MarkerLayer(markers: markers),
                    ],
                  );
                },
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildRecentRouteAlerts(Map<String, dynamic> data) {
    final alerts = data['recentAlerts'] as List<dynamic>? ?? [];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.red.shade400, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Recent Route Alerts',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.grey.shade800),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Text('DEMO DATA', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.orange.shade700)),
              )
            ],
          ),
          const SizedBox(height: 16),
          if (alerts.isEmpty)
            Text('No recent alerts.', style: TextStyle(color: Colors.grey.shade500))
          else
            ...alerts.map((alert) {
              IconData icon;
              Color color;
              switch (alert['type']) {
                case 'danger':
                  icon = Icons.schedule;
                  color = Colors.red;
                  break;
                case 'warning':
                  icon = Icons.directions;
                  color = Colors.orange;
                  break;
                case 'success':
                  icon = Icons.check_circle;
                  color = Colors.green;
                  break;
                default:
                  icon = Icons.info;
                  color = Colors.blue;
              }

              return Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, color: color, size: 16),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(alert['title'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          const SizedBox(height: 2),
                          Text(
                            alert['desc'],
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            alert['time'],
                            style: TextStyle(color: Colors.grey.shade400, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
        ],
      ),
    );
  }
}
