import 'dart:async';
import 'dart:convert';
import 'package:audioplayers/audioplayers.dart' as ap;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:media_kit/media_kit.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/chat/chat_message.dart';
import '../../services/chat/chat_service.dart';
import '../../services/chat/cloudinary_service.dart';
import '../../services/match/match_service.dart';
import '../../services/match/report_service.dart';
import 'full_screen_image_view.dart';
import '../profile/public_user_profile_view.dart';
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
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  StreamSubscription<List<ChatMessage>>? _messageSubscription;
  bool _isSending = false;
  bool _isSearching = false;
  String _searchQuery = '';
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
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

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
      Navigator.pop(context);

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
        Navigator.pop(context);
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

      if (latestMessage.receiverUid == currentUid &&
          _lastReadMessageId != latestMessage.id) {
        _lastReadMessageId = latestMessage.id;
        unawaited(_markConversationRead());
      }

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

        if (mounted) Navigator.pop(context);

        await _chatService.sendMediaMessage(
          targetUserUid: widget.targetUserUid,
          type: type,
          mediaUrl: mediaUrl,
        );
        _scrollToBottom();
      } catch (e) {
        if (mounted) Navigator.pop(context);
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
        0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<String, dynamic>?>(
      stream: _chatService.watchChatDoc(widget.targetUserUid),
      builder: (context, chatDocSnapshot) {
        final chatDocData = chatDocSnapshot.data;
        final currentUid = _chatService.currentUserUid;
        final mutedBy = chatDocData?['mutedBy'];
        final isMuted = mutedBy is Map && (mutedBy[currentUid] == true);

        return Scaffold(
          backgroundColor: const Color(0xFF0F172A),
          appBar: AppBar(
            title: _isSearching
                ? TextField(
                    controller: _searchController,
                    autofocus: true,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      hintText: 'Search in conversation...',
                      hintStyle: TextStyle(color: Colors.white38),
                      border: InputBorder.none,
                    ),
                    onChanged: (val) {
                      setState(() {
                        _searchQuery = val.trim();
                      });
                    },
                  )
                : StreamBuilder<MatchPairData?>(
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
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        widget.targetUserName,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      if (isMuted) ...[
                                        const SizedBox(width: 6),
                                        const Icon(
                                          Icons.notifications_off_outlined,
                                          size: 15,
                                          color: Colors.white38,
                                        ),
                                      ],
                                    ],
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
              IconButton(
                icon: Icon(_isSearching ? Icons.close : Icons.search, color: Colors.white70),
                tooltip: _isSearching ? 'Close search' : 'Search in chat',
                onPressed: () {
                  setState(() {
                    _isSearching = !_isSearching;
                    if (!_isSearching) {
                      _searchQuery = '';
                      _searchController.clear();
                    }
                  });
                },
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: Colors.white70),
                color: const Color(0xFF1E293B),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                onSelected: (val) async {
                  if (val == 'profile') {
                    _openTargetUserProfile();
                  } else if (val == 'mute') {
                    try {
                      await _chatService.toggleMuteChat(widget.targetUserUid, !isMuted);
                      if (mounted) {
                        _showError(!isMuted ? 'Chat notifications muted.' : 'Chat notifications unmuted.');
                      }
                    } catch (e) {
                      _showError(e.toString());
                    }
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
                  PopupMenuItem(
                    value: 'mute',
                    child: Row(
                      children: [
                        Icon(
                          isMuted ? Icons.notifications_active_outlined : Icons.notifications_off_outlined,
                          color: isMuted ? const Color(0xFF38BDF8) : Colors.orangeAccent,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          isMuted ? 'Unmute Chat' : 'Mute Chat',
                          style: const TextStyle(color: Colors.white),
                        ),
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
              if (_isSearching && _searchQuery.isNotEmpty)
                Container(
                  width: double.infinity,
                  color: const Color(0xFF1E293B),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.search, size: 16, color: Color(0xFF38BDF8)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Searching for "$_searchQuery"',
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
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

                    final allMessages = snapshot.data!;
                    final messages = _isSearching && _searchQuery.isNotEmpty
                        ? allMessages
                            .where((m) => m.text.toLowerCase().contains(_searchQuery.toLowerCase()))
                            .toList()
                        : allMessages;

                    if (messages.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _isSearching ? Icons.search_off : Icons.chat_bubble_outline,
                              size: 54,
                              color: Colors.white30,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _isSearching ? 'No matching messages found.' : 'No messages yet.',
                              style: const TextStyle(color: Colors.white60),
                            ),
                          ],
                        ),
                      );
                    }

                    final displayMessages = messages.reversed.toList();

                    return ListView.builder(
                      controller: _scrollController,
                      reverse: true,
                      padding: const EdgeInsets.all(16),
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      itemCount: displayMessages.length,
                      itemBuilder: (context, index) {
                        return _buildMessage(displayMessages[index], chatDocData);
                      },
                    );
                  },
                ),
              ),
              _buildMessageInput(),
            ],
          ),
        );
      },
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
            IconButton(
              icon: const Icon(
                Icons.add_photo_alternate_outlined,
                color: Color(0xFF38BDF8),
                size: 26,
              ),
              tooltip: 'Send Photo or Video',
              onPressed: _showMediaPickerOptions,
            ),
            IconButton(
              icon: const Icon(
                Icons.mic_none_outlined,
                color: Color(0xFF38BDF8),
                size: 26,
              ),
              tooltip: 'Record Voice Note',
              onPressed: _showVoiceRecorderSheet,
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

  Future<void> _showVoiceRecorderSheet() async {
    final audioRecorder = AudioRecorder();

    if (!await audioRecorder.hasPermission()) {
      _showError('Microphone permission is required to record voice notes.');
      return;
    }

    String? recordPath;
    try {
      if (!kIsWeb) {
        try {
          final tempDir = await getTemporaryDirectory();
          recordPath = '${tempDir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
        } catch (_) {
          recordPath = '';
        }
      } else {
        recordPath = '';
      }

      await audioRecorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc),
        path: recordPath,
      );
    } catch (e) {
      _showError('Unable to start recording: $e');
      return;
    }

    int durationSeconds = 0;
    bool isRecording = true;
    Timer? timer;

    if (!mounted) return;

    final result = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      isDismissible: false,
      enableDrag: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            timer ??= Timer.periodic(const Duration(seconds: 1), (t) {
              if (isRecording) {
                setSheetState(() {
                  durationSeconds++;
                });
              }
            });

            final minutes = (durationSeconds ~/ 60).toString().padLeft(2, '0');
            final seconds = (durationSeconds % 60).toString().padLeft(2, '0');

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Recording Voice Note',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: const BoxDecoration(
                            color: Colors.redAccent,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '$minutes:$seconds',
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () async {
                            isRecording = false;
                            timer?.cancel();
                            await audioRecorder.stop();
                            if (context.mounted) {
                              Navigator.pop(sheetContext, null);
                            }
                          },
                          icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                          label: const Text('Cancel', style: TextStyle(color: Colors.redAccent)),
                        ),
                        FilledButton.icon(
                          onPressed: durationSeconds > 0
                              ? () async {
                                  isRecording = false;
                                  timer?.cancel();
                                  recordPath = await audioRecorder.stop();
                                  if (context.mounted) {
                                    Navigator.pop(sheetContext, durationSeconds);
                                  }
                                }
                              : null,
                          icon: const Icon(Icons.send),
                          label: const Text('Send Voice Note'),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF3B82F6),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    timer?.cancel();
    await audioRecorder.dispose();

    if (result != null && result > 0 && recordPath != null && mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: Card(
            color: Color(0xFF1E293B),
            child: Padding(
              padding: EdgeInsets.all(20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text(
                    'Uploading Voice Note...',
                    style: TextStyle(color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      try {
        final xFile = XFile(recordPath!);
        final mediaUrl = await CloudinaryService.uploadMedia(xFile, isAudio: true);

        if (mounted) {
          Navigator.pop(context);
        }

        setState(() => _isSending = true);
        await _chatService.sendVoiceMessage(
          targetUserUid: widget.targetUserUid,
          mediaUrl: mediaUrl,
          durationSeconds: result,
        );
        _scrollToBottom();
      } catch (e) {
        if (mounted) {
          Navigator.pop(context);
        }
        _showError('Unable to send voice note: $e');
      } finally {
        if (mounted) setState(() => _isSending = false);
      }
    }
  }

  Widget _buildStatusTicks(ChatMessage message, Map<String, dynamic>? chatDocData) {
    if (message.senderUid != _chatService.currentUserUid) {
      return const SizedBox.shrink();
    }

    final targetUserUid = widget.targetUserUid;
    final lastReadAtTimestamp = (chatDocData?['lastReadAt'] as Map?)?[targetUserUid] as Timestamp?;
    final lastReadAt = lastReadAtTimestamp?.toDate();
    final createdAt = message.createdAt ?? DateTime.now();

    final isRead = lastReadAt != null && !lastReadAt.isBefore(createdAt);

    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Icon(
        Icons.done_all,
        size: 14,
        color: isRead ? const Color(0xFF38BDF8) : Colors.white38,
      ),
    );
  }

  void _showMessageOptions(ChatMessage message) {
    final isMine = message.senderUid == _chatService.currentUserUid;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isMine && message.type == ChatMessageType.text)
                  ListTile(
                    leading: const Icon(Icons.edit_outlined, color: Color(0xFF38BDF8)),
                    title: const Text('Edit Message', style: TextStyle(color: Colors.white)),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      _showEditMessageDialog(message);
                    },
                  ),
                if (isMine)
                  ListTile(
                    leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
                    title: const Text('Delete Message', style: TextStyle(color: Colors.redAccent)),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      _confirmDeleteMessage(message);
                    },
                  ),
                ListTile(
                  leading: const Icon(Icons.info_outline, color: Colors.white70),
                  title: const Text('Message Info', style: TextStyle(color: Colors.white)),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _showMessageInfoDialog(message);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showEditMessageDialog(ChatMessage message) {
    final controller = TextEditingController(text: message.text);

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: const Row(
            children: [
              Icon(Icons.edit, color: Color(0xFF38BDF8)),
              SizedBox(width: 8),
              Text('Edit Message', style: TextStyle(color: Colors.white)),
            ],
          ),
          content: TextField(
            controller: controller,
            maxLines: 3,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: 'Type new text...',
              hintStyle: TextStyle(color: Colors.white38),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final newText = controller.text.trim();
                if (newText.isNotEmpty && newText != message.text) {
                  Navigator.pop(dialogContext);
                  try {
                    await _chatService.editTextMessage(message, newText);
                  } catch (e) {
                    _showError(e.toString());
                  }
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _confirmDeleteMessage(ChatMessage message) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: const Text('Delete Message?', style: TextStyle(color: Colors.white)),
          content: const Text(
            'This will delete the message for everyone in this chat.',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
              onPressed: () async {
                Navigator.pop(dialogContext);
                try {
                  await _chatService.deleteMessage(message);
                } catch (e) {
                  _showError(e.toString());
                }
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  void _showMessageInfoDialog(ChatMessage message) {
    final createdAt = message.createdAt ?? DateTime.now();
    final formattedDate =
        "${createdAt.day.toString().padLeft(2, '0')}/${createdAt.month.toString().padLeft(2, '0')}/${createdAt.year} at ${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}:${createdAt.second.toString().padLeft(2, '0')}";

    final isMine = message.senderUid == _chatService.currentUserUid;
    final senderName = isMine ? 'You' : widget.targetUserName;

    String typeLabel = 'Text message';
    if (message.type == ChatMessageType.image) typeLabel = 'Photo';
    if (message.type == ChatMessageType.video) typeLabel = 'Video';
    if (message.type == ChatMessageType.voice) typeLabel = 'Voice note';
    if (message.type == ChatMessageType.meetingProposal) typeLabel = 'Meeting proposal';

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: const Row(
            children: [
              Icon(Icons.info_outline, color: Color(0xFF38BDF8)),
              SizedBox(width: 8),
              Text('Message Info', style: TextStyle(color: Colors.white)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _infoRow('Sender:', senderName),
              const SizedBox(height: 12),
              _infoRow('Type:', typeLabel),
              const SizedBox(height: 12),
              _infoRow('Created Date:', formattedDate),
              if (message.isEdited) ...[
                const SizedBox(height: 12),
                _infoRow('Edited:', 'Yes'),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Widget _infoRow(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.white54)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
      ],
    );
  }

  /// Render Message Item matching Interest Channel stream layout
  Widget _buildMessage(ChatMessage message, Map<String, dynamic>? chatDocData) {
    if (message.type == ChatMessageType.system) {
      return _buildSystemMessage(message);
    }

    final isMine = message.senderUid == _chatService.currentUserUid;
    final createdAt = message.createdAt ?? DateTime.now();
    final timeStr = "${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}";
    final statusTicks = _buildStatusTicks(message, chatDocData);

    final avatar = GestureDetector(
      onTap: isMine ? null : _openTargetUserProfile,
      child: CircleAvatar(
        radius: 18,
        backgroundColor: isMine ? const Color(0xFF2563EB) : const Color(0xFF64748B),
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
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isMine) ...[
            avatar,
            const SizedBox(width: 10),
          ],

          Flexible(
            child: Column(
              crossAxisAlignment: isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
                  children: [
                    if (isMine) ...[
                      if (message.isEdited)
                        const Padding(
                          padding: EdgeInsets.only(right: 4),
                          child: Text(
                            '(edited)',
                            style: TextStyle(fontSize: 10, color: Colors.white38, fontStyle: FontStyle.italic),
                          ),
                        ),
                      Text(
                        timeStr,
                        style: const TextStyle(fontSize: 10, color: Colors.white38),
                      ),
                      statusTicks,
                      const SizedBox(width: 8),
                      const Text(
                        "You",
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF3B82F6),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ] else ...[
                      GestureDetector(
                        onTap: _openTargetUserProfile,
                        child: Text(
                          widget.targetUserName,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF38BDF8),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        timeStr,
                        style: const TextStyle(fontSize: 10, color: Colors.white38),
                      ),
                      if (message.isEdited)
                        const Padding(
                          padding: EdgeInsets.only(left: 4),
                          child: Text(
                            '(edited)',
                            style: TextStyle(fontSize: 10, color: Colors.white38, fontStyle: FontStyle.italic),
                          ),
                        ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),

                _buildMessageContent(message, isMine),
              ],
            ),
          ),

          if (isMine) ...[
            const SizedBox(width: 10),
            avatar,
          ],
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
      case ChatMessageType.voice:
        return _buildVoiceContent(message, isMine: isMine);
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

  Widget _buildVoiceContent(ChatMessage message, {required bool isMine}) {
    return GestureDetector(
      onLongPress: () => _showMessageOptions(message),
      child: _VoiceMessagePlayerCard(
        message: message,
        isMine: isMine,
      ),
    );
  }

  Widget _buildTextContent(ChatMessage message, bool isMine) {
    return GestureDetector(
      onLongPress: () => _showMessageOptions(message),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isMine ? const Color(0xFF2563EB) : const Color(0xFF1E293B),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(14),
            topRight: const Radius.circular(14),
            bottomLeft: Radius.circular(isMine ? 14 : 4),
            bottomRight: Radius.circular(isMine ? 4 : 14),
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
                        child: SmartChatImage(
                          imageUrl: mediaUrl,
                          width: 220,
                          height: 200,
                          fit: BoxFit.cover,
                        ),
                      ),
                    )),
        ),
      ),
    );
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

class SmartChatImage extends StatefulWidget {
  const SmartChatImage({
    super.key,
    required this.imageUrl,
    this.width = 220,
    this.height = 200,
    this.fit = BoxFit.cover,
  });

  final String imageUrl;
  final double width;
  final double height;
  final BoxFit fit;

  @override
  State<SmartChatImage> createState() => _SmartChatImageState();
}

class _SmartChatImageState extends State<SmartChatImage> {
  int _retryCount = 0;
  bool _hasError = false;
  Timer? _retryTimer;

  @override
  void dispose() {
    _retryTimer?.cancel();
    super.dispose();
  }

  void _scheduleRetry() {
    if (_retryCount >= 10 || _retryTimer != null) return;
    _retryTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _retryCount++;
          _hasError = false;
          _retryTimer = null;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      _scheduleRetry();
      return Container(
        width: widget.width,
        height: widget.height,
        color: const Color(0xFF0F172A),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF38BDF8)),
              ),
              SizedBox(height: 8),
              Text(
                'Syncing photo...',
                style: TextStyle(color: Colors.white54, fontSize: 11),
              ),
            ],
          ),
        ),
      );
    }

    return Image.network(
      widget.imageUrl,
      key: ValueKey('${widget.imageUrl}_$_retryCount'),
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Container(
          width: widget.width,
          height: widget.height,
          color: const Color(0xFF0F172A),
          child: Center(
            child: CircularProgressIndicator(
              value: loadingProgress.expectedTotalBytes != null
                  ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                  : null,
              strokeWidth: 2,
              color: const Color(0xFF38BDF8),
            ),
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && !_hasError) {
            setState(() {
              _hasError = true;
            });
          }
        });
        return Container(
          width: widget.width,
          height: widget.height,
          color: const Color(0xFF0F172A),
          child: const Center(
            child: Icon(Icons.broken_image_outlined, color: Colors.white24, size: 28),
          ),
        );
      },
    );
  }
}

class _VoiceMessagePlayerCard extends StatefulWidget {
  const _VoiceMessagePlayerCard({
    required this.message,
    required this.isMine,
  });

  final ChatMessage message;
  final bool isMine;

  @override
  State<_VoiceMessagePlayerCard> createState() => _VoiceMessagePlayerCardState();
}

class _VoiceMessagePlayerCardState extends State<_VoiceMessagePlayerCard> {
  final ap.AudioPlayer _audioPlayer = ap.AudioPlayer();
  ap.PlayerState _playerState = ap.PlayerState.stopped;
  double _playbackSpeed = 1.0;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  StreamSubscription? _playerStateSubscription;
  StreamSubscription? _positionSubscription;
  StreamSubscription? _durationSubscription;

  @override
  void initState() {
    super.initState();
    _playerStateSubscription = _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          _playerState = state;
        });
      }
    });

    _positionSubscription = _audioPlayer.onPositionChanged.listen((p) {
      if (mounted) {
        setState(() {
          _position = p;
        });
      }
    });

    _durationSubscription = _audioPlayer.onDurationChanged.listen((d) {
      if (mounted) {
        setState(() {
          _duration = d;
        });
      }
    });
  }

  @override
  void dispose() {
    _playerStateSubscription?.cancel();
    _positionSubscription?.cancel();
    _durationSubscription?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _togglePlay() async {
    if (_playerState == ap.PlayerState.playing) {
      await _audioPlayer.pause();
    } else {
      final url = widget.message.mediaUrl;
      if (url != null && url.isNotEmpty) {
        await _audioPlayer.setPlaybackRate(_playbackSpeed);
        await _audioPlayer.play(ap.UrlSource(url));
      }
    }
  }

  Future<void> _toggleSpeed() async {
    final speeds = [1.0, 1.5, 2.0];
    final nextIndex = (speeds.indexOf(_playbackSpeed) + 1) % speeds.length;
    final newSpeed = speeds[nextIndex];
    setState(() {
      _playbackSpeed = newSpeed;
    });
    if (_playerState == ap.PlayerState.playing) {
      await _audioPlayer.setPlaybackRate(newSpeed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPlaying = _playerState == ap.PlayerState.playing;

    return Container(
      constraints: const BoxConstraints(maxWidth: 260),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: widget.isMine ? const Color(0xFF1E3A8A) : const Color(0xFF1E293B),
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(14),
          topRight: const Radius.circular(14),
          bottomLeft: Radius.circular(widget.isMine ? 14 : 4),
          bottomRight: Radius.circular(widget.isMine ? 4 : 14),
        ),
        border: widget.isMine
            ? Border.all(color: const Color(0xFF3B82F6).withValues(alpha: 0.5), width: 1)
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: _togglePlay,
            icon: Icon(
              isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill,
              size: 34,
              color: const Color(0xFF38BDF8),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: List.generate(
                    10,
                    (index) => Expanded(
                      child: Container(
                        height: (index % 3 + 1) * 5.0 + (isPlaying ? (index % 2 * 4) : 0),
                        margin: const EdgeInsets.symmetric(horizontal: 1.0),
                        decoration: BoxDecoration(
                          color: isPlaying ? const Color(0xFF38BDF8) : Colors.white70,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isPlaying
                      ? "${_position.inSeconds}s / ${_duration.inSeconds > 0 ? _duration.inSeconds : widget.message.text.replaceAll(RegExp(r'[^\d]'), '')}s"
                      : widget.message.text,
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          InkWell(
            onTap: _toggleSpeed,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white12,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '${_playbackSpeed}x',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
