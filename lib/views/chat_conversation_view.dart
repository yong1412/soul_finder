import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/chat_message.dart';
import '../services/chat_service.dart';

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
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  StreamSubscription<List<ChatMessage>>? _messageSubscription;
  bool _isSending = false;
  String? _lastReadMessageId;

  @override
  void initState() {
    super.initState();
    _setupMessageListener();
  }

  @override
  void dispose() {
    _messageSubscription?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
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

  Future<void> _openLocation(String location) async {
    final trimmed = location.trim();
    final parsedUri = Uri.tryParse(trimmed);

    final isWebLink = parsedUri != null &&
        parsedUri.hasScheme &&
        (parsedUri.scheme == 'https' || parsedUri.scheme == 'http');

    final Uri uri = isWebLink
        ? parsedUri
        : Uri.https(
      'www.google.com',
      '/maps/search/',
      {
        'api': '1',
        'query': trimmed,
      },
    );

    final opened = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );

    if (!opened) {
      _showError('Unable to open the map.');
    }
  }

  Future<void> _openProposalMap(ChatMessage message) async {
    final venue = message.venue;
    if (venue == null) return;

    final value = venue.mapsUrl.isNotEmpty
        ? venue.mapsUrl
        : '${venue.latitude},${venue.longitude}';
    await _openLocation(value);
  }

  void _showError(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
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
        title: Text(widget.targetUserName),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Chat information',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Only matched users can access this chat.',
                  ),
                ),
              );
            },
            icon: const Icon(Icons.info_outline),
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
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        decoration: const BoxDecoration(
          color: Color(0xFF1E293B),
          border: Border(
            top: BorderSide(color: Colors.white12),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _messageController,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendTextMessage(),
                decoration: InputDecoration(
                  hintText: 'Type a message',
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

  Widget _buildMessage(ChatMessage message) {
    switch (message.type) {
      case ChatMessageType.meetingProposal:
        return _buildStructuredProposal(message);
      case ChatMessageType.system:
        return _buildSystemMessage(message);
      case ChatMessageType.text:
        final sharedLocation = _SharedLocation.tryParse(message.text);
        if (sharedLocation != null) {
          return _buildSharedLocationCard(message, sharedLocation);
        }
        return _buildTextMessage(message);
    }
  }

  Widget _buildTextMessage(ChatMessage message) {
    final isMine = message.senderUid == _chatService.currentUserUid;

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 320),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        decoration: BoxDecoration(
          color: isMine
              ? const Color(0xFF2563EB)
              : const Color(0xFF1E293B),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isMine ? 18 : 4),
            bottomRight: Radius.circular(isMine ? 4 : 18),
          ),
        ),
        child: Text(message.text),
      ),
    );
  }

  Widget _buildSharedLocationCard(
      ChatMessage message,
      _SharedLocation location,
      ) {
    final isMine = message.senderUid == _chatService.currentUserUid;
    final hasResponded =
        message.status == MeetingProposalStatus.accepted ||
            message.status == MeetingProposalStatus.declined;
    final canRespond = !isMine && !hasResponded;

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 360),
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFF3B82F6)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                CircleAvatar(
                  backgroundColor: Color(0x333B82F6),
                  child: Icon(
                    Icons.location_on,
                    color: Color(0xFF60A5FA),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Meeting Place Suggestion',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              location.name,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              location.category,
              style: const TextStyle(color: Color(0xFF60A5FA)),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(
                  Icons.link,
                  size: 18,
                  color: Colors.white60,
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    location.isLink
                        ? 'Map link ready'
                        : location.location,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white70),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _openLocation(location.location),
                icon: const Icon(Icons.map_outlined),
                label: const Text('Open Map'),
              ),
            ),
            if (canRespond) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _isSending
                          ? null
                          : () => _sendLocationResponse(
                        message: message,
                        accepted: true,
                      ),
                      icon: const Icon(Icons.check),
                      label: const Text('Accept'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isSending
                          ? null
                          : () => _sendLocationResponse(
                        message: message,
                        accepted: false,
                      ),
                      icon: const Icon(Icons.close),
                      label: const Text('Decline'),
                    ),
                  ),
                ],
              ),
            ] else if (hasResponded) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    message.status == MeetingProposalStatus.accepted
                        ? Icons.check_circle
                        : Icons.cancel,
                    color: message.status == MeetingProposalStatus.accepted
                        ? Colors.greenAccent
                        : Colors.redAccent,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    message.status == MeetingProposalStatus.accepted
                        ? 'Meeting place accepted'
                        : 'Meeting place declined',
                    style: TextStyle(
                      color:
                      message.status == MeetingProposalStatus.accepted
                          ? Colors.greenAccent
                          : Colors.redAccent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ] else ...[
              const SizedBox(height: 4),
              const Text(
                'Waiting for a response',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSystemMessage(ChatMessage message) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white10,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          message.text,
          style: const TextStyle(color: Colors.white60, fontSize: 12),
        ),
      ),
    );
  }

  Widget _buildStructuredProposal(ChatMessage message) {
    final venue = message.venue;
    if (venue == null) return const SizedBox.shrink();

    final isMine = message.senderUid == _chatService.currentUserUid;
    final canRespond =
        !isMine && message.status == MeetingProposalStatus.pending;

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 360),
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _proposalColor(message.status)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.location_on, color: Color(0xFF60A5FA)),
                SizedBox(width: 8),
                Text(
                  'Meeting Place Proposal',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              venue.name,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              venue.category,
              style: const TextStyle(color: Color(0xFF60A5FA)),
            ),
            const SizedBox(height: 5),
            Text(
              venue.address,
              style: const TextStyle(color: Colors.white60),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => _openProposalMap(message),
              icon: const Icon(Icons.map_outlined),
              label: const Text('Open Map'),
            ),
            if (canRespond) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  FilledButton(
                    onPressed: () => _respondToProposal(
                      message,
                      MeetingProposalStatus.accepted,
                    ),
                    child: const Text('Accept'),
                  ),
                  OutlinedButton(
                    onPressed: () => _respondToProposal(
                      message,
                      MeetingProposalStatus.declined,
                    ),
                    child: const Text('Decline'),
                  ),
                ],
              ),
            ] else ...[
              const SizedBox(height: 8),
              Text(
                _proposalLabel(message.status, isMine),
                style: TextStyle(
                  color: _proposalColor(message.status),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _proposalLabel(MeetingProposalStatus status, bool isMine) {
    switch (status) {
      case MeetingProposalStatus.pending:
        return isMine ? 'Waiting for response' : 'Response required';
      case MeetingProposalStatus.accepted:
        return 'Meeting confirmed';
      case MeetingProposalStatus.declined:
        return 'Proposal declined';
      case MeetingProposalStatus.counterProposed:
        return 'Another place requested';
      case MeetingProposalStatus.none:
        return '';
    }
  }

  Color _proposalColor(MeetingProposalStatus status) {
    switch (status) {
      case MeetingProposalStatus.accepted:
        return Colors.greenAccent;
      case MeetingProposalStatus.declined:
        return Colors.redAccent;
      case MeetingProposalStatus.counterProposed:
        return Colors.orangeAccent;
      case MeetingProposalStatus.pending:
        return const Color(0xFF60A5FA);
      case MeetingProposalStatus.none:
        return Colors.white30;
    }
  }
}

class _SharedLocation {
  const _SharedLocation({
    required this.name,
    required this.category,
    required this.location,
  });

  final String name;
  final String category;
  final String location;

  bool get isLink {
    final uri = Uri.tryParse(location);
    return uri != null &&
        uri.hasScheme &&
        (uri.scheme == 'https' || uri.scheme == 'http');
  }

  static _SharedLocation? tryParse(String text) {
    if (!text.startsWith('📍 MEETING PLACE SUGGESTION')) {
      return null;
    }

    String name = '';
    String category = '';
    String location = '';

    for (final rawLine in text.split('\n')) {
      final line = rawLine.trim();
      if (line.startsWith('Place:')) {
        name = line.substring('Place:'.length).trim();
      } else if (line.startsWith('Category:')) {
        category = line.substring('Category:'.length).trim();
      } else if (line.startsWith('Location:')) {
        location = line.substring('Location:'.length).trim();
      }
    }

    if (name.isEmpty || location.isEmpty) return null;

    return _SharedLocation(
      name: name,
      category: category.isEmpty ? 'Public place' : category,
      location: location,
    );
  }
}
