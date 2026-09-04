import 'dart:convert';

import 'package:flutter/material.dart';

import '../controllers/auth_controller.dart';
import '../models/interest_data.dart';
import '../services/match_service.dart';
import '../services/profile_stats_service.dart';
import 'chat_list_view.dart';
import 'nearby_users_list_view.dart';
import 'profile/edit_profile_view.dart';
import 'profile_viewers_view.dart';

class UserDashboardView extends StatelessWidget {
  const UserDashboardView({
    super.key,
    required this.controller,
  });

  final AuthController controller;

  static final MatchService _matchService = MatchService();
  static final ProfileStatsService _profileStatsService =
  ProfileStatsService();

  Future<void> _confirmSignOut(
      BuildContext context,
      ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: const Text('Sign Out'),
          content: const Text(
            'Are you sure you want to sign out?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: const Text('Sign Out'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await controller.logout();
    }
  }

  Future<void> _showChangePasswordDialog(
      BuildContext context,
      ) async {
    final passwordController = TextEditingController();
    final confirmPasswordController = TextEditingController();

    bool hidePassword = true;
    bool hideConfirmPassword = true;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1E293B),
              title: const Row(
                children: [
                  Icon(
                    Icons.lock_reset,
                    color: Color(0xFF3B82F6),
                  ),
                  SizedBox(width: 10),
                  Text('Change Password'),
                ],
              ),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Enter your new password below.',
                      style: TextStyle(
                        color: Colors.white60,
                      ),
                    ),

                    const SizedBox(height: 20),

                    // New Password
                    TextField(
                      controller: passwordController,
                      obscureText: hidePassword,
                      decoration: InputDecoration(
                        labelText: 'New Password',
                        prefixIcon: const Icon(
                          Icons.lock_outline,
                        ),
                        suffixIcon: IconButton(
                          onPressed: () {
                            setDialogState(() {
                              hidePassword = !hidePassword;
                            });
                          },
                          icon: Icon(
                            hidePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                        filled: true,
                        fillColor: const Color(0xFF0F172A),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Confirm New Password
                    TextField(
                      controller: confirmPasswordController,
                      obscureText: hideConfirmPassword,
                      decoration: InputDecoration(
                        labelText: 'Confirm New Password',
                        prefixIcon: const Icon(
                          Icons.lock_reset_outlined,
                        ),
                        suffixIcon: IconButton(
                          onPressed: () {
                            setDialogState(() {
                              hideConfirmPassword =
                              !hideConfirmPassword;
                            });
                          },
                          icon: Icon(
                            hideConfirmPassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                        filled: true,
                        fillColor: const Color(0xFF0F172A),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    passwordController.dispose();
                    confirmPasswordController.dispose();

                    Navigator.pop(dialogContext);
                  },
                  child: const Text('Cancel'),
                ),

                FilledButton(
                  onPressed: () async {
                    final password =
                        passwordController.text;

                    final confirmPassword =
                        confirmPasswordController.text;

                    // Password minimum length
                    if (password.length < 8) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Password must contain at least 8 characters.',
                          ),
                        ),
                      );
                      return;
                    }

                    // Password strength validation
                    if (!RegExp(r'[A-Z]').hasMatch(password) ||
                        !RegExp(r'[0-9]').hasMatch(password)) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Password must contain at least one uppercase letter and one number.',
                          ),
                        ),
                      );
                      return;
                    }

                    // Confirm password
                    if (password != confirmPassword) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Passwords do not match.',
                          ),
                        ),
                      );
                      return;
                    }

                    final success =
                    await controller.changePassword(
                      password,
                    );

                    if (!context.mounted) {
                      return;
                    }

                    if (success) {
                      Navigator.pop(dialogContext);

                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Password changed successfully.',
                          ),
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            controller.errorMessage ??
                                'Unable to change password.',
                          ),
                        ),
                      );
                    }
                  },
                  child: const Text(
                    'Change Password',
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _confirmDelete(
      BuildContext context,
      ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: const Text(
            'Delete Account?',
            style: TextStyle(
              color: Colors.redAccent,
            ),
          ),
          content: const Text(
            'This will permanently delete your Soul Finder account '
                'and profile information. This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      final success =
      await controller.deleteAccount();

      if (!context.mounted) {
        return;
      }

      if (!success &&
          controller.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              controller.errorMessage!,
            ),
          ),
        );
      }
    }
  }

  Future<void> _showAccountMenu(
      BuildContext context,
      ) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: const Color(0xFF1E293B),
      builder: (bottomSheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ListTile(
                title: Text(
                  'Account Settings',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              // Change Password
              ListTile(
                leading: const Icon(
                  Icons.lock_reset,
                  color: Color(0xFF3B82F6),
                ),
                title: const Text(
                  'Change Password',
                ),
                subtitle: const Text(
                  'Update your account password',
                ),
                trailing: const Icon(
                  Icons.chevron_right,
                  color: Colors.white54,
                ),
                onTap: () {
                  Navigator.pop(
                    bottomSheetContext,
                  );

                  _showChangePasswordDialog(
                    context,
                  );
                },
              ),

              Divider(
                color: Colors.white.withValues(
                  alpha: 0.05,
                ),
                height: 1,
              ),

              // Sign Out
              ListTile(
                leading: const Icon(
                  Icons.logout,
                  color: Colors.orangeAccent,
                ),
                title: const Text('Sign Out'),
                subtitle: const Text(
                  'Sign out from your Soul Finder account',
                ),
                onTap: () {
                  Navigator.pop(
                    bottomSheetContext,
                  );

                  _confirmSignOut(context);
                },
              ),

              Divider(
                color: Colors.white.withValues(
                  alpha: 0.05,
                ),
                height: 1,
              ),

              // Delete Account
              ListTile(
                leading: Icon(
                  Icons.delete_forever_outlined,
                  color: Theme.of(context)
                      .colorScheme
                      .error,
                ),
                title: Text(
                  'Delete Account',
                  style: TextStyle(
                    color: Theme.of(context)
                        .colorScheme
                        .error,
                  ),
                ),
                subtitle: const Text(
                  'Permanently delete your account and profile',
                ),
                onTap: () {
                  Navigator.pop(
                    bottomSheetContext,
                  );

                  _confirmDelete(context);
                },
              ),

              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openEditProfile(
      BuildContext context,
      ) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) {
          return EditProfileView(
            controller: controller,
          );
        },
      ),
    );
  }

  void _openMatches(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: const Text('My Matches'),
            centerTitle: true,
          ),
          body: ChatListView(
            authController: controller,
          ),
        ),
      ),
    );
  }

  void _openNearYou(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: const Text('Near You'),
            centerTitle: true,
          ),
          body: const NearbyUsersListView(),
        ),
      ),
    );
  }

  void _openProfileViews(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProfileViewersView(),
      ),
    );
  }

  Widget _buildStatItem({
    required Stream<int> stream,
    required String label,
    required VoidCallback onTap,
  }) {
    return StreamBuilder<int>(
      stream: stream,
      initialData: 0,
      builder: (context, snapshot) {
        return Semantics(
          button: true,
          label: 'Open $label list',
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    snapshot.hasError ? '—' : '${snapshot.data ?? 0}',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        label,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Colors.white54,
                        ),
                      ),
                      const SizedBox(width: 2),
                      const Icon(
                        Icons.chevron_right,
                        size: 15,
                        color: Colors.white38,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme =
        Theme.of(context).colorScheme;

    final user = controller.currentUser;

    if (user == null) {
      return const Center(
        child: Text(
          'User profile not found.',
        ),
      );
    }

    final firstLetter =
    user.name.trim().isEmpty
        ? '?'
        : user.name
        .trim()[0]
        .toUpperCase();

    // Profile picture
    ImageProvider<Object>? profileImage;

    if (user.profileImageBase64.isNotEmpty) {
      try {
        profileImage = MemoryImage(
          base64Decode(
            user.profileImageBase64,
          ),
        );
      } catch (_) {
        profileImage = null;
      }
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.center,
        children: [

          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  theme.primary,
                  theme.secondary,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: CircleAvatar(
              radius: 50,
              backgroundColor:
              const Color(0xFF1E293B),
              backgroundImage: profileImage,
              child: profileImage == null
                  ? Text(
                firstLetter,
                style: const TextStyle(
                  fontSize: 44,
                  fontWeight:
                  FontWeight.bold,
                  color:
                  Colors.white70,
                ),
              )
                  : null,
            ),
          ),

          const SizedBox(height: 16),

          Text(
            '${user.name}, ${user.age}',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 4),

          Text(
            user.bio.trim().isEmpty
                ? 'Looking for deep connections'
                : user.bio,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: theme.primary,
              fontSize: 16,
            ),
          ),

          const SizedBox(height: 30),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              vertical: 20,
              horizontal: 10,
            ),
            decoration: BoxDecoration(
              color: theme.surface,
              borderRadius:
              BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    stream: _profileStatsService.watchMatchCount(),
                    label: 'Matches',
                    onTap: () => _openMatches(context),
                  ),
                ),

                Container(
                  width: 1,
                  height: 45,
                  color: Colors.white.withValues(
                    alpha: 0.10,
                  ),
                ),

                Expanded(
                  child: _buildStatItem(
                    stream: _matchService
                        .watchCandidates()
                        .map((candidates) => candidates.length),
                    label: 'Near You',
                    onTap: () => _openNearYou(context),
                  ),
                ),

                Container(
                  width: 1,
                  height: 45,
                  color: Colors.white.withValues(
                    alpha: 0.10,
                  ),
                ),

                Expanded(
                  child: _buildStatItem(
                    stream: _profileStatsService.watchProfileViewCount(),
                    label: 'Views',
                    onTap: () => _openProfileViews(context),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Height & Weight Card (if specified)
          if (user.heightCm != null || user.weightKg != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: theme.surface,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  if (user.heightCm != null)
                    Expanded(
                      child: Row(
                        children: [
                          const Icon(Icons.height, color: Color(0xFF38BDF8)),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Height', style: TextStyle(color: Colors.white60, fontSize: 12)),
                              const SizedBox(height: 2),
                              Text(
                                '${user.heightCm!.toStringAsFixed(0)} cm',
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  if (user.heightCm != null && user.weightKg != null)
                    Container(width: 1, height: 36, color: Colors.white12),
                  if (user.weightKg != null)
                    Expanded(
                      child: Row(
                        children: [
                          const SizedBox(width: 12),
                          const Icon(Icons.monitor_weight_outlined, color: Color(0xFF10B981)),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Weight', style: TextStyle(color: Colors.white60, fontSize: 12)),
                              const SizedBox(height: 2),
                              Text(
                                '${user.weightKg!.toStringAsFixed(0)} kg',
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: theme.surface,
              borderRadius:
              BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                // Interests
                Row(
                  children: [
                    Icon(
                      Icons.interests_outlined,
                      color: theme.primary,
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'Interests',
                      style: TextStyle(
                        color: Colors.white60,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children:
                  user.interests.map((interestId) {
                    return Chip(
                      label: Text(InterestData.getLabel(interestId)),
                      backgroundColor:
                      theme.primary.withValues(
                        alpha: 0.12,
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          Container(
            decoration: BoxDecoration(
              color: theme.surface,
              borderRadius:
              BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                // Edit Profile
                ListTile(
                  leading: Container(
                    padding:
                    const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: theme.secondary
                          .withValues(
                        alpha: 0.1,
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.edit,
                      color: theme.secondary,
                    ),
                  ),
                  title: const Text(
                    'Edit Profile',
                  ),
                  subtitle: const Text(
                    'Update your personal information',
                  ),
                  trailing: const Icon(
                    Icons.chevron_right,
                    color: Colors.white54,
                  ),
                  onTap: () {
                    _openEditProfile(
                      context,
                    );
                  },
                ),

                Divider(
                  color: Colors.white.withValues(
                    alpha: 0.05,
                  ),
                  height: 1,
                ),

                // Account Settings
                ListTile(
                  leading: Container(
                    padding:
                    const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white
                          .withValues(
                        alpha: 0.06,
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.manage_accounts_outlined,
                      color: Colors.white70,
                    ),
                  ),
                  title: const Text(
                    'Account Settings',
                  ),
                  subtitle: const Text(
                    'Password, sign out and account deletion',
                  ),
                  trailing: const Icon(
                    Icons.chevron_right,
                    color: Colors.white54,
                  ),
                  onTap: () {
                    _showAccountMenu(
                      context,
                    );
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
