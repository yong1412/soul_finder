import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:media_kit/media_kit.dart';
import '../models/channel.dart';
import '../services/channel_service.dart';
import '../services/cloudinary_service.dart';
import '../controllers/auth_controller.dart';
import 'full_screen_image_view.dart';
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
        text: text,
        senderName: user.name,
        senderProfileImage: user.profileImageBase64,
        type: type,
        mediaUrl: mediaUrl,
      );
      _messageController.clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<Duration> _getVideoDuration(String filePath) async {
    final player = Player();
    try {
      await player.open(Media(filePath), play: false);
      final duration = await player.stream.duration
          .firstWhere((d) => d > Duration.zero)
          .timeout(
            const Duration(seconds: 3),
            onTimeout: () => player.state.duration,
          );
      return duration;
    } catch (e) {
      debugPrint("Error reading video duration: $e");
      return Duration.zero;
    } finally {
      await player.dispose();
    }
  }

  Future<void> _pickMedia(MessageType type, ImageSource source) async {
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
        
        if (mounted) Navigator.pop(context); // Close loading dialog

        await _sendMessage(
          type: type,
          mediaUrl: mediaUrl,
        );
      } catch (e) {
        if (mounted) Navigator.pop(context); // Close loading dialog
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: Column(
          children: [
            Text(widget.channelName, style: const TextStyle(fontWeight: FontWeight.bold)),
            Text('Global Interests Chat', style: TextStyle(fontSize: 10, color: Colors.white.withOpacity(0.5))),
          ],
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<ChannelMessage>>(
              stream: _messagesStream,
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final messages = snapshot.data!;
                if (messages.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.forum_outlined, size: 64, color: Colors.white10),
                        const SizedBox(height: 16),
                        Text('Welcome to # ${widget.channelName}', style: const TextStyle(color: Colors.white38)),
                        const Text('Start the conversation!', style: TextStyle(color: Colors.white24, fontSize: 12)),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  reverse: true, // Newest at bottom
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    return _buildMessageItem(messages[index]);
                  },
                );
              },
            ),
          ),
          _buildInputArea(),
        ],
      ),
    );
  }

  void _showMessageOptions(ChannelMessage message) {
    final diffInSeconds = DateTime.now().difference(message.createdAt).inSeconds;
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

    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isMine) ...[
            CircleAvatar(
              radius: 18,
              backgroundImage: profileImage,
              child: profileImage == null ? const Icon(Icons.person, size: 18) : null,
            ),
            const SizedBox(width: 10),
          ],
          Flexible(
            child: GestureDetector(
              onLongPress: isMine ? () => _showMessageOptions(message) : null,
              child: Column(
                crossAxisAlignment: isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  if (!isMine)
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 4),
                      child: Text(
                        message.senderName,
                        style: const TextStyle(fontSize: 11, color: Colors.white54, fontWeight: FontWeight.bold),
                      ),
                    ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: isMine ? const Color(0xFF3B82F6) : const Color(0xFF1E293B),
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(16),
                        topRight: const Radius.circular(16),
                        bottomLeft: Radius.circular(isMine ? 16 : 4),
                        bottomRight: Radius.circular(isMine ? 4 : 16),
                      ),
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
                                  width: 200,
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
                              width: 200,
                              height: 120,
                              decoration: BoxDecoration(
                                color: Colors.black26,
                                borderRadius: BorderRadius.circular(8),
                                image: DecorationImage(
                                  image: NetworkImage(CloudinaryService.getVideoThumbnail(message.mediaUrl!)),
                                  fit: BoxFit.cover,
                                  opacity: 0.6,
                                ),
                              ),
                              child: const Center(
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    Icon(Icons.play_circle_fill, size: 50, color: Colors.white),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        if (message.text.isNotEmpty)
                          Padding(
                            padding: EdgeInsets.only(top: message.mediaUrl != null ? 8.0 : 0.0),
                            child: Text(message.text, style: const TextStyle(color: Colors.white, fontSize: 14)),
                          ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 4, left: 4, right: 4),
                    child: Text(
                      "${message.createdAt.hour}:${message.createdAt.minute.toString().padLeft(2, '0')}",
                      style: const TextStyle(fontSize: 9, color: Colors.white24),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isMine) ...[
            const SizedBox(width: 10),
            CircleAvatar(
              radius: 18,
              backgroundImage: profileImage,
              child: profileImage == null ? const Icon(Icons.person, size: 18) : null,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.05))),
      ),
      child: SafeArea(
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.add_circle_outline, color: Colors.white54),
              onPressed: () => _showMediaOptions(),
            ),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: TextField(
                  controller: _messageController,
                  decoration: InputDecoration(
                    hintText: 'Message # ${widget.channelName}',
                    hintStyle: const TextStyle(color: Colors.white24, fontSize: 14),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  style: const TextStyle(color: Colors.white),
                  maxLines: null,
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: _isSending ? null : () => _sendMessage(),
              icon: _isSending 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.send, color: Color(0xFF3B82F6)),
            ),
          ],
        ),
      ),
    );
  }

  void _showMediaOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt, color: Colors.greenAccent),
                title: const Text('Take Photo', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  _pickMedia(MessageType.image, ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.videocam, color: Colors.redAccent),
                title: const Text('Record Video (Max 30s)', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  _pickMedia(MessageType.video, ImageSource.camera);
                },
              ),
              const Divider(color: Colors.white10),
              ListTile(
                leading: const Icon(Icons.photo_library, color: Colors.blueAccent),
                title: const Text('Choose Image from Gallery', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  _pickMedia(MessageType.image, ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.video_library, color: Colors.purpleAccent),
                title: const Text('Choose Video from Gallery', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  _pickMedia(MessageType.video, ImageSource.gallery);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  ImageProvider? _decodeProfileImage(String base64) {
    if (base64.isEmpty) return null;
    try {
      return MemoryImage(base64Decode(base64));
    } catch (_) {
      return null;
    }
  }
}
