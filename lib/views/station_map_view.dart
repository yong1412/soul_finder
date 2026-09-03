import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/event_hotspot.dart';
import '../models/radar/radar_models.dart';
import '../services/event_hotspot_service.dart';
import '../services/station_service.dart';
import '../widgets/marquee_text.dart';

/// Transit Stations & Event Hotspots Map View
class StationMapView extends StatefulWidget {
  const StationMapView({
    super.key,
    this.initialTarget,
    this.targetEvent,
  });

  final LatLng? initialTarget;
  final EventHotspot? targetEvent;

  @override
  State<StationMapView> createState() => _StationMapViewState();
}

class _StationMapViewState extends State<StationMapView> {
  List<Station> _transitStations = [];
  List<EventHotspot> _eventHotspots = [];
  Set<Marker> _markers = {};
  bool _isLoading = true;
  String _selectedFilter = 'ALL'; // 'ALL', 'LRT', 'MRT', 'EVENTS'

  // Default initial camera position (Kuala Lumpur Center or passed target)
  late CameraPosition _initialCameraPosition;

  @override
  void initState() {
    super.initState();

    // 🎯 If opened from an Event, automatically filter to ONLY show Event Hotspots
    if (widget.targetEvent != null || widget.initialTarget != null) {
      _selectedFilter = 'EVENTS';
    }

    final target = widget.initialTarget ??
        (widget.targetEvent != null
            ? LatLng(widget.targetEvent!.latitude, widget.targetEvent!.longitude)
            : const LatLng(3.1498, 101.6963));

    _initialCameraPosition = CameraPosition(
      target: target,
      zoom: widget.initialTarget != null || widget.targetEvent != null ? 15.5 : 12.5,
    );

    _loadData();
  }

  /// Load transit stations from CSV and event hotspots from EventHotspotService
  Future<void> _loadData() async {
    final stations = await StationService.loadStationsFromCsv();
    final events = EventHotspotService().events;

    if (mounted) {
      setState(() {
        _transitStations = stations;
        _eventHotspots = events;
        _updateMarkers();
        _isLoading = false;
      });

      // Auto-popup details if opened for a specific event
      if (widget.targetEvent != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showEventDetails(widget.targetEvent!);
        });
      }
    }
  }

  /// Update map markers based on selected filter
  void _updateMarkers() {
    final Set<Marker> markers = {};

    // 1. Add Transit Stations
    if (_selectedFilter == 'ALL' || _selectedFilter == 'LRT' || _selectedFilter == 'MRT') {
      final filteredStations = _transitStations.where((station) {
        if (_selectedFilter == 'LRT') return station.type == StationType.lrt;
        if (_selectedFilter == 'MRT') return station.type == StationType.mrt;
        return true;
      }).toList();

      markers.addAll(
        StationService.convertToMarkers(
          filteredStations,
          onTap: (station) {
            _showStationDetails(station);
          },
        ),
      );
    }

    // 2. Add Event Hotspots (e.g. Serimas Condo • Pearl Tower)
    if (_selectedFilter == 'ALL' || _selectedFilter == 'EVENTS') {
      for (final event in _eventHotspots) {
        markers.add(
          Marker(
            markerId: MarkerId('event_${event.id}'),
            position: LatLng(event.latitude, event.longitude),
            infoWindow: InfoWindow(
              title: event.eventTitle,
              snippet: event.name,
            ),
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
            onTap: () {
              _showEventDetails(event);
            },
          ),
        );
      }
    }

    setState(() {
      _markers = markers;
    });
  }

  /// Show details modal for Event Hotspots with high-contrast, clean font colors
  void _showEventDetails(EventHotspot event) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E293B), // Dark slate background
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
              // Badge & Title
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.local_fire_department,
                            color: Color(0xFFF59E0B), size: 16),
                        SizedBox(width: 4),
                        Text(
                          'EVENT HOTSPOT',
                          style: TextStyle(
                            color: Color(0xFFF59E0B),
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

              // Event Title (Marquee Auto-scrolling if long)
              MarqueeText(
                text: event.eventTitle,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFF8FAFC),
                ),
              ),
              const SizedBox(height: 6),

              // Place / Venue Name (e.g. Serimas Condo • Pearl Tower)
              Row(
                children: [
                  const Icon(Icons.place, color: Color(0xFF38BDF8), size: 16),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      event.name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFCBD5E1), // Slate light font
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Stats Row
              Row(
                children: [
                  _buildStatBadge(
                    icon: Icons.thumb_up_alt_outlined,
                    label: 'Interested',
                    value: '${event.interestedCount}',
                    color: const Color(0xFF38BDF8),
                  ),
                  const SizedBox(width: 12),
                  _buildStatBadge(
                    icon: Icons.people_alt_outlined,
                    label: 'Active',
                    value: '${event.activeAttendees}',
                    color: const Color(0xFF10B981),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Address / Description
              Text(
                'Location: ${event.description}',
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF94A3B8), // Muted readable font
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  /// Show details modal for Transit Stations with high-contrast, clean font colors
  void _showStationDetails(Station station) {
    final isLrt = station.type == StationType.lrt;
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E293B), // Dark slate background
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
                  CircleAvatar(
                    backgroundColor: isLrt ? const Color(0xFFEF4444) : const Color(0xFF3B82F6),
                    radius: 12,
                    child: Icon(
                      isLrt ? Icons.train : Icons.subway,
                      size: 14,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      station.name,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFF8FAFC), // High-contrast white font
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Type: ${isLrt ? "LRT Station" : "MRT Station"}',
                style: const TextStyle(fontSize: 15, color: Color(0xFFCBD5E1)),
              ),
              const SizedBox(height: 8),
              Text(
                'Coordinates: ${station.latitude.toStringAsFixed(4)}, ${station.longitude.toStringAsFixed(4)}',
                style: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatBadge({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            '$label: $value',
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        title: const Text(
          'Locations & Events Map',
          style: TextStyle(color: Color(0xFFF8FAFC), fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Color(0xFFF8FAFC)),
        centerTitle: true,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Color(0xFF38BDF8)),
                  SizedBox(height: 16),
                  Text(
                    'Loading map locations & events...',
                    style: TextStyle(color: Color(0xFF94A3B8)),
                  ),
                ],
              ),
            )
          : Stack(
              children: [
                // 1. Google Map
                GoogleMap(
                  initialCameraPosition: _initialCameraPosition,
                  markers: _markers,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: true,
                ),

                // 2. Top Filter Chips Area
                Positioned(
                  top: 16,
                  left: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A).withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: Colors.white10),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x66000000),
                          blurRadius: 8,
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildFilterChip('ALL', 'All (${_transitStations.length + _eventHotspots.length})'),
                          const SizedBox(width: 6),
                          _buildFilterChip('EVENTS', 'Events (${_eventHotspots.length})'),
                          const SizedBox(width: 6),
                          _buildFilterChip(
                            'LRT',
                            'LRT (${_transitStations.where((s) => s.type == StationType.lrt).length})',
                          ),
                          const SizedBox(width: 6),
                          _buildFilterChip(
                            'MRT',
                            'MRT (${_transitStations.where((s) => s.type == StationType.mrt).length})',
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // 3. Bottom Legend Box
                Positioned(
                  bottom: 24,
                  left: 16,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A).withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white12),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x33000000),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.location_on, color: Color(0xFFF59E0B), size: 16),
                            SizedBox(width: 6),
                            Text('Event Hotspot', style: TextStyle(fontSize: 12, color: Color(0xFFF8FAFC))),
                          ],
                        ),
                        SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.location_on, color: Color(0xFFEF4444), size: 16),
                            SizedBox(width: 6),
                            Text('LRT Station', style: TextStyle(fontSize: 12, color: Color(0xFFF8FAFC))),
                          ],
                        ),
                        SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.location_on, color: Color(0xFF3B82F6), size: 16),
                            SizedBox(width: 6),
                            Text('MRT Station', style: TextStyle(fontSize: 12, color: Color(0xFFF8FAFC))),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildFilterChip(String filterKey, String label) {
    final isSelected = _selectedFilter == filterKey;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _selectedFilter = filterKey;
            _updateMarkers();
          });
        }
      },
      selectedColor: const Color(0xFF38BDF8),
      backgroundColor: const Color(0xFF1E293B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      labelStyle: TextStyle(
        color: isSelected ? Colors.black : const Color(0xFFCBD5E1),
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        fontSize: 12,
      ),
    );
  }
}
