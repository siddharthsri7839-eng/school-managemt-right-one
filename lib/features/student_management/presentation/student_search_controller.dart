import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/student_repository.dart';

final studentSearchControllerProvider =
    AsyncNotifierProvider<StudentSearchController, List<dynamic>>(
  StudentSearchController.new,
);

class StudentSearchController extends AsyncNotifier<List<dynamic>> {
  final _repository = StudentRepository();

  // The initial state is an empty list
  @override
  FutureOr<List<dynamic>> build() => [];

  // Method to be called from the UI to perform a search
  Future<void> search(String query) async {
    // If the query is empty, clear the results
    if (query.isEmpty) {
      state = const AsyncData([]);
      return;
    }

    // Set state to loading
    state = const AsyncValue.loading();

    // Fetch new data and update the state
    state = await AsyncValue.guard(() {
      return _repository.searchStudents(query: query);
    });
  }
}