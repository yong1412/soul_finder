import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/chat_message.dart';
import '../models/meeting_venue.dart';

class ChatPreview {
  const ChatPreview({
    required this.chatId,
    required this.otherUserUid,
    required this.otherUserName,
    required this.otherUserProfileImageBase64,
    required this.lastMessage,
    required this.lastMessageType,
    required this.unreadCount,
    this.lastMessageAt,
  });

  final String chatId;
  final String otherUserUid;
  final String otherUserName;
  final String otherUserProfileImageBase64;
  final String lastMessage;
  final String lastMessageType;
  final int unreadCount;
  final DateTime? lastMessageAt;
}

class ChatService {
  ChatService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  String get currentUserUid {
    final uid = _auth.currentUser?.uid;

    if (uid == null) {
      throw const ChatException('User is not signed in.');
    }

    return uid;
  }

  String createChatId(
      String firstUid,
      String secondUid,
      ) {
    final userIds = [firstUid, secondUid]..sort();
    return userIds.join('_');
  }

  DocumentReference<Map<String, dynamic>> _chatReference(
      String chatId,
      ) {
    return _firestore.collection('chats').doc(chatId);
  }

  CollectionReference<Map<String, dynamic>> _messageCollection(
      String chatId,
      ) {
    return _chatReference(chatId).collection('messages');
  }

  Future<void> _checkActiveMatch(
      String targetUserUid,
      ) async {
    final currentUid = currentUserUid;
    final matchId = createChatId(currentUid, targetUserUid);

    final matchSnapshot = await _firestore
        .collection('matches')
        .doc(matchId)
        .get();

    final matchData = matchSnapshot.data();
    final users = (matchData?['users'] as List<dynamic>? ?? const [])
        .map((item) => item.toString())
        .toList();

    final validMatch = matchSnapshot.exists &&
        matchData?['status'] == 'active' &&
        users.contains(currentUid) &&
        users.contains(targetUserUid);

    if (!validMatch) {
      throw const ChatException(
        'Chat is only available after a mutual match.',
      );
    }
  }

  Stream<List<ChatMessage>> watchMessages(
      String targetUserUid,
      ) {
    final chatId = createChatId(
      currentUserUid,
      targetUserUid,
    );

    return _messageCollection(chatId)
        .orderBy('createdAt')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
          .map(ChatMessage.fromDocument)
          .toList(),
    );
  }

  Future<void> deleteMessage(ChatMessage message) async {
    final uid = currentUserUid;
    if (message.senderUid != uid) {
      throw const ChatException('You can only delete your own messages.');
    }

    final createdAt = message.createdAt ?? DateTime.now();
    if (DateTime.now().difference(createdAt).inSeconds > 180) {
      throw const ChatException('Messages can only be deleted within 3 minutes of sending.');
    }

    await _messageCollection(message.chatId).doc(message.id).delete();
  }

  Future<void> sendTextMessage({
    required String targetUserUid,
    required String text,
  }) async {
    final trimmedText = text.trim();

    if (trimmedText.isEmpty) {
      return;
    }

    await _checkActiveMatch(targetUserUid);

    final currentUid = currentUserUid;
    final chatId = createChatId(currentUid, targetUserUid);
    final messageReference = _messageCollection(chatId).doc();

    final message = ChatMessage(
      id: messageReference.id,
      chatId: chatId,
      senderUid: currentUid,
      receiverUid: targetUserUid,
      type: ChatMessageType.text,
      text: trimmedText,
      status: MeetingProposalStatus.none,
      acceptedBy: const [],
    );

    final batch = _firestore.batch();

    batch.set(
      messageReference,
      message.toFirestore(),
    );

    // Participants were created by MatchService. Do not rewrite the list
    // here because Firestore list equality is order-sensitive.
    batch.update(
      _chatReference(chatId),
      {
        'chatId': chatId,
        'lastMessage': trimmedText,
        'lastMessageType': 'text',
        'lastSenderUid': currentUid,
        'lastMessageAt': FieldValue.serverTimestamp(),
        'unreadCounts.$targetUserUid': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      },
    );

    await batch.commit();
  }

  Future<void> respondToSharedLocation({
    required String chatId,
    required String messageId,
    required bool accepted,
  }) async {
    final currentUid = currentUserUid;
    final messageReference = _messageCollection(chatId).doc(messageId);
    final systemMessageReference = _messageCollection(chatId).doc();

    await _firestore.runTransaction<void>((transaction) async {
      final snapshot = await transaction.get(messageReference);

      if (!snapshot.exists) {
        throw const ChatException('Meeting suggestion was not found.');
      }

      final message = ChatMessage.fromDocument(snapshot);

      if (message.type != ChatMessageType.text ||
          !message.text.startsWith('📍 MEETING PLACE SUGGESTION')) {
        throw const ChatException('This is not a meeting suggestion.');
      }

      if (message.receiverUid != currentUid) {
        throw const ChatException(
          'Only the receiver can answer this suggestion.',
        );
      }

      if (message.status == MeetingProposalStatus.accepted ||
          message.status == MeetingProposalStatus.declined) {
        throw const ChatException(
          'This meeting suggestion has already been answered.',
        );
      }

      final responseStatus = accepted
          ? MeetingProposalStatus.accepted
          : MeetingProposalStatus.declined;
      final systemText = accepted
          ? 'Meeting place accepted.'
          : 'Meeting place declined. Please suggest another public place.';

      transaction.update(
        messageReference,
        {
          'status': responseStatus.name,
          'acceptedBy': accepted
              ? [message.senderUid, currentUid]
              : <String>[],
          'updatedAt': FieldValue.serverTimestamp(),
        },
      );

      final systemMessage = ChatMessage(
        id: systemMessageReference.id,
        chatId: chatId,
        senderUid: currentUid,
        receiverUid: message.senderUid,
        type: ChatMessageType.system,
        text: systemText,
        status: MeetingProposalStatus.none,
        acceptedBy: const [],
      );

      transaction.set(
        systemMessageReference,
        systemMessage.toFirestore(),
      );

      transaction.update(
        _chatReference(chatId),
        {
          'lastMessage': systemText,
          'lastMessageType': 'system',
          'lastSenderUid': currentUid,
          'lastMessageAt': FieldValue.serverTimestamp(),
          'unreadCounts.${message.senderUid}': FieldValue.increment(1),
          'updatedAt': FieldValue.serverTimestamp(),
        },
      );
    });
  }

  Future<String> sendMeetingProposal({
    required String targetUserUid,
    required MeetingVenue venue,
  }) async {
    await _checkActiveMatch(targetUserUid);

    final currentUid = currentUserUid;
    final chatId = createChatId(currentUid, targetUserUid);
    final messageReference = _messageCollection(chatId).doc();

    final message = ChatMessage(
      id: messageReference.id,
      chatId: chatId,
      senderUid: currentUid,
      receiverUid: targetUserUid,
      type: ChatMessageType.meetingProposal,
      text: 'Suggested ${venue.name}',
      status: MeetingProposalStatus.pending,
      acceptedBy: [currentUid],
      venue: venue,
    );

    final batch = _firestore.batch();

    batch.set(
      messageReference,
      message.toFirestore(),
    );

    // Keep the original participants list unchanged.
    batch.update(
      _chatReference(chatId),
      {
        'chatId': chatId,
        'lastMessage': 'Meeting place suggested: ${venue.name}',
        'lastMessageType': 'meetingProposal',
        'lastSenderUid': currentUid,
        'lastMessageAt': FieldValue.serverTimestamp(),
        'unreadCounts.$targetUserUid': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      },
    );

    await batch.commit();
    return messageReference.id;
  }

  Future<void> respondToMeetingProposal({
    required String chatId,
    required String messageId,
    required MeetingProposalStatus response,
  }) async {
    if (response != MeetingProposalStatus.accepted &&
        response != MeetingProposalStatus.declined &&
        response != MeetingProposalStatus.counterProposed) {
      throw const ChatException('Invalid meeting response.');
    }

    final currentUid = currentUserUid;
    final messageReference = _messageCollection(chatId).doc(messageId);
    final systemMessageReference = _messageCollection(chatId).doc();

    await _firestore.runTransaction<void>((transaction) async {
      final messageSnapshot = await transaction.get(messageReference);

      if (!messageSnapshot.exists) {
        throw const ChatException(
          'Meeting proposal was not found.',
        );
      }

      final message = ChatMessage.fromDocument(messageSnapshot);

      if (message.type != ChatMessageType.meetingProposal) {
        throw const ChatException(
          'This message is not a meeting proposal.',
        );
      }

      final isParticipant = currentUid == message.senderUid ||
          currentUid == message.receiverUid;

      if (!isParticipant) {
        throw const ChatException(
          'You cannot respond to this proposal.',
        );
      }

      if (currentUid == message.senderUid) {
        throw const ChatException(
          'Wait for the other user to respond.',
        );
      }

      if (message.status != MeetingProposalStatus.pending &&
          message.status != MeetingProposalStatus.counterProposed) {
        throw const ChatException(
          'This proposal has already been answered.',
        );
      }

      final acceptedBy = [...message.acceptedBy];

      MeetingProposalStatus finalStatus;
      String systemText;

      if (response == MeetingProposalStatus.accepted) {
        if (!acceptedBy.contains(currentUid)) {
          acceptedBy.add(currentUid);
        }

        finalStatus = acceptedBy.length >= 2
            ? MeetingProposalStatus.accepted
            : MeetingProposalStatus.pending;
        systemText = 'Meeting place accepted.';
      } else if (response == MeetingProposalStatus.declined) {
        finalStatus = MeetingProposalStatus.declined;
        systemText = 'Meeting place declined.';
      } else {
        finalStatus = MeetingProposalStatus.counterProposed;
        systemText = 'Requested another meeting place.';
      }

      transaction.update(
        messageReference,
        {
          'status': finalStatus.name,
          'acceptedBy': acceptedBy,
          'updatedAt': FieldValue.serverTimestamp(),
        },
      );

      final otherUserUid = currentUid == message.senderUid
          ? message.receiverUid
          : message.senderUid;

      final systemMessage = ChatMessage(
        id: systemMessageReference.id,
        chatId: chatId,
        senderUid: currentUid,
        receiverUid: otherUserUid,
        type: ChatMessageType.system,
        text: systemText,
        status: MeetingProposalStatus.none,
        acceptedBy: const [],
      );

      transaction.set(
        systemMessageReference,
        systemMessage.toFirestore(),
      );

      transaction.update(
        _chatReference(chatId),
        {
          'lastMessage': systemText,
          'lastMessageType': 'system',
          'lastSenderUid': currentUid,
          'lastMessageAt': FieldValue.serverTimestamp(),
          'unreadCounts.$otherUserUid': FieldValue.increment(1),
          'updatedAt': FieldValue.serverTimestamp(),
        },
      );

      if (finalStatus == MeetingProposalStatus.accepted &&
          message.venue != null) {
        transaction.set(
          _firestore.collection('meetingPlans').doc(chatId),
          {
            'matchId': chatId,
            'chatId': chatId,
            'proposalMessageId': messageId,
            'participants': [
              message.senderUid,
              message.receiverUid,
            ]..sort(),
            'venue': message.venue!.toJson(),
            'status': 'confirmed',
            'acceptedBy': acceptedBy,
            'confirmedAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      }
    });
  }

  Stream<List<ChatPreview>> watchChatPreviews() {
    final currentUid = currentUserUid;

    return _firestore
        .collection('chats')
        .where('participants', arrayContains: currentUid)
        .snapshots()
        .asyncMap((snapshot) async {
      final previews = <ChatPreview>[];

      for (final chatDocument in snapshot.docs) {
        final data = chatDocument.data();
        final participants =
        (data['participants'] as List<dynamic>? ?? const [])
            .map((item) => item.toString())
            .toList();

        final otherUserUid = participants.firstWhere(
              (uid) => uid != currentUid,
          orElse: () => '',
        );

        if (otherUserUid.isEmpty) {
          continue;
        }

        final userSnapshot = await _firestore
            .collection('users')
            .doc(otherUserUid)
            .get();

        final userData = userSnapshot.data();
        final timestamp = data['lastMessageAt'] as Timestamp?;

        previews.add(
          ChatPreview(
            chatId: chatDocument.id,
            otherUserUid: otherUserUid,
            otherUserName:
            userData?['name'] as String? ?? 'User',
            otherUserProfileImageBase64:
            userData?['profileImageBase64'] as String? ?? '',
            lastMessage:
            data['lastMessage'] as String? ?? 'Start chatting',
            lastMessageType:
            data['lastMessageType'] as String? ?? 'text',
            unreadCount: _unreadCountFromData(data, currentUid),
            lastMessageAt: timestamp?.toDate(),
          ),
        );
      }

      previews.sort((first, second) {
        final firstDate = first.lastMessageAt ?? DateTime(2000);
        final secondDate = second.lastMessageAt ?? DateTime(2000);
        return secondDate.compareTo(firstDate);
      });

      return previews;
    }).asBroadcastStream();
  }

  Stream<int> watchTotalUnreadCount() {
    final currentUid = currentUserUid;

    return _firestore
        .collection('chats')
        .where('participants', arrayContains: currentUid)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.fold<int>(
        0,
            (total, document) =>
        total + _unreadCountFromData(document.data(), currentUid),
      ),
    );
  }

  Future<void> markChatRead(String targetUserUid) async {
    final currentUid = currentUserUid;
    final chatId = createChatId(currentUid, targetUserUid);

    await _chatReference(chatId).update({
      'unreadCounts.$currentUid': 0,
      'lastReadAt.$currentUid': FieldValue.serverTimestamp(),
    });
  }

  int _unreadCountFromData(
      Map<String, dynamic> data,
      String userUid,
      ) {
    final unreadCounts = data['unreadCounts'];

    if (unreadCounts is! Map) {
      return 0;
    }

    final value = unreadCounts[userUid];
    if (value is! num || value <= 0) {
      return 0;
    }

    return value.toInt();
  }
}

class ChatException implements Exception {
  const ChatException(this.message);

  final String message;

  @override
  String toString() => message;
}
