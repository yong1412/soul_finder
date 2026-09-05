import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/channel.dart';
import '../models/interest_data.dart';

class ChannelService {
  ChannelService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  String get _currentUserUid => _auth.currentUser?.uid ?? '';

  Stream<List<InterestChannel>> watchMyChannels(List<String> interests) {
    debugPrint("DEBUG: User Interests in app: $interests");

    if (interests.isEmpty) {
      return Stream.value([]);
    }

    final validInterests = interests.take(30).toList();

    return _firestore
        .collection('channels')
        .where(FieldPath.documentId, whereIn: validInterests)
        .snapshots()
        .map((snapshot) {
          final docMap = {
            for (var doc in snapshot.docs)
              doc.id: InterestChannel.fromFirestore(doc.id, doc.data())
          };

          return interests.map((id) {
            final storeChannel = docMap[id];
            return InterestChannel(
              id: id,
              name: InterestData.getLabel(id),
              description: storeChannel?.description ?? 'Global chat for ${InterestData.getLabel(id)}',
              lastMessage: storeChannel?.lastMessage,
              lastSenderName: storeChannel?.lastSenderName,
              lastMessageAt: storeChannel?.lastMessageAt,
            );
          }).toList();
        })
        .handleError((error) {
          debugPrint("Error watching interest channels: $error");
          return interests.map((id) {
            return InterestChannel(
              id: id,
              name: InterestData.getLabel(id),
              description: 'Global chat for ${InterestData.getLabel(id)}',
            );
          }).toList();
        })
        .asBroadcastStream();
  }

  Stream<List<ChannelMessage>> watchMessages(String channelName) {
    return _firestore
        .collection('channels')
        .doc(channelName)
        .collection('messages')
        .orderBy('createdAt', descending: false)
        .limit(100)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ChannelMessage.fromDocument(doc))
            .toList())
        .handleError((error) {
          debugPrint("Error watching channel messages for $channelName: $error");
          return <ChannelMessage>[];
        });
  }

  Future<void> deleteMessage(String channelName, ChannelMessage message) async {
    final uid = _currentUserUid;
    if (uid.isEmpty || message.senderUid != uid) {
      throw Exception('You can only delete your own messages.');
    }

    if (DateTime.now().difference(message.createdAt).inSeconds > 180) {
      throw Exception('Messages can only be deleted within 3 minutes of sending.');
    }

    await _firestore
        .collection('channels')
        .doc(channelName)
        .collection('messages')
        .doc(message.id)
        .delete();
  }

  Future<void> sendMessage({
    required String channelName,
    required String text,
    required String senderName,
    required String senderProfileImage,
    MessageType type = MessageType.text,
    String? mediaUrl,
    String? thumbnailUrl,
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
      type: type,
      mediaUrl: mediaUrl,
      thumbnailUrl: thumbnailUrl,
    );

    batch.set(messageRef, message.toFirestore());
    
    // Update channel summary
    final String lastMessageText = type == MessageType.image 
        ? "Sent a photo 📷" 
        : (type == MessageType.video ? "Sent a video 🎥" : text);

    batch.set(channelRef, {
      'name': channelName,
      'description': 'Global chat for $channelName lovers',
      'lastMessage': lastMessageText,
      'lastSenderName': senderName,
      'lastMessageAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await batch.commit();
  }

  /// Seeds initial interest channels if they don't exist
  Future<void> initializeInterestChannels() async {
    final channels = [
      {
        'id': 'pet_lovers',
        'name': 'Pet Lovers',
        'description': 'A community for people who love animals, pets, and sharing cute moments!',
      },
      {
        'id': 'tech_enthusiasts',
        'name': 'Tech Enthusiasts',
        'description': 'Discussion about latest technology, coding, and gadgets.',
      },
      {
        'id': 'travelers',
        'name': 'Travelers',
        'description': 'Share your travel stories and discover new destinations.',
      }
    ];

    for (final channel in channels) {
      try {
        final docId = channel['id']!;
        final docRef = _firestore.collection('channels').doc(docId);
        final doc = await docRef.get();
        if (!doc.exists) {
          await docRef.set({
            'name': channel['name'],
            'description': channel['description'],
            'lastMessage': 'Welcome to # ${channel['name']}!',
            'lastSenderName': 'System',
            'lastMessageAt': FieldValue.serverTimestamp(),
          });
        }
      } catch (e) {
        // Skip if no permission to initialize (already exists or rules prevent)
        continue;
      }
    }
  }
}
