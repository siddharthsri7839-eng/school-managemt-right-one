import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/staff_dashboard_repository.dart';

final staffDashboardControllerProvider =
    AsyncNotifierProvider<StaffDashboardController, Map<String, dynamic>>(
  StaffDashboardController.new,
);

class StaffDashboardController extends AsyncNotifier<Map<String, dynamic>> {
  final _repository = StaffDashboardRepository();

  @override
  FutureOr<Map<String, dynamic>> build() {
    return _repository.getDashboardData();
  }
}