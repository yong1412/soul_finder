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

    final channelStreams = interests.map((id) {
      return _firestore
          .collection('channels')
          .doc(id)
          .snapshots()
          .map((doc) {
            if (doc.exists && doc.data() != null) {
              final fromStore = InterestChannel.fromFirestore(doc.id, doc.data()!);
              return InterestChannel(
                id: fromStore.id,
                name: InterestData.getLabel(fromStore.id),
                description: fromStore.description,
                lastMessage: fromStore.lastMessage,
                lastSenderName: fromStore.lastSenderName,
                lastMessageAt: fromStore.lastMessageAt,
              );
            }
            return InterestChannel(
              id: id,
              name: InterestData.getLabel(id),
              description: 'Global chat for ${InterestData.getLabel(id)}',
            );
          })
          .handleError((error) {
            debugPrint("Channel permission/read error for $id: $error");
            return InterestChannel(
              id: id,
              name: InterestData.getLabel(id),
              description: 'Global chat for ${InterestData.getLabel(id)}',
            );
          });
    }).toList();

    return _combineChannelStreams(channelStreams, interests);
  }

  Stream<List<InterestChannel>> _combineChannelStreams(
      List<Stream<InterestChannel>> streams, List<String> interests) {
    late StreamController<List<InterestChannel>> controller;
    final List<InterestChannel?> latestValues = List.filled(streams.length, null);
    final List<StreamSubscription> subscriptions = [];

    controller = StreamController<List<InterestChannel>>(
      onListen: () {
        final initial = interests.map((id) {
          return InterestChannel(
            id: id,
            name: InterestData.getLabel(id),
            description: 'Global chat for ${InterestData.getLabel(id)}',
          );
        }).toList();
        controller.add(initial);

        for (int i = 0; i < streams.length; i++) {
          final index = i;
          final sub = streams[index].listen(
            (channel) {
              latestValues[index] = channel;
              if (!controller.isClosed) {
                final currentList = <InterestChannel>[];
                for (int j = 0; j < streams.length; j++) {
                  currentList.add(
                    latestValues[j] ??
                        InterestChannel(
                          id: interests[j],
                          name: InterestData.getLabel(interests[j]),
                          description: 'Global chat for ${InterestData.getLabel(interests[j])}',
                        ),
                  );
                }
                controller.add(currentList);
              }
            },
            onError: (error) {
              debugPrint("Error listening to channel stream $index: $error");
            },
          );
          subscriptions.add(sub);
        }
      },
      onCancel: () {
        for (final sub in subscriptions) {
          sub.cancel();
        }
      },
    );

    return controller.stream;
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
