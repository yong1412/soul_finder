import 'package:flutter/material.dart';
import '../../controllers/auth_controller.dart';
import '../../models/channel.dart';
import '../../models/event_hotspot.dart';
import '../../services/channel_service.dart';
import '../../services/event_hotspot_service.dart';
import '../../widgets/marquee_text.dart';
import '../channel_conversation_view.dart';
import '../station_map_view.dart';

class ChannelsView extends StatefulWidget {
  const ChannelsView({
    super.key,
    required this.authController,
  });

  final AuthController authController;

  @override
  State<ChannelsView> createState() => _ChannelsViewState();
}

class _ChannelsViewState extends State<ChannelsView> {
  final ChannelService _channelService = ChannelService();
  final EventHotspotService _eventService = EventHotspotService();

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

    return ListenableBuilder(
      listenable: _eventService,
      builder: (context, _) {
        final events = _eventService.events;

        return StreamBuilder<List<InterestChannel>>(
          stream: _channelsStream,
          builder: (context, snapshot) {
            final channels = snapshot.data ?? [];

            return ListView(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              children: [
                // 1. Collapsible Section 1: Event Channels
                _buildCollapsibleEventChannels(events),

                const SizedBox(height: 12),

                // 2. Collapsible Section 2: Interest Channels
                _buildCollapsibleInterestChannels(channels, snapshot.connectionState == ConnectionState.waiting),
              ],
            );
          },
        );
      },
    );
  }

  /// 1. Collapsible Event Channels Section
  Widget _buildCollapsibleEventChannels(List<EventHotspot> events) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.2)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: true, // 可收放，默认展开
          iconColor: const Color(0xFF38BDF8),
          collapsedIconColor: Colors.white54,
          title: Row(
            children: [
              const Icon(Icons.local_fire_department, color: Color(0xFF38BDF8), size: 20),
              const SizedBox(width: 8),
              Text(
                'Event Channels (${events.length})',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          children: events.isEmpty
              ? [
                  const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text(
                      'No active event channels at the moment.',
                      style: TextStyle(color: Colors.white38, fontSize: 13),
                    ),
                  ),
                ]
              : events.map((event) => _buildEventChannelTile(event)).toList(),
        ),
      ),
    );
  }

  Widget _buildEventChannelTile(EventHotspot event) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF38BDF8), Color(0xFF0284C7)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.event_available, color: Colors.white, size: 24),
      ),
      title: MarqueeText(
        text: event.eventTitle,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 15,
          color: Colors.white,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 2),
          MarqueeText(
            text: '📍 ${event.name}', // Serimas Condo • Pearl Tower
            style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 12),
          ),
          const SizedBox(height: 2),
          Text(
            '👍 ${event.interestedCount} interested • 👥 ${event.activeAttendees} active',
            style: const TextStyle(color: Colors.white38, fontSize: 11),
          ),
        ],
      ),
      trailing: IconButton(
        icon: const Icon(Icons.map_outlined, color: Color(0xFF38BDF8), size: 20),
        tooltip: 'View Location',
        onPressed: () {
          _showEventDetailsModal(event);
        },
      ),
      onTap: () {
        _showEventDetailsModal(event);
      },
    );
  }

  /// 2. Collapsible Interest Channels Section
  Widget _buildCollapsibleInterestChannels(List<InterestChannel> channels, bool isLoading) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: true, // 可收放，默认展开
          iconColor: const Color(0xFF3B82F6),
          collapsedIconColor: Colors.white54,
          title: Row(
            children: [
              const Icon(Icons.tag, color: Color(0xFF3B82F6), size: 20),
              const SizedBox(width: 8),
              Text(
                'Interest Channels (${channels.length})',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          children: isLoading
              ? [
                  const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: CircularProgressIndicator(),
                  )
                ]
              : (channels.isEmpty
                  ? [
                      const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text(
                          'No interest channels joined yet. Add interests in your profile!',
                          style: TextStyle(color: Colors.white38, fontSize: 13),
                        ),
                      )
                    ]
                  : channels.map((channel) => _buildInterestChannelTile(channel)).toList()),
        ),
      ),
    );
  }

  Widget _buildInterestChannelTile(InterestChannel channel) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Theme.of(context).colorScheme.primary, Theme.of(context).colorScheme.secondary],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.tag, color: Colors.white, size: 24),
      ),
      title: Text(
        '# ${channel.name}',
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white),
      ),
      subtitle: Text(
        channel.lastMessage ?? channel.description,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: Colors.white60, fontSize: 12),
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
          const Icon(Icons.arrow_forward_ios, size: 12, color: Colors.white24),
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
  }

  /// Event Details Modal with Map Navigation Action
  void _showEventDetailsModal(EventHotspot event) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF38BDF8).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.local_fire_department, color: Color(0xFF38BDF8), size: 16),
                        SizedBox(width: 4),
                        Text(
                          'EVENT CHANNEL',
                          style: TextStyle(
                            color: Color(0xFF38BDF8),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                event.eventTitle,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.place, color: Color(0xFFF43F5E), size: 16),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      event.name, // "Serimas Condo • Pearl Tower"
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFCBD5E1),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                '📍 Details: ${event.description}',
                style: const TextStyle(color: Colors.white54, fontSize: 13),
              ),
              const SizedBox(height: 12),
              Text(
                '👍 Interested: ${event.interestedCount} souls  •  👥 Active Now: ${event.activeAttendees}',
                style: const TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.bold, fontSize: 12),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => StationMapView(
                          initialTarget: null,
                          targetEvent: event,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.map_outlined, size: 18),
                  label: const Text('View Location on Map'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF38BDF8),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        );
      },
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
