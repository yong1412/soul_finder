import 'package:flutter/material.dart';
import '../../controllers/auth_controller.dart';
import '../../models/channel.dart';
import '../../services/channel_service.dart';
import '../channel_conversation_view.dart';

class InterestChannelsView extends StatefulWidget {
  const InterestChannelsView({
    super.key,
    required this.authController,
  });

  final AuthController authController;

  @override
  State<InterestChannelsView> createState() => _InterestChannelsViewState();
}

class _InterestChannelsViewState extends State<InterestChannelsView> {
  final ChannelService _channelService = ChannelService();
  Stream<List<InterestChannel>>? _channelsStream;
  List<String>? _lastInterests;

  void _updateChannelsStreamIfNeeded() {
    final user = widget.authController.currentUser;
    if (user != null) {
      if (_channelsStream == null || _lastInterests != user.interests) {
        _lastInterests = user.interests;
        _channelsStream = _channelService.watchMyChannels(user.interests);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    _updateChannelsStreamIfNeeded();

    final user = widget.authController.currentUser;
    if (user == null) return const SizedBox.shrink();

    return StreamBuilder<List<InterestChannel>>(
      stream: _channelsStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildErrorState(snapshot.error.toString());
        }

        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

        final channels = snapshot.data!;
        if (channels.isEmpty) {
          return _buildEmptyState(
            icon: Icons.tag,
            title: 'No Interests Found',
            subtitle: 'Add interests to your profile to join global channels.',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: channels.length,
          itemBuilder: (context, index) {
            final channel = channels[index];
            return ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              leading: Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Theme.of(context).colorScheme.primary, Theme.of(context).colorScheme.secondary],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.tag, color: Colors.white, size: 28),
              ),
              title: Text(
                '# ${channel.name}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
              ),
              subtitle: Text(
                channel.lastMessage ?? channel.description,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white60),
              ),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (channel.lastMessageAt != null)
                    Text(
                      _formatMessageTime(channel.lastMessageAt),
                      style: const TextStyle(color: Colors.white38, fontSize: 11),
                    ),
                  const SizedBox(height: 4),
                  const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.white12),
                ],
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ChannelConversationView(
                      channelId: channel.id,
                      channelName: channel.name,
                      authController: widget.authController,
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyState({required IconData icon, required String title, required String subtitle}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 60, color: Colors.white10),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white38),
            ),
            const SizedBox(height: 8),
            Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white24)),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text('Error: $error', textAlign: TextAlign.center, style: const TextStyle(color: Colors.redAccent)),
      ),
    );
  }

  String _formatMessageTime(DateTime? dateTime) {
    if (dateTime == null) return '';
    final localTime = dateTime.toLocal();
    final now = DateTime.now();
    if (localTime.year == now.year && localTime.month == now.month && localTime.day == now.day) {
      return "${localTime.hour}:${localTime.minute.toString().padLeft(2, '0')}";
    }
    return '${localTime.day}/${localTime.month}';
  }
}
