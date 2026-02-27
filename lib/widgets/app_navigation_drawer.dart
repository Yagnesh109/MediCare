import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:medicare_app/l10n/app_localizations.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:medicare_app/app.dart';

class AppNavigationDrawer extends StatelessWidget {
  const AppNavigationDrawer({
    super.key,
    required this.currentRoute,
  });

  final String currentRoute;

  Future<void> _logout(BuildContext context) async {
    try {
      await GoogleSignIn().signOut();
    } catch (_) {}
    await FirebaseAuth.instance.signOut();

    if (!context.mounted) {
      return;
    }
    Navigator.pushNamedAndRemoveUntil(
      context,
      MyApp.routeLogin,
      (route) => false,
    );
  }

  void _navigate(BuildContext context, String route) {
    Navigator.pop(context);
    if (route == currentRoute) {
      return;
    }
    Navigator.pushNamedAndRemoveUntil(
      context,
      route,
      (r) => false,
    );
  }

  String _fallbackDisplayName(User? user) {
    final displayName = (user?.displayName ?? '').trim();
    if (displayName.isNotEmpty) {
      return displayName;
    }
    final email = (user?.email ?? '').trim();
    if (email.isNotEmpty && email.contains('@')) {
      return email.split('@').first;
    }
    return 'Patient';
  }

  Widget _profileHeader(BuildContext context, double avatarRadius) {
    final user = FirebaseAuth.instance.currentUser;
    final uid = user?.uid;

    Widget headerContent({
      required Uint8List? imageBytes,
      required String? fallbackPhotoUrl,
      required String name,
    }) {
      final bgImage = imageBytes != null
          ? MemoryImage(imageBytes) as ImageProvider<Object>
          : (fallbackPhotoUrl == null || fallbackPhotoUrl.isEmpty)
              ? null
              : NetworkImage(fallbackPhotoUrl);
      return InkWell(
        borderRadius: BorderRadius.circular(avatarRadius),
        onTap: () => _navigate(context, MyApp.routeProfile),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: avatarRadius,
              backgroundColor: Colors.white,
              backgroundImage: bgImage,
              child: bgImage == null
                  ? Icon(
                      Icons.person,
                      color: const Color(0xFF1565C0),
                      size: avatarRadius,
                    )
                  : null,
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.5,
              ),
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (uid == null || uid.isEmpty) {
      return headerContent(
        imageBytes: null,
        fallbackPhotoUrl: user?.photoURL,
        name: _fallbackDisplayName(user),
      );
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('patients')
          .doc(uid)
          .snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data();
        final base64Image = (data?['profileImageBase64'] ?? '').toString();
        final profileName = (data?['name'] ?? '').toString().trim();

        Uint8List? bytes;
        if (base64Image.isNotEmpty) {
          try {
            bytes = base64Decode(base64Image);
          } catch (_) {
            bytes = null;
          }
        }

        final resolvedName =
            profileName.isEmpty ? _fallbackDisplayName(user) : profileName;
        return headerContent(
          imageBytes: bytes,
          fallbackPhotoUrl: user?.photoURL,
          name: resolvedName,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final drawerWidth = MediaQuery.of(context).size.width * 0.8;
    final avatarDiameter = drawerWidth * 0.2;
    final avatarRadius = avatarDiameter / 2;

    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          Container(
            color: const Color(0xFF1565C0),
            height: MediaQuery.of(context).size.height * 0.2,
            padding: const EdgeInsets.fromLTRB(16, 48, 16, 16),
            child: Align(
              alignment: Alignment.topLeft,
              child: _profileHeader(context, avatarRadius),
            ),
          ),
          ListTile(
            selected: currentRoute == MyApp.routeHome,
            leading: const Icon(Icons.dashboard_outlined),
            title: Text(l10n.dashboard),
            onTap: () => _navigate(context, MyApp.routeHome),
          ),
          ListTile(
            selected: currentRoute == MyApp.routeAdherence,
            leading: const Icon(Icons.bar_chart_outlined),
            title: Text(l10n.adherenceHistory),
            onTap: () => _navigate(context, MyApp.routeAdherence),
          ),
          ListTile(
            selected: currentRoute == MyApp.routeCaregivers,
            leading: const Icon(Icons.people_alt_outlined),
            title: Text(l10n.caregivers),
            onTap: () => _navigate(context, MyApp.routeCaregivers),
          ),
          ListTile(
            selected: currentRoute == MyApp.routeAddMedicine,
            leading: const Icon(Icons.add_circle_outline),
            title: Text(l10n.addMedicine),
            onTap: () => _navigate(context, MyApp.routeAddMedicine),
          ),
          ListTile(
            selected: currentRoute == MyApp.routeSettings,
            leading: const Icon(Icons.settings_outlined),
            title: const Text('Settings'),
            onTap: () => _navigate(context, MyApp.routeSettings),
          ),
          ListTile(
            leading: const Icon(Icons.logout),
            title: Text(l10n.logout),
            onTap: () {
              Navigator.pop(context);
              _logout(context);
            },
          ),
        ],
      ),
    );
  }
}
