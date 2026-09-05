import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class UserModerationStatus {
  final String status; // 'active', 'suspended', 'banned'
  final int reportCount;
  final DateTime? bannedUntil;

  UserModerationStatus({
    required this.status,
    required this.reportCount,
    this.bannedUntil,
  });

  bool get isBanned {
    if (status == 'banned') {
      if (bannedUntil == null) return true;
      return DateTime.now().isBefore(bannedUntil!);
    }
    return false;
  }

  bool get isSuspended {
    if (isBanned) return false;
    return status == 'suspended' || reportCount >= 5;
  }
}

class ReportService {
  static final ReportService _instance = ReportService._internal();
  factory ReportService() => _instance;
  ReportService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  static final Map<String, UserModerationStatus> _moderationCache = {};

  static UserModerationStatus? getModerationStatus(String uid) => _moderationCache[uid];

  static const List<String> reportReasons = [
    '📸 Inappropriate Photos / Profile Image',
    '🎥 Inappropriate Video / Media Content',
    '💬 Offensive / Abusive Speech / Harassment',
    '⚠️ Spam / Scam / Fake Account',
    '❓ Other Reasons',
  ];

  /// Submit a report against a user to the dedicated 'reports' Firestore collection
  Future<void> submitReport({
    required String targetUid,
    required String targetName,
    required String reason,
    String? details,
  }) async {
    final reporterUid = _auth.currentUser?.uid;
    if (reporterUid == null || reporterUid.isEmpty) {
      throw Exception('You must be signed in to submit a report.');
    }

    if (reporterUid == targetUid) {
      throw Exception('You cannot report yourself.');
    }

    final now = DateTime.now();
    final reportDocId = '${reporterUid}_${targetUid}_${now.millisecondsSinceEpoch}';

    final Map<String, dynamic> reportData = {
      'reportId': reportDocId,
      'reporterUid': reporterUid,
      'targetUid': targetUid,
      'targetName': targetName,
      'reason': reason,
      'details': details ?? '',
      'createdAt': FieldValue.serverTimestamp(),
    };

    // 1. Write report directly to dedicated top-level 'reports' collection in Firestore
    await _firestore.collection('reports').doc(reportDocId).set(reportData);
    debugPrint("REPORT SAVED TO DEDICATED 'reports' COLLECTION: $reportDocId");

    // 2. Also keep a backup copy on user's own document
    try {
      await _firestore.collection('users').doc(reporterUid).set({
        'mySentReports': {
          reportDocId: {
            ...reportData,
            'createdAt': now.toIso8601String(),
          },
        },
      }, SetOptions(merge: true));
    } catch (_) {}

    // 3. Evaluate moderation rules (5+ reports -> suspended, 10+ reports from 3+ users -> 3-day ban)
    await _evaluateAndCacheModeration(targetUid);
  }

  Future<void> _evaluateAndCacheModeration(String targetUid) async {
    try {
      final reportsSnapshot = await _firestore
          .collection('reports')
          .where('targetUid', isEqualTo: targetUid)
          .get();

      final totalReports = reportsSnapshot.docs.length;
      final distinctReporters = reportsSnapshot.docs
          .map((doc) => doc.data()['reporterUid'] as String? ?? '')
          .where((id) => id.isNotEmpty)
          .toSet()
          .length;

      String newAccountStatus = 'active';
      DateTime? bannedUntilDate;

      // Rule 2: Ban for 3 days if reported >= 10 times AND by >= 3 distinct users!
      if (totalReports >= 10 && distinctReporters >= 3) {
        newAccountStatus = 'banned';
        bannedUntilDate = DateTime.now().add(const Duration(days: 3));
      }
      // Rule 1: Set to 'suspended' if reported >= 5 times!
      else if (totalReports >= 5) {
        newAccountStatus = 'suspended';
      }

      // Cache moderation status in memory for real-time UI updates
      _moderationCache[targetUid] = UserModerationStatus(
        status: newAccountStatus,
        reportCount: totalReports,
        bannedUntil: bannedUntilDate,
      );

      // Attempt to update target user document in Firestore
      try {
        final Map<String, dynamic> updateData = {
          'reportCount': totalReports,
          'accountStatus': newAccountStatus,
          'updatedAt': FieldValue.serverTimestamp(),
        };

        if (bannedUntilDate != null) {
          updateData['bannedUntil'] = Timestamp.fromDate(bannedUntilDate);
        }

        await _firestore
            .collection('users')
            .doc(targetUid)
            .set(updateData, SetOptions(merge: true));
      } catch (_) {}

      debugPrint("MODERATION EVALUATED FOR $targetUid: Status=$newAccountStatus, Reports=$totalReports, Reporters=$distinctReporters");
    } catch (e) {
      debugPrint("Notice evaluating moderation: $e");
    }
  }
}

Future<void> showReportUserDialog({
  required BuildContext context,
  required String targetUid,
  required String targetName,
}) async {
  String selectedReason = ReportService.reportReasons.first;
  final detailsController = TextEditingController();

  await showDialog(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF1E293B),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                const Icon(Icons.report_problem_outlined, color: Colors.redAccent),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Report $targetName',
                    style: const TextStyle(color: Colors.white, fontSize: 18),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Select a reason for reporting this user:',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  ...ReportService.reportReasons.map((reason) {
                    return RadioListTile<String>(
                      contentPadding: EdgeInsets.zero,
                      activeColor: Colors.redAccent,
                      title: Text(reason, style: const TextStyle(color: Colors.white, fontSize: 13)),
                      value: reason,
                      groupValue: selectedReason,
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() {
                            selectedReason = val;
                          });
                        }
                      },
                    );
                  }).toList(),
                  const SizedBox(height: 10),
                  TextField(
                    controller: detailsController,
                    maxLines: 2,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Additional details (optional)...',
                      hintStyle: const TextStyle(color: Colors.white38),
                      filled: true,
                      fillColor: const Color(0xFF0F172A),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
              ),
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
                icon: const Icon(Icons.flag_outlined, size: 16),
                label: const Text('Submit Report'),
                onPressed: () async {
                  Navigator.pop(dialogContext);
                  try {
                    await ReportService().submitReport(
                      targetUid: targetUid,
                      targetName: targetName,
                      reason: selectedReason,
                      details: detailsController.text.trim(),
                    );
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Report submitted. Thank you for keeping Soul Finder safe!'),
                          backgroundColor: Color(0xFF10B981),
                        ),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Failed to submit report: $e'),
                          backgroundColor: Colors.redAccent,
                        ),
                      );
                    }
                  }
                },
              ),
            ],
          );
        },
      );
    },
  );
}
