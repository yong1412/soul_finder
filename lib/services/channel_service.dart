import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/channel.dart';

class ChannelService {
  ChannelService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  String get _currentUserUid => _auth.currentUser?.uid ?? '';

  Stream<List<InterestChannel>> watchMyChannels(List<String> interests) async* {
    if (interests.isEmpty) {
      yield [];
      return;
    }

    // Immediately yield placeholders to stop loading spinner
    final placeholders = interests.map((interest) => InterestChannel(
      name: interest,
      description: 'Global chat for $interest lovers',
    )).toList();
    
    yield placeholders;

    // Then stream real data from Firestore
    yield* _firestore
        .collection('channels')
        .snapshots()
        .map((snapshot) {
          final allChannels = snapshot.docs
              .map((doc) => InterestChannel.fromFirestore(doc.data()))
              .toList();

          return interests.map((interest) {
            final existing = allChannels.firstWhere(
              (c) => c.name.toLowerCase() == interest.toLowerCase(),
              orElse: () => InterestChannel(
                name: interest,
                description: 'Global chat for $interest lovers',
              ),
            );
            return existing;
          }).toList();
        })
        .handleError((error) {
          debugPrint('Error watching channels: $error');
          return placeholders;
        });
  }

  Stream<List<ChannelMessage>> watchMessages(String channelName) {
    return _firestore
        .collection('channels')
        .doc(channelName)
        .collection('messages')
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ChannelMessage.fromDocument(doc))
            .toList());
  }

  Future<void> sendMessage({
    required String channelName,
    required String text,
    required String senderName,
    required String senderProfileImage,
  }) async {
    final uid = _currentUserUid;
    if (uid.isEmpty) return;

    final batch = _firestore.batch();
    final channelRef = _firestore.collection('channels').doc(channelName);
    final messageRef = channelRef.collection('messages').doc();

    final message = ChannelMessage(
      id: messageRef.id,
      channelName: channelName,
      senderUid: uid,
      senderName: senderName,
      senderProfileImageBase64: senderProfileImage,
      text: text,
      createdAt: DateTime.now(),
    );

    batch.set(messageRef, message.toFirestore());
    
    // Update channel summary
    batch.set(channelRef, {
      'name': channelName,
      'description': 'Global chat for $channelName lovers',
      'lastMessage': text,
      'lastSenderName': senderName,
      'lastMessageAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await batch.commit();
  }
}
