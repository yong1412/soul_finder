import 'package:flutter/material.dart';
import '../models/user_profile.dart';
import '../controllers/auth_controller.dart';

class BannedAccountView extends StatelessWidget {
  const BannedAccountView({
    super.key,
    required this.user,
    required this.authController,
  });

  final UserProfile user;
  final AuthController authController;

  String _formatRemainingTime() {
    if (user.bannedUntil == null) return '3 days';
    final remaining = user.bannedUntil!.difference(DateTime.now());
    if (remaining.isNegative) return '0 hours';
    final days = remaining.inDays;
    final hours = remaining.inHours % 24;
    final mins = remaining.inMinutes % 60;
    if (days > 0) {
      return '$days day${days > 1 ? "s" : ""} $hours hr${hours > 1 ? "s" : ""}';
    }
    return '$hours hr${hours > 1 ? "s" : ""} $mins min${mins > 1 ? "s" : ""}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.block_rounded,
                  size: 72,
                  color: Colors.redAccent,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Account Temporarily Banned',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Your account (${user.name}) has been temporarily suspended for 3 days due to multiple community guidelines violation reports.',
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: Colors.white70,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.timer_outlined, color: Colors.orangeAccent),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Ban Expires In',
                          style: TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _formatRemainingTime(),
                          style: const TextStyle(
                            color: Colors.orangeAccent,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 36),
              ElevatedButton.icon(
                onPressed: () => authController.logout(),
                icon: const Icon(Icons.logout),
                label: const Text('Sign Out'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E293B),
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
