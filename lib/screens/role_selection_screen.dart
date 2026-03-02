import 'package:flutter/material.dart';
import 'package:medicare_app/app.dart';
import 'package:medicare_app/services/user_role_service.dart';

class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  bool _isSaving = false;

  Future<void> _selectRole(AppUserRole role) async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    try {
      await UserRoleService.instance.setCurrentRole(role);
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(
        context,
        role == AppUserRole.caregiver
            ? MyApp.routeCaregiverDashboard
            : MyApp.routeHome,
        (route) => false,
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Select Role')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Choose how you want to use the app for this login',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _isSaving ? null : () => _selectRole(AppUserRole.patient),
              icon: const Icon(Icons.person_outline),
              label: const Text('Patient'),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed:
                  _isSaving ? null : () => _selectRole(AppUserRole.caregiver),
              icon: const Icon(Icons.groups_outlined),
              label: const Text('Caregiver'),
            ),
          ],
        ),
      ),
    );
  }
}
