import 'package:flutter/material.dart';
import 'package:school_erp_staff_app/shared/widgets/main_scaffold.dart';

class StaffDirectoryScreen extends StatelessWidget {
  const StaffDirectoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const MainScaffold(
      body: Center(
        child: Text("Staff Directory Screen"),
      ),
    );
  }
}