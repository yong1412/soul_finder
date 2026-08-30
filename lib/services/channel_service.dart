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

  Stream<List<InterestChannel>> watchMyChannels(List<String> interests) async* {
    debugPrint("DEBUG: User Interests in app: $interests");

    if (interests.isEmpty) {
      yield [];
      return;
    }

    // 1. Create the base list of channels based on user interests
    final myChannels = interests.map((id) {
      return InterestChannel(
        id: id,
        name: InterestData.getLabel(id),
        description: 'Global chat for ${InterestData.getLabel(id)}',
      );
    }).toList();

    // 2. Yield initial state immediately
    yield myChannels;

    // 3. Fetch channel details if permitted
    try {
      final updatedChannels = await Future.wait(myChannels.map((channel) async {
        try {
          final doc = await _firestore.collection('channels').doc(channel.id).get();
          if (doc.exists) {
            final fromStore = InterestChannel.fromFirestore(doc.id, doc.data()!);
            // Keep our local "pretty name" but take other details from store
            return InterestChannel(
              id: fromStore.id,
              name: InterestData.getLabel(fromStore.id),
              description: fromStore.description,
              lastMessage: fromStore.lastMessage,
              lastSenderName: fromStore.lastSenderName,
              lastMessageAt: fromStore.lastMessageAt,
            );
          }
        } catch (e) {
          // Silent failure for unauthorized channels
        }
        return channel;
      }));
      yield updatedChannels;
    } catch (e) {
      // Ignore
    }
  }

  String _capitalize(String text) {
    if (text.isEmpty) return text;
    return text.split(' ').map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1);
    }).join(' ');
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
