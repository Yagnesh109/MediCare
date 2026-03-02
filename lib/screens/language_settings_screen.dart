import 'package:flutter/material.dart';
import 'package:medicare_app/l10n/app_localizations.dart';
import 'package:medicare_app/app.dart';
import 'package:medicare_app/services/app_language_controller.dart';
import 'package:medicare_app/services/user_role_service.dart';
import 'package:medicare_app/services/voice_alert_service.dart';
import 'package:medicare_app/widgets/app_bar_pulse_indicator.dart';
import 'package:medicare_app/widgets/app_navigation_drawer.dart';
import 'package:medicare_app/widgets/chatbot_fab.dart';

class LanguageSettingsScreen extends StatefulWidget {
  const LanguageSettingsScreen({super.key});

  @override
  State<LanguageSettingsScreen> createState() => _LanguageSettingsScreenState();
}

class _LanguageSettingsScreenState extends State<LanguageSettingsScreen> {
  bool _isUpdatingRole = false;

  @override
  void initState() {
    super.initState();
    VoiceAlertService.instance.init();
  }

  Future<void> _changeRole(AppUserRole role) async {
    if (_isUpdatingRole) return;
    setState(() => _isUpdatingRole = true);
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
        setState(() => _isUpdatingRole = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        flexibleSpace: const AppBarPulseBackground(),
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: const Text('Settings'),
        ),
      ),
      drawer: const AppNavigationDrawer(
        currentRoute: MyApp.routeSettings,
      ),
      floatingActionButton: const ChatbotFab(heroTag: 'chatbot_settings'),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Role',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          StreamBuilder<AppUserRole?>(
            stream: UserRoleService.instance.roleStream(),
            builder: (context, snapshot) {
              final selectedRole = snapshot.data;
              return Column(
                children: [
                  RadioListTile<AppUserRole>(
                    value: AppUserRole.patient,
                    groupValue: selectedRole,
                    title: const Text('Patient'),
                    onChanged: _isUpdatingRole
                        ? null
                        : (value) {
                            if (value != null && value != selectedRole) {
                              _changeRole(value);
                            }
                          },
                  ),
                  RadioListTile<AppUserRole>(
                    value: AppUserRole.caregiver,
                    groupValue: selectedRole,
                    title: const Text('Caregiver'),
                    onChanged: _isUpdatingRole
                        ? null
                        : (value) {
                            if (value != null && value != selectedRole) {
                              _changeRole(value);
                            }
                          },
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          const Text(
            'Notifications',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          ValueListenableBuilder<bool>(
            valueListenable: VoiceAlertService.instance.enabledNotifier,
            builder: (context, enabled, _) {
              return SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Voice Alert'),
                subtitle: const Text('Speak reminder message at reminder time'),
                value: enabled,
                onChanged: (value) {
                  VoiceAlertService.instance.setEnabled(value);
                },
              );
            },
          ),
          const SizedBox(height: 16),
          Text(
            l10n.selectLanguage,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          ValueListenableBuilder<Locale>(
            valueListenable: AppLanguageController.instance.localeNotifier,
            builder: (context, locale, _) {
              final selected = locale.languageCode;
              return Column(
                children: [
                  RadioListTile<String>(
                    value: 'en',
                    groupValue: selected,
                    title: Text(l10n.english),
                    onChanged: (v) {
                      if (v != null) {
                        AppLanguageController.instance.setLanguageCode(v);
                      }
                    },
                  ),
                  RadioListTile<String>(
                    value: 'hi',
                    groupValue: selected,
                    title: Text(l10n.hindi),
                    onChanged: (v) {
                      if (v != null) {
                        AppLanguageController.instance.setLanguageCode(v);
                      }
                    },
                  ),
                  RadioListTile<String>(
                    value: 'mr',
                    groupValue: selected,
                    title: Text(l10n.marathi),
                    onChanged: (v) {
                      if (v != null) {
                        AppLanguageController.instance.setLanguageCode(v);
                      }
                    },
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
