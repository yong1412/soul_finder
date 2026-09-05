import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:media_kit/media_kit.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/chat_message.dart';
import '../services/chat_service.dart';
import '../services/cloudinary_service.dart';
import '../services/match_service.dart';
import '../services/report_service.dart';
import 'full_screen_image_view.dart';
import 'public_user_profile_view.dart';
import 'video_player_view.dart';

class ChatConversationView extends StatefulWidget {
  const ChatConversationView({
    super.key,
    required this.targetUserUid,
    required this.targetUserName,
  });

  final String targetUserUid;
  final String targetUserName;

  @override
  State<ChatConversationView> createState() =>
      _ChatConversationViewState();
}

class _ChatConversationViewState extends State<ChatConversationView> {
  final ChatService _chatService = ChatService();
  final MatchService _matchService = MatchService();
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  StreamSubscription<List<ChatMessage>>? _messageSubscription;
  bool _isSending = false;
  String? _lastReadMessageId;
  ImageProvider? _targetProfileImage;

  @override
  void initState() {
    super.initState();
    _setupMessageListener();
    _loadTargetProfileData();
  }

  @override
  void dispose() {
    _messageSubscription?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// Load target user's profile image for AppBar & Avatar rendering
  Future<void> _loadTargetProfileData() async {
    final candidate = await _matchService.getCandidateForUid(widget.targetUserUid);
    if (candidate != null && mounted) {
      final base64Str = candidate.profile.profileImageBase64.trim();
      if (base64Str.isNotEmpty) {
        try {
          final cleanBase64 = base64Str.contains(',')
              ? base64Str.substring(base64Str.indexOf(',') + 1)
              : base64Str;
          setState(() {
            _targetProfileImage = MemoryImage(base64Decode(cleanBase64));
          });
        } catch (_) {}
      }
    }
  }

  /// Open target user's full profile view on Avatar tap
  Future<void> _openTargetUserProfile() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final candidate = await _matchService.getCandidateForUid(widget.targetUserUid);
      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog

      if (candidate != null) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PublicUserProfileView(candidate: candidate),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to load user profile.')),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading profile: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  void _setupMessageListener() {
    _messageSubscription = _chatService
        .watchMessages(widget.targetUserUid)
        .listen((messages) {
      if (messages.isEmpty) return;

      final latestMessage = messages.last;
      final currentUid = _chatService.currentUserUid;

      // 1. Mark as read if receiving a new message while the view is active
      if (latestMessage.receiverUid == currentUid &&
          _lastReadMessageId != latestMessage.id) {
        _lastReadMessageId = latestMessage.id;
        unawaited(_markConversationRead());
      }

      // 2. Decide whether to scroll to bottom
      final isMyMessage = latestMessage.senderUid == currentUid;
      final isAtBottom = !_scrollController.hasClients ||
          _scrollController.offset >=
              _scrollController.position.maxScrollExtent - 100;

      if (isMyMessage || isAtBottom) {
        _scrollToBottom();
      }
    });
  }

  Future<void> _markConversationRead() async {
    try {
      await _chatService.markChatRead(widget.targetUserUid);
    } catch (error) {
      debugPrint('Unable to mark chat as read: $error');
    }
  }

  Future<void> _sendTextMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isSending) return;

    setState(() => _isSending = true);

    try {
      await _chatService.sendTextMessage(
        targetUserUid: widget.targetUserUid,
        text: text,
      );
      _messageController.clear();
      _scrollToBottom();
    } catch (error) {
      _showError(error.toString());
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  /// Show modal sheet to choose photo or video from Camera/Gallery
  void _showMediaPickerOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFF3B82F6),
                  child: Icon(Icons.photo_library, color: Colors.white),
                ),
                title: const Text('Choose Photo from Gallery', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  _pickAndSendMedia(
                    type: ChatMessageType.image,
                    source: ImageSource.gallery,
                  );
                },
              ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFF10B981),
                  child: Icon(Icons.camera_alt, color: Colors.white),
                ),
                title: const Text('Take Photo with Camera', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  _pickAndSendMedia(
                    type: ChatMessageType.image,
                    source: ImageSource.camera,
                  );
                },
              ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFF59E0B),
                  child: Icon(Icons.video_library, color: Colors.white),
                ),
                title: const Text('Choose Video (Max 30s)', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  _pickAndSendMedia(
                    type: ChatMessageType.video,
                    source: ImageSource.gallery,
                  );
                },
              ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFF43F5E),
                  child: Icon(Icons.videocam, color: Colors.white),
                ),
                title: const Text('Record Video (Max 30s)', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  _pickAndSendMedia(
                    type: ChatMessageType.video,
                    source: ImageSource.camera,
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Pick photo/video, validate video length <= 30s, upload to Cloudinary and send message
  Future<void> _pickAndSendMedia({
    required ChatMessageType type,
    required ImageSource source,
  }) async {
    final bool isVideo = type == ChatMessageType.video;
    final XFile? file = isVideo
        ? await _picker.pickVideo(
            source: source,
            maxDuration: const Duration(seconds: 30),
          )
        : await _picker.pickImage(
            source: source,
            imageQuality: 70,
          );

    if (file != null) {
      if (isVideo) {
        final duration = await _getVideoDuration(file.path);
        if (duration > const Duration(seconds: 30, milliseconds: 500)) {
          if (mounted) {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                backgroundColor: const Color(0xFF1E293B),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                title: const Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Colors.orangeAccent),
                    SizedBox(width: 8),
                    Text('Video Too Long', style: TextStyle(color: Colors.white, fontSize: 18)),
                  ],
                ),
                content: Text(
                  'The selected video is ${duration.inSeconds} seconds long.\n\nPlease choose or record a video that is 30 seconds or shorter.',
                  style: const TextStyle(color: Colors.white70),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('OK', style: TextStyle(color: Color(0xFF3B82F6), fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            );
          }
          return;
        }
      }

      if (!mounted) return;

      // Show uploading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(
          child: Card(
            color: const Color(0xFF1E293B),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    isVideo ? 'Uploading Video (Max 30s)...' : 'Uploading Image...',
                    style: const TextStyle(color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      try {
        final mediaUrl = await CloudinaryService.uploadMedia(file, isVideo: isVideo);

        if (mounted) Navigator.pop(context); // Close loading dialog

        await _chatService.sendMediaMessage(
          targetUserUid: widget.targetUserUid,
          type: type,
          mediaUrl: mediaUrl,
        );
        _scrollToBottom();
      } catch (e) {
        if (mounted) Navigator.pop(context); // Close loading dialog
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Upload failed: $e'),
              backgroundColor: Colors.redAccent,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      }
    }
  }

  Future<Duration> _getVideoDuration(String path) async {
    try {
      final player = Player();
      await player.open(Media(path), play: false);
      await Future.delayed(const Duration(milliseconds: 300));
      final duration = player.state.duration;
      await player.dispose();
      return duration;
    } catch (_) {
      return Duration.zero;
    }
  }

  Future<void> _sendLocationResponse({
    required ChatMessage message,
    required bool accepted,
  }) async {
    if (_isSending) return;

    setState(() => _isSending = true);

    try {
      await _chatService.respondToSharedLocation(
        chatId: message.chatId,
        messageId: message.id,
        accepted: accepted,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              accepted
                  ? 'Meeting place accepted.'
                  : 'Meeting place declined.',
            ),
          ),
        );
      }
    } catch (error) {
      _showError(error.toString());
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _respondToProposal(
    ChatMessage message,
    MeetingProposalStatus response,
  ) async {
    if (_isSending) return;
    setState(() => _isSending = true);

    try {
      await _chatService.respondToMeetingProposal(
        chatId: message.chatId,
        messageId: message.id,
        response: response,
      );
    } catch (error) {
      _showError(error.toString());
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
      ),
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        // 🎯 Tapping the Avatar/Name in AppBar opens target user profile + Displays Realtime Online/Offline Status
        title: StreamBuilder<MatchPairData?>(
          stream: _matchService.watchPair(widget.targetUserUid),
          builder: (context, snapshot) {
            final targetProfile = snapshot.data?.otherUser;
            final isOnline = targetProfile?.isPubliclyOnline ?? false;

            return InkWell(
              onTap: _openTargetUserProfile,
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Stack(
                      children: [
                        CircleAvatar(
                          radius: 17,
                          backgroundColor: const Color(0xFF3B82F6),
                          backgroundImage: _targetProfileImage,
                          child: _targetProfileImage == null
                              ? Text(
                                  _firstCharacter(widget.targetUserName),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                )
                              : null,
                        ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isOnline ? const Color(0xFF10B981) : Colors.white38,
                              border: Border.all(color: const Color(0xFF0F172A), width: 2),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.targetUserName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          isOnline ? '🟢 Online' : '⚪ Offline',
                          style: TextStyle(
                            fontSize: 10,
                            color: isOnline ? const Color(0xFF10B981) : Colors.white38,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        centerTitle: true,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white70),
            color: const Color(0xFF1E293B),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            onSelected: (val) {
              if (val == 'profile') {
                _openTargetUserProfile();
              } else if (val == 'report') {
                showReportUserDialog(
                  context: context,
                  targetUid: widget.targetUserUid,
                  targetName: widget.targetUserName,
                );
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'profile',
                child: Row(
                  children: [
                    Icon(Icons.person_outline, color: Colors.white70, size: 20),
                    SizedBox(width: 10),
                    Text('View Profile', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'report',
                child: Row(
                  children: [
                    Icon(Icons.flag_outlined, color: Colors.redAccent, size: 20),
                    SizedBox(width: 10),
                    Text('Report User', style: TextStyle(color: Colors.redAccent)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<ChatMessage>>(
              stream: _chatService.watchMessages(widget.targetUserUid),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Unable to load messages: ${snapshot.error}',
                    ),
                  );
                }

                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final messages = snapshot.data!;
                if (messages.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 54,
                          color: Colors.white30,
                        ),
                        SizedBox(height: 12),
                        Text(
                          'No messages yet.',
                          style: TextStyle(color: Colors.white60),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    return _buildMessage(messages[index]);
                  },
                );
              },
            ),
          ),
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 10, 12, 12),
        decoration: const BoxDecoration(
          color: Color(0xFF1E293B),
          border: Border(
            top: BorderSide(color: Colors.white12),
          ),
        ),
        child: Row(
          children: [
            // Media Attachment Button (Photos / Videos)
            IconButton(
              icon: const Icon(
                Icons.add_photo_alternate_outlined,
                color: Color(0xFF38BDF8),
                size: 26,
              ),
              tooltip: 'Send Photo or Video',
              onPressed: _showMediaPickerOptions,
            ),
            const SizedBox(width: 4),

            Expanded(
              child: TextField(
                controller: _messageController,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendTextMessage(),
                decoration: InputDecoration(
                  hintText: 'Type a message...',
                  filled: true,
                  fillColor: const Color(0xFF0F172A),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 12,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: _isSending ? null : _sendTextMessage,
              icon: _isSending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send),
            ),
          ],
        ),
      ),
    );
  }

  /// Render Message Item matching Interest Channel stream layout
  Widget _buildMessage(ChatMessage message) {
    if (message.type == ChatMessageType.system) {
      return _buildSystemMessage(message);
    }

    final isMine = message.senderUid == _chatService.currentUserUid;
    final createdAt = message.createdAt ?? DateTime.now();
    final timeStr = "${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}";

    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          // Left Avatar
          GestureDetector(
            onTap: isMine ? null : _openTargetUserProfile,
            child: CircleAvatar(
              radius: 18,
              backgroundColor: isMine ? const Color(0xFF3B82F6) : const Color(0xFF64748B),
              backgroundImage: isMine ? null : _targetProfileImage,
              child: (isMine || _targetProfileImage == null)
                  ? Text(
                      _firstCharacter(isMine ? 'You' : widget.targetUserName),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : null,
            ),
          ),
          const SizedBox(width: 10),

          // Message Content Column
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Sender Name & Timestamp
                Row(
                  children: [
                    GestureDetector(
                      onTap: isMine ? null : _openTargetUserProfile,
                      child: Text(
                        isMine ? "You" : widget.targetUserName,
                        style: TextStyle(
                          fontSize: 13,
                          color: isMine ? const Color(0xFF3B82F6) : const Color(0xFF38BDF8),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      timeStr,
                      style: const TextStyle(fontSize: 10, color: Colors.white38),
                    ),
                  ],
                ),
                const SizedBox(height: 4),

                _buildMessageContent(message, isMine),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageContent(ChatMessage message, bool isMine) {
    switch (message.type) {
      case ChatMessageType.image:
        return _buildMediaContent(message, isVideo: false, isMine: isMine);
      case ChatMessageType.video:
        return _buildMediaContent(message, isVideo: true, isMine: isMine);
      case ChatMessageType.meetingProposal:
        return _buildStructuredProposal(message);
      case ChatMessageType.system:
        return _buildSystemMessage(message);
      case ChatMessageType.text:
        final sharedLocation = _SharedLocation.tryParse(message.text);
        if (sharedLocation != null) {
          return _buildSharedLocationCard(message, sharedLocation);
        }
        return _buildTextContent(message, isMine);
    }
  }

  Widget _buildTextContent(ChatMessage message, bool isMine) {
    return GestureDetector(
      onLongPress: isMine ? () => _showMessageOptions(message) : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isMine ? const Color(0xFF1E3A8A) : const Color(0xFF1E293B),
          borderRadius: const BorderRadius.only(
            topRight: Radius.circular(14),
            bottomLeft: Radius.circular(14),
            bottomRight: Radius.circular(14),
          ),
          border: isMine ? Border.all(color: const Color(0xFF3B82F6).withValues(alpha: 0.5), width: 1) : null,
        ),
        child: Text(
          message.text,
          style: const TextStyle(color: Colors.white, fontSize: 14),
        ),
      ),
    );
  }

  Widget _buildMediaContent(ChatMessage message, {required bool isVideo, required bool isMine}) {
    final mediaUrl = message.mediaUrl;

    return GestureDetector(
      onLongPress: isMine ? () => _showMessageOptions(message) : null,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: isMine ? const Color(0xFF1E3A8A) : const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(14),
          border: isMine ? Border.all(color: const Color(0xFF3B82F6).withValues(alpha: 0.5), width: 1) : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: mediaUrl == null
              ? const SizedBox(
                  width: 180,
                  height: 120,
                  child: Center(
                    child: Icon(Icons.broken_image, color: Colors.white38),
                  ),
                )
              : (isVideo
                  ? GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => VideoPlayerView(
                              videoUrl: mediaUrl,
                            ),
                          ),
                        );
                      },
                      child: Container(
                        width: 220,
                        height: 130,
                        decoration: BoxDecoration(
                          color: Colors.black26,
                          borderRadius: BorderRadius.circular(10),
                          image: DecorationImage(
                            image: NetworkImage(
                              CloudinaryService.getVideoThumbnail(mediaUrl),
                            ),
                            fit: BoxFit.cover,
                            opacity: 0.7,
                          ),
                        ),
                        child: const Center(
                          child: CircleAvatar(
                            backgroundColor: Colors.black45,
                            radius: 22,
                            child: Icon(
                              Icons.play_arrow,
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                        ),
                      ),
                    )
                  : GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => FullScreenImageView(
                              imageUrl: mediaUrl,
                              heroTag: 'msg_${message.id}',
                            ),
                          ),
                        );
                      },
                      child: Hero(
                        tag: 'msg_${message.id}',
                        child: Image.network(
                          mediaUrl,
                          width: 220,
                          height: 200,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              const Icon(Icons.broken_image, color: Colors.white24),
                        ),
                      ),
                    )),
        ),
      ),
    );
  }

  void _showMessageOptions(ChatMessage message) {
    final createdAt = message.createdAt ?? DateTime.now();
    final diffInSeconds = DateTime.now().difference(createdAt).inSeconds;
    final bool canDelete = diffInSeconds <= 180; // 3 minutes limit

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(
                  Icons.delete_outline,
                  color: canDelete ? Colors.redAccent : Colors.white24,
                ),
                title: Text(
                  'Delete Message',
                  style: TextStyle(
                    color: canDelete ? Colors.redAccent : Colors.white24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: Text(
                  canDelete
                      ? 'You can delete this message within 3 minutes of sending'
                      : 'Expired (sent over 3 minutes ago)',
                  style: const TextStyle(color: Colors.white38, fontSize: 12),
                ),
                onTap: canDelete
                    ? () {
                        Navigator.pop(context);
                        _confirmDeleteMessage(message);
                      }
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDeleteMessage(ChatMessage message) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Message?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Are you sure you want to delete this message?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _chatService.deleteMessage(message);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Message deleted.')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Delete failed: $e'), backgroundColor: Colors.redAccent),
          );
        }
      }
    }
  }

  Widget _buildSystemMessage(ChatMessage message) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF334155).withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        message.text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildSharedLocationCard(
    ChatMessage message,
    _SharedLocation sharedLocation,
  ) {
    final isMine = message.senderUid == _chatService.currentUserUid;

    return Container(
      width: 300,
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF3B82F6).withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.place,
                color: Color(0xFFF43F5E),
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  sharedLocation.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            sharedLocation.address,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _openMaps(sharedLocation.mapsUrl),
                  icon: const Icon(Icons.map, size: 16),
                  label: const Text('Open Map'),
                ),
              ),
              if (!isMine) ...[
                const SizedBox(width: 8),
                if (message.status == MeetingProposalStatus.none) ...[
                  IconButton(
                    tooltip: 'Accept place',
                    onPressed: () => _sendLocationResponse(
                      message: message,
                      accepted: true,
                    ),
                    icon: const Icon(
                      Icons.check_circle_outline,
                      color: Color(0xFF10B981),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Decline place',
                    onPressed: () => _sendLocationResponse(
                      message: message,
                      accepted: false,
                    ),
                    icon: const Icon(
                      Icons.cancel_outlined,
                      color: Colors.redAccent,
                    ),
                  ),
                ],
              ],
            ],
          ),
          if (message.status != MeetingProposalStatus.none) ...[
            const SizedBox(height: 8),
            Text(
              message.status == MeetingProposalStatus.accepted
                  ? '✓ Meeting place accepted'
                  : '✕ Meeting place declined',
              style: TextStyle(
                color: message.status == MeetingProposalStatus.accepted
                    ? const Color(0xFF10B981)
                    : Colors.redAccent,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStructuredProposal(ChatMessage message) {
    final venue = message.venue;

    if (venue == null) {
      return _buildTextContent(message, message.senderUid == _chatService.currentUserUid);
    }

    final isReceiver = message.receiverUid == _chatService.currentUserUid;
    final isAccepted = message.status == MeetingProposalStatus.accepted;
    final isDeclined = message.status == MeetingProposalStatus.declined;

    return Container(
      width: 310,
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isAccepted
              ? const Color(0xFF10B981)
              : isDeclined
                  ? Colors.redAccent
                  : const Color(0xFF3B82F6),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.place_outlined,
                color: isAccepted
                    ? const Color(0xFF10B981)
                    : isDeclined
                        ? Colors.redAccent
                        : const Color(0xFF3B82F6),
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  venue.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            venue.address,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${venue.category} • ${venue.distanceFromMidpointKm.toStringAsFixed(1)} km from midpoint',
            style: const TextStyle(
              color: Colors.white38,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 12),
          if (isReceiver && message.status == MeetingProposalStatus.pending) ...[
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _respondToProposal(
                      message,
                      MeetingProposalStatus.declined,
                    ),
                    icon: const Icon(Icons.close, size: 16),
                    label: const Text('Decline'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                      side: const BorderSide(color: Colors.redAccent),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _respondToProposal(
                      message,
                      MeetingProposalStatus.accepted,
                    ),
                    icon: const Icon(Icons.check, size: 16),
                    label: const Text('Accept'),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                    ),
                  ),
                ),
              ],
            ),
          ] else if (isAccepted) ...[
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.check_circle,
                    color: Color(0xFF10B981),
                    size: 16,
                  ),
                  SizedBox(width: 6),
                  Text(
                    'Meeting Accepted 🎉',
                    style: TextStyle(
                      color: Color(0xFF10B981),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ] else if (isDeclined) ...[
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: Colors.redAccent.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.cancel,
                    color: Colors.redAccent,
                    size: 16,
                  ),
                  SizedBox(width: 6),
                  Text(
                    'Meeting Declined',
                    style: TextStyle(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: TextButton.icon(
              onPressed: () => _openMaps(venue.mapsUrl),
              icon: const Icon(Icons.map, size: 16),
              label: const Text('View in Google Maps'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openMaps(String mapsUrl) async {
    final uri = Uri.tryParse(mapsUrl);
    if (uri == null) {
      _showError('Invalid map URL.');
      return;
    }

    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        _showError('Could not open Google Maps.');
      }
    } catch (_) {
      _showError('Could not open Google Maps.');
    }
  }

  String _firstCharacter(String name) {
    return name.trim().isEmpty ? '?' : name.trim().substring(0, 1).toUpperCase();
  }
}

class _SharedLocation {
  const _SharedLocation({
    required this.title,
    required this.address,
    required this.mapsUrl,
  });

  final String title;
  final String address;
  final String mapsUrl;

  static _SharedLocation? tryParse(String text) {
    if (!text.startsWith('📍 MEETING PLACE SUGGESTION')) {
      return null;
    }

    final lines = text.split('\n');
    if (lines.length < 3) {
      return null;
    }

    final title = lines[0].replaceFirst('📍 MEETING PLACE SUGGESTION: ', '');
    final address = lines[1].replaceFirst('Address: ', '');
    final mapsUrl = lines[2].replaceFirst('Map: ', '');

    return _SharedLocation(
      title: title,
      address: address,
      mapsUrl: mapsUrl,
    );
  }
}
