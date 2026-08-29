import 'package:cloud_firestore/cloud_firestore.dart';

class InterestChannel {
  const InterestChannel({
    required this.name,
    required this.description,
    this.lastMessage,
    this.lastSenderName,
    this.lastMessageAt,
  });

  final String name;
  final String description;
  final String? lastMessage;
  final String? lastSenderName;
  final DateTime? lastMessageAt;

  factory InterestChannel.fromFirestore(Map<String, dynamic> data) {
    return InterestChannel(
      name: data['name'] as String? ?? '',
      description: data['description'] as String? ?? '',
      lastMessage: data['lastMessage'] as String?,
      lastSenderName: data['lastSenderName'] as String?,
      lastMessageAt: (data['lastMessageAt'] as Timestamp?)?.toDate(),
    );
  }
}

class ChannelMessage {
  const ChannelMessage({
    required this.id,
    required this.channelName,
    required this.senderUid,
    required this.senderName,
    required this.senderProfileImageBase64,
    required this.text,
    required this.createdAt,
  });

  final String id;
  final String channelName;
  final String senderUid;
  final String senderName;
  final String senderProfileImageBase64;
  final String text;
  final DateTime createdAt;

  factory ChannelMessage.fromDocument(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return ChannelMessage(
      id: doc.id,
      channelName: data['channelName'] as String? ?? '',
      senderUid: data['senderUid'] as String? ?? '',
      senderName: data['senderName'] as String? ?? 'Anonymous',
      senderProfileImageBase64: data['senderProfileImageBase64'] as String? ?? '',
      text: data['text'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'channelName': channelName,
      'senderUid': senderUid,
      'senderName': senderName,
      'senderProfileImageBase64': senderProfileImageBase64,
      'text': text,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}
