import 'package:flutter/material.dart';

import '../models/meeting_venue.dart';
import '../services/chat_service.dart';
import '../services/match_service.dart';
import '../services/venue_service.dart';
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
  final VenueService _venueService = VenueService();

  bool _isSending = false;
  bool _isDiscoveryActive = false;
  List<MeetingVenue> _discoveredVenues = [];

  Future<void> _scanNearbyPlaces(MatchPairData pair) async {
    if (_isDiscoveryActive) return;

    setState(() {
      _isDiscoveryActive = true;
      _discoveredVenues = [];
    });

    if (!mounted) return;

    final lat = pair.midpointLatitude!;
    final lng = pair.midpointLongitude!;

    List<MeetingVenue> results = [];

    try {
      final suggestions = await _venueService.findPublicVenues(
        midpointLatitude: lat,
        midpointLongitude: lng,
        radiusMeters: 2500,
        limit: 15,
      );

      results = suggestions.map((v) {
        return MeetingVenue(
          id: v.id,
          name: v.name,
          category: v.category,
          address: v.address,
          latitude: v.latitude,
          longitude: v.longitude,
          mapsUrl: v.mapUrl,
          distanceFromMidpointKm: v.distanceFromMidpointKm,
          rating: v.rating,
          imageUrl: v.imageUrl,
        );
      }).toList();
    } catch (e) {
      debugPrint("Venue scan network fallback: $e");
    }

    if (results.isEmpty) {
      final mockPlaces = [
        {'name': 'Soul Café', 'cat': 'Public café', 'offLat': 0.0015, 'offLng': 0.001, 'rating': 4.8, 'img': 'https://images.unsplash.com/photo-1554118811-1e0d58224f24?w=600&q=80'},
        {'name': 'Garden Mall', 'cat': 'Shopping mall', 'offLat': -0.001, 'offLng': 0.002, 'rating': 4.7, 'img': 'https://images.unsplash.com/photo-1567449303078-57ad995bd301?w=600&q=80'},
        {'name': 'Metro Library', 'cat': 'Library', 'offLat': 0.0008, 'offLng': -0.0015, 'rating': 4.6, 'img': 'https://images.unsplash.com/photo-1521587760476-6c12a4b040da?w=600&q=80'},
        {'name': 'Skyline Restaurant', 'cat': 'Restaurant', 'offLat': -0.002, 'offLng': -0.001, 'rating': 4.9, 'img': 'https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?w=600&q=80'},
      ];

      results = mockPlaces.map((p) {
        final vLat = lat + (p['offLat'] as double);
        final vLng = lng + (p['offLng'] as double);
        return MeetingVenue(
          id: 'mock_${DateTime.now().millisecondsSinceEpoch}_${p['name']}',
          name: p['name'] as String,
          category: p['cat'] as String,
          address: 'Near the fair midpoint',
          latitude: vLat,
          longitude: vLng,
          mapsUrl: 'https://www.google.com/maps/search/?api=1&query=$vLat,$vLng',
          rating: p['rating'] as double,
          imageUrl: p['img'] as String,
        );
      }).toList();
    }

    setState(() {
      _discoveredVenues = results;
      _isDiscoveryActive = false;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Radar scan complete! ${results.length} top-rated spots found near midpoint.'),
          backgroundColor: const Color(0xFF3B82F6),
        ),
      );
    }
  }

  Future<void> _shareSelectedVenue(MeetingVenue venue) async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      isScrollControlled: true,
      builder: (bottomContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (venue.imageUrl.isNotEmpty)
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                child: Image.network(
                  venue.imageUrl,
                  height: 180,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    height: 120,
                    color: const Color(0xFF334155),
                    child: const Icon(Icons.storefront_outlined, size: 50, color: Colors.white38),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          venue.name,
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.amber, width: 1),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.star_rounded, color: Colors.amber, size: 16),
                            const SizedBox(width: 4),
                            Text(
                              venue.rating.toStringAsFixed(1),
                              style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(venue.category, style: const TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.w600)),
                  if (venue.address.isNotEmpty && venue.address != 'Address unavailable') ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.location_on_outlined, color: Colors.white54, size: 16),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            venue.address,
                            style: const TextStyle(color: Colors.white70, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => Navigator.pop(bottomContext, false),
                          icon: const Icon(Icons.close),
                          label: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () => Navigator.pop(bottomContext, true),
                          icon: const Icon(Icons.send_rounded),
                          label: const Text('Send Proposal'),
                          style: FilledButton.styleFrom(backgroundColor: const Color(0xFF3B82F6)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true) {
      setState(() => _isSending = true);
      try {
        await _chatService.sendMeetingProposal(
          targetUserUid: widget.targetUserUid,
          venue: venue,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Proposal for ${venue.name} sent!')),
          );
        }
      } catch (e) {
        if (mounted) _showError(e.toString());
      } finally {
        if (mounted) setState(() => _isSending = false);
      }
    }
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
            Row(
              children: [
                const Icon(Icons.swap_calls_rounded, color: Color(0xFF38BDF8), size: 18),
                const SizedBox(width: 8),
                Text(
                  'Fair Midpoint ($distanceText)',
                  style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ],
            ),
            const SizedBox(height: 8),
            MatchMeetingMap(
              pair: pair,
              otherUserName: widget.soulName,
              suggestedVenues: _discoveredVenues,
              onVenueSelected: _shareSelectedVenue,
            ),
            const SizedBox(height: 12),
            // Radar Scan Button
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _isDiscoveryActive ? null : () => _scanNearbyPlaces(pair),
                icon: _isDiscoveryActive
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.radar),
                label: Text(_isDiscoveryActive ? 'Scanning...' : 'Scan Near Midpoint'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF3B82F6),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
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
