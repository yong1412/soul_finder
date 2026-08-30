import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/channel.dart';
import '../services/channel_service.dart';
import '../controllers/auth_controller.dart';

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
  bool _isSending = false;

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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent),
      );
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _pickMedia(MessageType type) async {
    final XFile? file = type == MessageType.image 
        ? await _picker.pickImage(source: ImageSource.gallery)
        : await _picker.pickVideo(source: ImageSource.gallery);

    if (file != null) {
      // FOR TEST: We don't have Firebase Storage yet, so we use a placeholder URL
      // In a real app, you would upload to Firebase Storage and get the URL
      final dummyUrl = type == MessageType.image 
          ? "https://images.unsplash.com/photo-1514888286974-6c03e2ca1dba?q=80&w=500" // A cat image
          : "https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4"; // A sample video

      await _sendMessage(
        type: type,
        mediaUrl: dummyUrl,
      );
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
              stream: _channelService.watchMessages(widget.channelId),
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
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            message.mediaUrl!,
                            width: 200,
                            height: 200,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => 
                              const Icon(Icons.broken_image, color: Colors.white24),
                          ),
                        ),
                      if (message.type == MessageType.video && message.mediaUrl != null)
                        Container(
                          width: 200,
                          height: 120,
                          decoration: BoxDecoration(
                            color: Colors.black26,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Center(
                            child: Icon(Icons.play_circle_fill, size: 50, color: Colors.white70),
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
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.image, color: Colors.blue),
                title: const Text('Send Image'),
                onTap: () {
                  Navigator.pop(context);
                  _pickMedia(MessageType.image);
                },
              ),
              ListTile(
                leading: const Icon(Icons.videocam, color: Colors.red),
                title: const Text('Send Video'),
                onTap: () {
                  Navigator.pop(context);
                  _pickMedia(MessageType.video);
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
