import 'package:cloud_firestore/cloud_firestore.dart';
import 'meeting_venue.dart';

enum ChatMessageType {
  text,
  image,
  video,
  meetingProposal,
  system,
}

enum MeetingProposalStatus {
  none,
  pending,
  accepted,
  declined,
  counterProposed,
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.chatId,
    required this.senderUid,
    required this.receiverUid,
    required this.type,
    required this.text,
    required this.status,
    required this.acceptedBy,
    this.mediaUrl,
    this.venue,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String chatId;
  final String senderUid;
  final String receiverUid;
  final ChatMessageType type;
  final String text;
  final MeetingProposalStatus status;
  final List<String> acceptedBy;
  final String? mediaUrl;
  final MeetingVenue? venue;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory ChatMessage.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? {};
    final venueData = data['venue'] as Map<String, dynamic>?;
    final createdTimestamp = data['createdAt'] as Timestamp?;
    final updatedTimestamp = data['updatedAt'] as Timestamp?;

    return ChatMessage(
      id: document.id,
      chatId: data['chatId'] as String? ?? '',
      senderUid: data['senderUid'] as String? ?? '',
      receiverUid: data['receiverUid'] as String? ?? '',
      type: _parseMessageType(data['type'] as String?),
      text: data['text'] as String? ?? '',
      status: _parseProposalStatus(data['status'] as String?),
      acceptedBy: (data['acceptedBy'] as List<dynamic>? ?? [])
          .map((item) => item.toString())
          .toList(),
      mediaUrl: data['mediaUrl'] as String?,
      venue: venueData == null ? null : MeetingVenue.fromJson(venueData),
      createdAt: createdTimestamp?.toDate(),
      updatedAt: updatedTimestamp?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'chatId': chatId,
      'senderUid': senderUid,
      'receiverUid': receiverUid,
      'type': type.name,
      'text': text,
      'status': status.name,
      'acceptedBy': acceptedBy,
      if (mediaUrl != null && mediaUrl!.isNotEmpty) 'mediaUrl': mediaUrl,
      if (venue != null) 'venue': venue!.toJson(),
      'createdAt': createdAt == null
          ? FieldValue.serverTimestamp()
          : Timestamp.fromDate(createdAt!),
      'updatedAt': updatedAt == null
          ? FieldValue.serverTimestamp()
          : Timestamp.fromDate(updatedAt!),
    };
  }

  ChatMessage copyWith({
    String? id,
    String? chatId,
    String? senderUid,
    String? receiverUid,
    ChatMessageType? type,
    String? text,
    MeetingProposalStatus? status,
    List<String>? acceptedBy,
    String? mediaUrl,
    MeetingVenue? venue,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      chatId: chatId ?? this.chatId,
      senderUid: senderUid ?? this.senderUid,
      receiverUid: receiverUid ?? this.receiverUid,
      type: type ?? this.type,
      text: text ?? this.text,
      status: status ?? this.status,
      acceptedBy: acceptedBy ?? this.acceptedBy,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      venue: venue ?? this.venue,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static ChatMessageType _parseMessageType(String? value) {
    switch (value) {
      case 'image':
        return ChatMessageType.image;
      case 'video':
        return ChatMessageType.video;
      case 'meetingProposal':
        return ChatMessageType.meetingProposal;
      case 'system':
        return ChatMessageType.system;
      default:
        return ChatMessageType.text;
    }
  }

  static MeetingProposalStatus _parseProposalStatus(String? value) {
    switch (value) {
      case 'pending':
        return MeetingProposalStatus.pending;
      case 'accepted':
        return MeetingProposalStatus.accepted;
      case 'declined':
        return MeetingProposalStatus.declined;
      case 'counterProposed':
        return MeetingProposalStatus.counterProposed;
      default:
        return MeetingProposalStatus.none;
    }
  }
}
