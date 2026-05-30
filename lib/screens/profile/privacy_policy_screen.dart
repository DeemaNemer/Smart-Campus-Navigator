import 'package:flutter/material.dart';
import '../../config/app_colors.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Privacy Policy')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: const [
          _PolicyHeader(),
          SizedBox(height: 16),
          _PolicySection(
            title: 'What We Collect',
            icon: Icons.wifi_tethering_outlined,
            text:
                'Smart Campus Navigator may collect Wi-Fi RSSI readings, selected destinations, account information, and event interactions needed for positioning, navigation, and campus services.',
          ),
          _PolicySection(
            title: 'How We Use Data',
            icon: Icons.route_outlined,
            text:
                'Wi-Fi signal data is used to estimate indoor position and provide navigation instructions. Search and event data helps show relevant rooms, offices, announcements, and directions.',
          ),
          _PolicySection(
            title: 'Location Transparency',
            icon: Icons.my_location_outlined,
            text:
                'Outdoor location is requested only when live navigation is started. Indoor localization data is used for navigation features described in the graduation project report.',
          ),
          _PolicySection(
            title: 'Account and Email',
            icon: Icons.mark_email_read_outlined,
            text:
                'Email addresses are used for account verification, password reset, Google Sign-In, and event access according to user type. Verification codes expire after a limited time.',
          ),
          _PolicySection(
            title: 'User Control',
            icon: Icons.verified_user_outlined,
            text:
                'Users can view this policy at any time from Profile. The system is designed to keep data use transparent and limited to campus navigation and event functionality.',
          ),
        ],
      ),
    );
  }
}

class _PolicyHeader extends StatelessWidget {
  const _PolicyHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.privacy_tip_outlined, color: AppColors.primary, size: 36),
          SizedBox(height: 12),
          Text(
            'Smart Campus Navigator Privacy Policy',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'This policy summarizes how the app handles data for indoor localization, navigation, account verification, and event announcements.',
            style: TextStyle(color: AppColors.textSecondary, height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _PolicySection extends StatelessWidget {
  final String title;
  final IconData icon;
  final String text;

  const _PolicySection({
    required this.title,
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  text,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
