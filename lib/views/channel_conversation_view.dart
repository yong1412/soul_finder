import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:media_kit/media_kit.dart';
import '../models/channel.dart';
import '../services/channel_service.dart';
import '../services/cloudinary_service.dart';
import '../services/match_service.dart';
import '../controllers/auth_controller.dart';
import 'full_screen_image_view.dart';
import 'public_user_profile_view.dart';
import 'video_player_view.dart';

class ChannelConversationView extends StatefulWidget {
  const ChannelConversationView({
    super.key,
    required this.channelId,
    required this.channelName,
    required this.authController,
  });

  final String channelId;
  final String channelName;
  final AuthController authController;

  @override
  State<ChannelConversationView> createState() => _ChannelConversationViewState();
}

class _ChannelConversationViewState extends State<ChannelConversationView> {
  final ChannelService _channelService = ChannelService();
  final MatchService _matchService = MatchService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _picker = ImagePicker();
  late final Stream<List<ChannelMessage>> _messagesStream;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _messagesStream = _channelService.watchMessages(widget.channelId);
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// Open another user's profile on avatar tap
  Future<void> _openUserProfile(String userUid) async {
    if (userUid == widget.authController.currentUser?.uid) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final candidate = await _matchService.getCandidateForUid(userUid);
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

  Future<void> _sendMessage({MessageType type = MessageType.text, String? mediaUrl}) async {
    final text = _messageController.text.trim();
    if (text.isEmpty && type == MessageType.text) return;
    if (_isSending) return;

    final user = widget.authController.currentUser;
    if (user == null) return;

    setState(() => _isSending = true);

    try {
      await _channelService.sendMessage(
        channelName: widget.channelId,
        senderName: user.name,
        senderProfileImage: user.profileImageBase64 ?? '',
        text: text,
        type: type,
        mediaUrl: mediaUrl,
      );

      _messageController.clear();
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send message: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

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
                  _pickAndSendMedia(type: MessageType.image, source: ImageSource.gallery);
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
                  _pickAndSendMedia(type: MessageType.image, source: ImageSource.camera);
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
                  _pickAndSendMedia(type: MessageType.video, source: ImageSource.gallery);
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
                  _pickAndSendMedia(type: MessageType.video, source: ImageSource.camera);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickAndSendMedia({required MessageType type, required ImageSource source}) async {
    final bool isVideo = type == MessageType.video;
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
        // Validate video duration
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
          return; // Cancel upload if video exceeds 30 seconds
        }
      }

      if (!mounted) return;

      // Show uploading indicator
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
        if (mounted) {
          Navigator.of(context).pop();
          _sendMessage(
            type: type,
            mediaUrl: mediaUrl,
          );
        }
      } catch (e) {
        if (mounted) {
          Navigator.of(context).pop();
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

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  ImageProvider? _decodeProfileImage(String? base64Str) {
    if (base64Str == null || base64Str.trim().isEmpty) return null;
    try {
      final cleanBase64 = base64Str.contains(',')
          ? base64Str.substring(base64Str.indexOf(',') + 1)
          : base64Str;
      return MemoryImage(base64Decode(cleanBase64));
    } catch (_) {
      return null;
    }
  }

  void _showMessageOptions(ChannelMessage message) {
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

  void _confirmDeleteMessage(ChannelMessage message) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Message?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Are you sure you want to delete this message for everyone in the channel?',
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
        await _channelService.deleteMessage(widget.channelId, message);
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

  Widget _buildMessageItem(ChannelMessage message) {
    final isMine = message.senderUid == widget.authController.currentUser?.uid;
    final profileImage = _decodeProfileImage(message.senderProfileImageBase64);
    final timeStr = "${message.createdAt.hour.toString().padLeft(2, '0')}:${message.createdAt.minute.toString().padLeft(2, '0')}";

    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.start, // Standard top-to-bottom left-aligned channel message stream
        children: [
          GestureDetector(
            onTap: () => _openUserProfile(message.senderUid),
            child: CircleAvatar(
              radius: 18,
              backgroundColor: isMine ? const Color(0xFF3B82F6) : const Color(0xFF64748B),
              backgroundImage: profileImage,
              child: profileImage == null
                  ? Text(
                      _firstCharacter(message.senderName),
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => _openUserProfile(message.senderUid),
                      child: Text(
                        isMine ? "${message.senderName} (You)" : message.senderName,
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
                GestureDetector(
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (message.type == MessageType.image && message.mediaUrl != null)
                          GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => FullScreenImageView(
                                    imageUrl: message.mediaUrl!,
                                    heroTag: 'msg_${message.id}',
                                  ),
                                ),
                              );
                            },
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Hero(
                                tag: 'msg_${message.id}',
                                child: Image.network(
                                  message.mediaUrl!,
                                  width: 220,
                                  height: 200,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      const Icon(Icons.broken_image, color: Colors.white24),
                                ),
                              ),
                            ),
                          ),
                        if (message.type == MessageType.video && message.mediaUrl != null)
                          GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => VideoPlayerView(
                                    videoUrl: message.mediaUrl!,
                                  ),
                                ),
                              );
                            },
                            child: Container(
                              width: 220,
                              height: 130,
                              decoration: BoxDecoration(
                                color: Colors.black26,
                                borderRadius: BorderRadius.circular(8),
                                image: DecorationImage(
                                  image: NetworkImage(
                                    CloudinaryService.getVideoThumbnail(message.mediaUrl!),
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
                          ),
                        if (message.text.isNotEmpty)
                          Padding(
                            padding: EdgeInsets.only(
                              top: (message.type != MessageType.text && message.mediaUrl != null) ? 8.0 : 0,
                            ),
                            child: Text(
                              message.text,
                              style: const TextStyle(color: Colors.white, fontSize: 14),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _firstCharacter(String name) {
    return name.trim().isEmpty ? '?' : name.trim().substring(0, 1).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: Text(widget.channelName),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<ChannelMessage>>(
              stream: _messagesStream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Error loading messages: ${snapshot.error}',
                      style: const TextStyle(color: Colors.redAccent),
                    ),
                  );
                }

                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final messages = snapshot.data!;
                if (messages.isEmpty) {
                  return const Center(
                    child: Text(
                      'No messages yet. Start the conversation!',
                      style: TextStyle(color: Colors.white54),
                    ),
                  );
                }

                _scrollToBottom();

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    return _buildMessageItem(messages[index]);
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
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        color: const Color(0xFF1E293B),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.add_photo_alternate_outlined, color: Color(0xFF38BDF8)),
              onPressed: _showMediaPickerOptions,
            ),
            Expanded(
              child: TextField(
                controller: _messageController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Type a message...',
                  hintStyle: const TextStyle(color: Colors.white38),
                  filled: true,
                  fillColor: const Color(0xFF0F172A),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: _isSending
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send, color: Color(0xFF3B82F6)),
              onPressed: _isSending ? null : () => _sendMessage(),
            ),
          ],
        ),
      ),
    );
  }
}
