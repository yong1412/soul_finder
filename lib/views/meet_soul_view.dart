import 'package:flutter/material.dart';

import '../models/meeting_venue.dart';
import '../services/chat_service.dart';
import '../services/match_service.dart';
import '../widgets/match_meeting_map.dart';

class MeetSoulView extends StatefulWidget {
  const MeetSoulView({
    super.key,
    required this.targetUserUid,
    required this.soulName,
  });

  final String targetUserUid;
  final String soulName;

  @override
  State<MeetSoulView> createState() => _MeetSoulViewState();
}

class _MeetSoulViewState extends State<MeetSoulView> {
  final MatchService _matchService = MatchService();
  final ChatService _chatService = ChatService();

  bool _isSending = false;

  Future<void> _shareMeetingPlace(String category) async {
    if (_isSending) return;

    final nameController = TextEditingController();
    final locationController = TextEditingController();
    String? validationMessage;

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1E293B),
              title: Row(
                children: [
                  const Icon(
                    Icons.add_location_alt_outlined,
                    color: Color(0xFF38BDF8),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text('Share $category')),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Enter a specific public place. Copy its address or '
                          'sharing link from Google Maps.',
                      style: TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: nameController,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Place name',
                        hintText: 'Example: Starbucks KLCC',
                        prefixIcon: Icon(Icons.storefront_outlined),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: locationController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Address or Google Maps link',
                        hintText: 'Paste the public location here',
                        prefixIcon: Icon(Icons.map_outlined),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    if (validationMessage != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        validationMessage!,
                        style: const TextStyle(color: Colors.redAccent),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                FilledButton.icon(
                  onPressed: () {
                    final name = nameController.text.trim();
                    final location = locationController.text.trim();

                    if (name.isEmpty || location.isEmpty) {
                      setDialogState(() {
                        validationMessage =
                        'Enter both the place name and location.';
                      });
                      return;
                    }

                    Navigator.pop(dialogContext, {
                      'name': name,
                      'location': location,
                    });
                  },
                  icon: const Icon(Icons.send),
                  label: const Text('Send to Chat'),
                ),
              ],
            );
          },
        );
      },
    );

    nameController.dispose();
    locationController.dispose();

    if (result == null || !mounted) return;

    setState(() => _isSending = true);

    try {
      final location = result['location'] ?? '';
      final isLink = location.startsWith('http');

      await _chatService.sendMeetingProposal(
        targetUserUid: widget.targetUserUid,
        venue: MeetingVenue(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          name: result['name'] ?? 'Meeting place',
          category: category,
          address: isLink ? 'See map link' : location,
          latitude: 0,
          longitude: 0,
          mapsUrl: isLink ? location : '',
        ),
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Meeting location sent to ${widget.soulName}.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to send location: $error'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: Text('Meet ${widget.soulName}'),
        centerTitle: true,
      ),
      body: StreamBuilder<bool>(
        stream: _matchService.watchMatchStatus(widget.targetUserUid),
        builder: (context, matchSnapshot) {
          if (matchSnapshot.hasError) {
            return _MessageState(
              message: 'Unable to check match: ${matchSnapshot.error}',
              color: Colors.redAccent,
            );
          }

          if (!matchSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          if (matchSnapshot.data != true) {
            return const _MessageState(
              message:
              'Meeting planning is available after a mutual match.',
              color: Colors.white60,
            );
          }

          return StreamBuilder<MatchPairData?>(
            stream: _matchService.watchPair(widget.targetUserUid),
            builder: (context, pairSnapshot) {
              if (pairSnapshot.hasError) {
                return _MessageState(
                  message:
                  'Unable to load match details: ${pairSnapshot.error}',
                  color: Colors.redAccent,
                );
              }

              if (!pairSnapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final pair = pairSnapshot.data;
              if (pair == null) {
                return const _MessageState(
                  message: 'The matched profile was not found.',
                  color: Colors.white60,
                );
              }

              return _buildPlanner(pair);
            },
          );
        },
      ),
    );
  }

  Widget _buildPlanner(MatchPairData pair) {
    final distanceText = pair.distanceKm == null
        ? 'Distance unavailable'
        : '${pair.distanceKm!.toStringAsFixed(1)} km apart';

    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.all(18),
          children: [
            MatchMeetingMap(
              pair: pair,
              otherUserName: widget.soulName,
            ),
            const SizedBox(height: 12),
            Card(
              color: const Color(0xFF1E293B),
              child: ListTile(
                leading: const Icon(
                  Icons.sync,
                  color: Color(0xFF38BDF8),
                ),
                title: Text(
                  distanceText,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: const Text(
                  'Select a safe public meeting place near the midpoint.',
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Meeting suggestions',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Choose a category, then enter a specific public place and '
                  'its Google Maps link.',
              style: TextStyle(color: Colors.white60),
            ),
            const SizedBox(height: 14),
            _categoryCard(
              title: 'Public café',
              subtitle: 'Choose a named café in a public area',
              icon: Icons.local_cafe_outlined,
              color: const Color(0xFF38BDF8),
            ),
            _categoryCard(
              title: 'Shopping mall',
              subtitle: 'Choose a mall with public transport access',
              icon: Icons.shopping_bag_outlined,
              color: const Color(0xFFE879F9),
            ),
            _categoryCard(
              title: 'Library or community space',
              subtitle: 'Choose a public and easy-to-find place',
              icon: Icons.local_library_outlined,
              color: const Color(0xFFFF5C8A),
            ),
            const SizedBox(height: 8),
            const Card(
              color: Color(0xFF1E293B),
              child: ListTile(
                leading: Icon(
                  Icons.shield_outlined,
                  color: Color(0xFF22C55E),
                ),
                title: Text('Public location only'),
                subtitle: Text(
                  'Do not share either user\'s private live location. '
                      'The selected place will be sent to the shared chat.',
                ),
              ),
            ),
          ],
        ),
        if (_isSending)
          const Positioned.fill(
            child: ColoredBox(
              color: Color(0x77000000),
              child: Center(
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(18),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(width: 14),
                        Text('Sending to chat...'),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _categoryCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        color: const Color(0xFF1E293B),
        elevation: 0,
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 9,
          ),
          leading: CircleAvatar(
            backgroundColor: color.withValues(alpha: 0.18),
            child: Icon(icon, color: color),
          ),
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Text(subtitle),
          trailing: const Icon(Icons.send_outlined),
          onTap: () => _shareMeetingPlace(title),
        ),
      ),
    );
  }
}

class _MessageState extends StatelessWidget {
  const _MessageState({
    required this.message,
    required this.color,
  });

  final String message;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(color: color),
        ),
      ),
    );
  }
}
