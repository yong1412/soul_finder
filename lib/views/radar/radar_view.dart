import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../../controllers/radar/radar_controller.dart';
import '../../controllers/auth_controller.dart';
import '../../models/radar/radar_models.dart';
import '../../services/match_service.dart';
import '../../services/radar/geocoding_service.dart';
import '../../widgets/marquee_text.dart';
import '../chat_conversation_view.dart';
import '../public_user_profile_view.dart';
import 'radar_painter.dart';

class RadarView extends StatefulWidget {
  const RadarView({
    super.key,
    required this.authController,
    this.isRadarTabActive = true,
  });

  final AuthController authController;
  final bool isRadarTabActive;

  @override
  State<RadarView> createState() => _RadarViewState();
}

class _RadarViewState extends State<RadarView> with SingleTickerProviderStateMixin {
  late final RadarController _controller;
  late AnimationController _animationController;
  bool _isRadiusExpanded = false;

  final MatchService _matchService = MatchService();
  StreamSubscription<List<MatchCandidate>>? _candidatesSubscription;
  StreamSubscription<Set<String>>? _likedUserIdsSubscription;
  Timer? _detectionDelayTimer;

  List<MatchCandidate> _latestCandidates = [];
  Set<String> _likedUserIds = {};
  final Set<String> _skippedUserIds = {};
  bool _isShowingDialog = false;

  @override
  void initState() {
    super.initState();
    // Discovery Radius is stored in km in the profile, convert to meters for radar (50m - 200m)
    final user = widget.authController.currentUser;
    final initialRadius = user != null 
        ? (user.discoveryRadius * 1000).clamp(50.0, 200.0) 
        : 200.0;
    
    _controller = RadarController(initialRadius: initialRadius);
    _controller.addListener(_onRadarControllerChanged);
    _controller.startLocationTracking();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    // Listen to profile changes to update radar radius dynamically
    widget.authController.addListener(_onAuthChanged);

    // Subscribe to match candidates & liked users for high match popup on radar
    _likedUserIdsSubscription = _matchService.watchLikedUserIds().listen((likedIds) {
      if (!mounted) return;
      _likedUserIds = likedIds;
      _checkAndShowHighMatchCandidate();
    });

    _subscribeToCandidates();
  }

  void _subscribeToCandidates() {
    _candidatesSubscription?.cancel();
    final mode = _controller.scanMode.isEmpty ? 'friends' : _controller.scanMode.first;
    _candidatesSubscription = _matchService.watchCandidates(scanMode: mode).listen((candidates) {
      if (!mounted) return;
      _latestCandidates = candidates;
      _checkAndShowHighMatchCandidate();
    });
  }

  void _onRadarControllerChanged() {
    if (!mounted) return;
    _checkAndShowHighMatchCandidate();
  }

  @override
  void didUpdateWidget(RadarView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isRadarTabActive && !oldWidget.isRadarTabActive) {
      _checkAndShowHighMatchCandidate();
    }
  }

  void _onAuthChanged() {
    final user = widget.authController.currentUser;
    if (user != null) {
      final newRadiusMeters = user.discoveryRadius * 1000;
      if (_controller.radarRadius != newRadiusMeters) {
        _controller.setRadarRadius(newRadiusMeters);
      }
    }
  }

  @override
  void dispose() {
    _detectionDelayTimer?.cancel();
    _controller.removeListener(_onRadarControllerChanged);
    _candidatesSubscription?.cancel();
    _likedUserIdsSubscription?.cancel();
    widget.authController.removeListener(_onAuthChanged);
    _animationController.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _showStationDetails(VisitRecord record) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final timeStr = "${record.timestamp.hour.toString().padLeft(2, '0')}:${record.timestamp.minute.toString().padLeft(2, '0')}";
        final dateStr = "${record.timestamp.day}/${record.timestamp.month}";
        
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      record.station.name,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      record.station.type.name.toUpperCase(),
                      style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(color: Colors.white10),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(Icons.access_time, color: Colors.white54, size: 18),
                  const SizedBox(width: 12),
                  Text(
                    "Visited at $timeStr on $dateStr",
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              FutureBuilder<GeocodingResult?>(
                future: GeocodingService().reverseGeocode(
                  record.station.latitude,
                  record.station.longitude,
                ),
                builder: (context, snapshot) {
                  final addressText = snapshot.data?.shortAddress ??
                      "${record.station.latitude.toStringAsFixed(4)}, ${record.station.longitude.toStringAsFixed(4)}";

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.location_on_outlined, color: Colors.white54, size: 18),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              addressText,
                              style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              "GPS: ${record.station.latitude.toStringAsFixed(4)}, ${record.station.longitude.toStringAsFixed(4)}",
                              style: const TextStyle(color: Colors.white38, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text("Close"),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  void _showHistoryModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return ListenableBuilder(
          listenable: _controller,
          builder: (context, child) {
            final topStay = _controller.topStayStations;

            return DefaultTabController(
              length: 2,
              child: Container(
                height: MediaQuery.of(context).size.height * 0.65,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                ),
                child: Column(
                  children: [
                    const SizedBox(height: 12),
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white12,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TabBar(
                      indicatorColor: Theme.of(context).colorScheme.primary,
                      labelColor: Colors.white,
                      unselectedLabelColor: Colors.white38,
                      tabs: const [
                        Tab(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.leaderboard, size: 16),
                              SizedBox(width: 6),
                              Text("Top Stay Stations"),
                            ],
                          ),
                        ),
                        Tab(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.history, size: 16),
                              SizedBox(width: 6),
                              Text("Visit Logs"),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 1, color: Colors.white10),
                    Expanded(
                      child: TabBarView(
                        children: [
                          // Tab 1: Top Stay Stations Rank List
                          topStay.isEmpty
                              ? const Center(
                                  child: Text(
                                    "No station stay data recorded yet.",
                                    style: TextStyle(color: Colors.white38),
                                  ),
                                )
                              : ListView.builder(
                                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                  itemCount: topStay.length,
                                  itemBuilder: (context, index) {
                                    final record = topStay[index];
                                    final rank = index + 1;
                                    final isTop3 = rank <= 3;
                                    final rankColor = rank == 1
                                        ? const Color(0xFFFFD700)
                                        : rank == 2
                                            ? const Color(0xFFC0C0C0)
                                            : rank == 3
                                                ? const Color(0xFFCD7F32)
                                                : Colors.white38;

                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 10),
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: isTop3
                                            ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.08)
                                            : Colors.white.withValues(alpha: 0.03),
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: isTop3
                                              ? rankColor.withValues(alpha: 0.4)
                                              : Colors.white.withValues(alpha: 0.05),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          // Rank badge
                                          Container(
                                            width: 32,
                                            height: 32,
                                            alignment: Alignment.center,
                                            decoration: BoxDecoration(
                                              color: isTop3 ? rankColor.withValues(alpha: 0.2) : Colors.white10,
                                              shape: BoxShape.circle,
                                            ),
                                            child: Text(
                                              "#$rank",
                                              style: TextStyle(
                                                color: isTop3 ? rankColor : Colors.white54,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          // Station details
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  record.station.type == StationType.event
                                                      ? (record.station.eventTitle ?? record.station.name)
                                                      : record.station.name,
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 14,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Row(
                                                  children: [
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                      decoration: BoxDecoration(
                                                        color: record.station.type == StationType.event
                                                            ? const Color(0xFFF59E0B).withValues(alpha: 0.2)
                                                            : Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                                                        borderRadius: BorderRadius.circular(6),
                                                      ),
                                                      child: Text(
                                                        record.station.type == StationType.event
                                                            ? 'EVENT'
                                                            : record.station.type.name.toUpperCase(),
                                                        style: TextStyle(
                                                          color: record.station.type == StationType.event
                                                              ? const Color(0xFFF59E0B)
                                                              : Theme.of(context).colorScheme.primary,
                                                          fontSize: 9,
                                                          fontWeight: FontWeight.bold,
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Text(
                                                      "${record.visitCount} visits",
                                                      style: const TextStyle(color: Colors.white38, fontSize: 11),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                          // Duration highlight
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.end,
                                            children: [
                                              Text(
                                                record.formattedDuration,
                                                style: TextStyle(
                                                  color: Theme.of(context).colorScheme.secondary,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 15,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              const Text(
                                                "Stay Duration",
                                                style: TextStyle(color: Colors.white38, fontSize: 9),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),

                          // Tab 2: Visit Logs
                          _controller.recentStations.isEmpty
                              ? const Center(
                                  child: Text(
                                    "No visit logs recorded yet.",
                                    style: TextStyle(color: Colors.white38),
                                  ),
                                )
                              : ListView.builder(
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  itemCount: _controller.recentStations.length,
                                  itemBuilder: (context, index) {
                                    final record = _controller.recentStations[index];
                                    final timeStr = "${record.timestamp.hour.toString().padLeft(2, '0')}:${record.timestamp.minute.toString().padLeft(2, '0')}";
                                    final isEvent = record.station.type == StationType.event;
                                    final stationTitle = isEvent
                                        ? (record.station.eventTitle ?? record.station.name)
                                        : record.station.name;

                                    return ListTile(
                                      leading: CircleAvatar(
                                        backgroundColor: isEvent
                                            ? const Color(0xFFF59E0B).withValues(alpha: 0.15)
                                            : Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                                        child: Icon(
                                          isEvent ? Icons.local_fire_department : Icons.history,
                                          color: isEvent ? const Color(0xFFF59E0B) : Theme.of(context).colorScheme.primary,
                                          size: 20,
                                        ),
                                      ),
                                      title: Text(stationTitle, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
                                      subtitle: Text("Visited at $timeStr", style: const TextStyle(color: Colors.white38, fontSize: 12)),
                                      trailing: const Icon(Icons.arrow_forward_ios, size: 12, color: Colors.white24),
                                      onTap: () {
                                        Navigator.pop(context);
                                        _showStationDetails(record);
                                      },
                                    );
                                  },
                                ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildRadiusPillButton(ColorScheme theme) {
    final currentRadiusInt = _controller.radarRadius.round().clamp(50, 200);

    return InkWell(
      onTap: () {
        setState(() {
          _isRadiusExpanded = !_isRadiusExpanded;
        });
      },
      borderRadius: BorderRadius.circular(25),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: _isRadiusExpanded 
              ? theme.primary.withValues(alpha: 0.25)
              : theme.surface,
          borderRadius: BorderRadius.circular(25),
          border: Border.all(
            color: _isRadiusExpanded 
                ? theme.primary 
                : Colors.white.withValues(alpha: 0.12),
          ),
          boxShadow: [
            if (_isRadiusExpanded)
              BoxShadow(
                color: theme.primary.withValues(alpha: 0.2),
                blurRadius: 10,
                spreadRadius: 1,
              )
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.tune,
              size: 18,
              color: theme.primary,
            ),
            const SizedBox(width: 6),
            Text(
              "${currentRadiusInt}m",
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              _isRadiusExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
              size: 18,
              color: Colors.white54,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopControlRow(ColorScheme theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Mode Switch Button (Find Friends / Couple / Mix)
              Flexible(child: _buildModeToggleButton(theme)),
              const SizedBox(width: 10),
              // Radius Expandable Pill Button
              _buildRadiusPillButton(theme),
            ],
          ),

          // Animated Expanded Slider Card
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Container(
              margin: const EdgeInsets.only(top: 10),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              decoration: BoxDecoration(
                color: theme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: theme.primary.withValues(alpha: 0.4)),
                boxShadow: [
                  BoxShadow(
                    color: theme.primary.withValues(alpha: 0.12),
                    blurRadius: 10,
                    spreadRadius: 1,
                  )
                ],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Discovery Radius",
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        "${_controller.radarRadius.round()}m",
                        style: TextStyle(
                          color: theme.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 4,
                      activeTrackColor: theme.primary,
                      inactiveTrackColor: Colors.white10,
                      thumbColor: theme.primary,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                      overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
                    ),
                    child: Slider(
                      value: _controller.radarRadius.clamp(50.0, 200.0),
                      min: 50.0,
                      max: 200.0,
                      divisions: 15,
                      label: "${_controller.radarRadius.round()}m",
                      onChanged: (double val) {
                        _controller.setRadarRadius(val);
                        final user = widget.authController.currentUser;
                        if (user != null) {
                          widget.authController.updateProfile(
                            user.copyWith(discoveryRadius: val / 1000.0),
                          );
                        }
                      },
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("50m", style: TextStyle(color: Colors.white38, fontSize: 10)),
                        Text("200m", style: TextStyle(color: Colors.white38, fontSize: 10)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            crossFadeState: _isRadiusExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 250),
          ),
        ],
      ),
    );
  }

  Widget _buildModeToggleButton(ColorScheme theme) {
    final mode = _controller.scanMode.isEmpty ? 'friends' : _controller.scanMode.first;
    final isCouple = mode == 'couple';

    final icon = isCouple ? Icons.favorite : Icons.people_alt;
    final label = isCouple ? "Find Couple" : "Find Friends";
    final activeColor = isCouple ? theme.secondary : theme.primary;
    final gradient = isCouple
        ? const LinearGradient(
            colors: [Color(0xFFF43F5E), Color(0xFFBE123C)],
          )
        : const LinearGradient(
            colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
          );

    return InkWell(
      onTap: () {
        final nextMode = isCouple ? 'friends' : 'couple';
        _controller.setScanMode({nextMode});
        _subscribeToCandidates();
      },
      borderRadius: BorderRadius.circular(25),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(25),
          boxShadow: [
            BoxShadow(
              color: activeColor.withValues(alpha: 0.35),
              blurRadius: 12,
              spreadRadius: 1,
              offset: const Offset(0, 3),
            )
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.sync_alt, color: Colors.white70, size: 16),
          ],
        ),
      ),
    );
  }

  Color _getModeColor(String mode, ColorScheme theme) {
    if (mode == 'couple') return const Color(0xFFFF2D55); // Vibrant Crimson Red
    return const Color(0xFF3B82F6); // Vibrant Electric Blue
  }

  IconData _getModeIcon(String mode) {
    if (mode == 'couple') return Icons.favorite;
    return Icons.person;
  }

  String _getModeSoulsLabel(String mode) {
    if (mode == 'couple') return 'matches';
    return 'friends';
  }

  Widget _buildCompactPulseButton(Color modeColor) {
    final isScanning = _controller.isScanning;
    final isDisabled = isScanning || _controller.currentPosition == null;

    return InkWell(
      onTap: isDisabled
          ? null
          : () => _controller.performRadarScan(_controller.currentPosition!),
      borderRadius: BorderRadius.circular(15),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDisabled
              ? Colors.white10
              : modeColor.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: isDisabled
                ? Colors.white12
                : modeColor.withValues(alpha: 0.5),
          ),
          boxShadow: [
            if (!isDisabled)
              BoxShadow(
                color: modeColor.withValues(alpha: 0.18),
                blurRadius: 10,
                spreadRadius: 1,
              )
          ],
        ),
        child: isScanning
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Icon(
                Icons.gps_fixed,
                size: 20,
                color: modeColor,
              ),
      ),
    );
  }

  Widget _buildRecentHotspotsButton(ColorScheme theme) {
    final hasHotspots = _controller.recentStations.isNotEmpty;

    return InkWell(
      onTap: () {
        if (!hasHotspots) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("No recent hotspots visited yet! Keep moving to discover."),
              duration: Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
            ),
          );
        } else {
          _showHistoryModal();
        }
      },
      borderRadius: BorderRadius.circular(15),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
        decoration: BoxDecoration(
          color: !hasHotspots 
              ? Colors.white.withValues(alpha: 0.05) 
              : theme.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: !hasHotspots ? Colors.white10 : theme.primary.withValues(alpha: 0.3)
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.history_toggle_off, 
              size: 18, 
              color: !hasHotspots ? Colors.white24 : theme.primary
            ),
            const SizedBox(width: 8),
            const Flexible(
              child: Text(
                "VIEW RECENT HOTSPOTS",
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11, 
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                  color: Colors.white,
                ),
              ),
            ),
            if (hasHotspots) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(color: theme.primary, shape: BoxShape.circle),
                child: Text(
                  "${_controller.recentStations.length}", 
                  style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
                ),
              )
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildRadarLoadingScreen(ColorScheme theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: theme.primary, strokeWidth: 3),
          const SizedBox(height: 20),
          const Text(
            'Initializing Radar & Hotspots...',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Syncing user location & loading hotspot history...',
            style: TextStyle(color: Colors.white38, fontSize: 12),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).colorScheme;

    return ListenableBuilder(
      listenable: _controller,
      builder: (context, child) {
        // 🎯 Show Radar Loading Screen until location & Firestore history are 100% loaded!
        if (!_controller.isLocationLoaded || !_controller.isHistoryLoaded) {
          return _buildRadarLoadingScreen(theme);
        }

        final mode = _controller.scanMode.isEmpty ? 'friends' : _controller.scanMode.first;
        final modeColor = _getModeColor(mode, theme);

        return Column(
          children: [
            // Top Selection Area
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              child: Column(
                children: [
                  // Top Control Row (Mode Button + Radius Expandable Button side by side)
                  _buildTopControlRow(theme),
                  
                  // 热点状态条
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 500),
                    height: _controller.currentStationHotspot != null ? 50 : 0,
                    margin: const EdgeInsets.only(top: 10, left: 20, right: 20),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      gradient: _controller.currentStationHotspot?.type == StationType.event
                          ? const LinearGradient(colors: [Color(0xFF0284C7), Color(0xFF0F766E)])
                          : LinearGradient(colors: [theme.primary, theme.secondary]),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(color: theme.secondary.withValues(alpha: 0.3), blurRadius: 8, spreadRadius: 1)
                      ],
                    ),
                    child: _controller.currentStationHotspot == null 
                      ? const SizedBox.shrink()
                      : Row(
                        children: [
                          Icon(
                            _controller.currentStationHotspot?.type == StationType.event
                                ? Icons.local_fire_department
                                : Icons.stars,
                            color: Colors.white,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: MarqueeText(
                              text: _controller.currentStationHotspot?.type == StationType.event
                                  ? "ACTIVE EVENT: ${_controller.currentStationHotspot?.eventTitle ?? _controller.currentStationHotspot?.name}"
                                  : "ACTIVE HOTSPOT: ${_controller.currentStationHotspot?.name}",
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white),
                            ),
                          ),
                          Text(
                            _controller.currentStationHotspot?.type == StationType.event
                                ? "EVENT ACTIVE"
                                : "BONUS LUCK",
                            style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                  ),

                  // 距离最近站点/Event显示
                  Padding(
                    padding: const EdgeInsets.only(top: 12.0),
                    child: Builder(
                      builder: (context) {
                        if (_controller.isScanning) {
                          return Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 12,
                                height: 12,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: theme.primary,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                "Scanning for nearby locations...",
                                style: TextStyle(fontSize: 12, color: Colors.white38),
                              ),
                            ],
                          );
                        }

                        if (_controller.nearestStation != null && _controller.minDistanceToStation != null) {
                          final station = _controller.nearestStation!;
                          final isEvent = station.type == StationType.event;

                          if (isEvent) {
                            // Dedicated Event Nearest UI: ONLY Event Title, NO place name!
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0F172A).withValues(alpha: 0.8),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: const Color(0xFF38BDF8).withValues(alpha: 0.6),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.local_fire_department,
                                    size: 16,
                                    color: Color(0xFF38BDF8),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF38BDF8).withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text(
                                      "EVENT",
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF38BDF8),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: MarqueeText(
                                      text: station.eventTitle ?? station.name, // ONLY EVENT TITLE
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    "(${(_controller.minDistanceToStation! * 1000).toInt()}m)",
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF38BDF8),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }

                          // Regular Transit Station Nearest UI
                          return Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.train,
                                size: 14, 
                                color: theme.primary.withValues(alpha: 0.7)
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  "Nearest: ${station.name} ",
                                  style: const TextStyle(fontSize: 12, color: Colors.white70),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(
                                "(${(_controller.minDistanceToStation! * 1000).toInt()}m)",
                                style: TextStyle(
                                  fontSize: 12, 
                                  color: _controller.minDistanceToStation! < 0.5 ? theme.secondary : theme.primary,
                                  fontWeight: FontWeight.bold
                                ),
                              ),
                            ],
                          );
                        }

                        return const Text(
                          "No locations detected in range",
                          style: TextStyle(fontSize: 12, color: Colors.white24),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),

            // Radar section
            Expanded(
              child: Stack(
                children: [
                  Align(
                    alignment: const Alignment(0, -0.75),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: 320,
                      height: 320,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: modeColor.withValues(alpha: 0.4), width: 1.5),
                        color: modeColor.withValues(alpha: 0.05),
                        boxShadow: [
                          BoxShadow(
                            color: modeColor.withValues(alpha: 0.2),
                            blurRadius: 20,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Animated Radar
                          AnimatedBuilder(
                            animation: _animationController,
                            builder: (context, child) {
                              return CustomPaint(
                                size: const Size(300, 300),
                                painter: RadarPainter(
                                  progress: _animationController.value,
                                  color: modeColor,
                                  dots: _controller.dots,
                                ),
                              );
                            },
                          ),
                          
                          // Center Icon
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            height: 50,
                            width: 50,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: theme.surface,
                              border: Border.all(color: Colors.white24, width: 2),
                              boxShadow: [
                                BoxShadow(
                                  color: modeColor.withValues(alpha: 0.4),
                                  blurRadius: 15,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: _controller.isScanning 
                              ? const Padding(
                                  padding: EdgeInsets.all(12.0),
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : Icon(
                                  _getModeIcon(mode),
                                  size: 24,
                                  color: Colors.white,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Bottom Stats
                  Positioned(
                    bottom: 20,
                    left: 0,
                    right: 0,
                    child: Column(
                      children: [
                        if (_controller.currentPosition != null)
                          FutureBuilder<GeocodingResult?>(
                            future: GeocodingService().reverseGeocode(
                              _controller.currentPosition!.latitude,
                              _controller.currentPosition!.longitude,
                            ),
                            builder: (context, snapshot) {
                              final locText = snapshot.data?.shortAddress ??
                                  "${_controller.currentPosition!.latitude.toStringAsFixed(4)}, ${_controller.currentPosition!.longitude.toStringAsFixed(4)}";
                              return Text(
                                "My Location: $locText",
                                style: const TextStyle(fontSize: 11, color: Colors.white54),
                                textAlign: TextAlign.center,
                              );
                            },
                          ),
                        const SizedBox(height: 10),
                        Builder(
                          builder: (context) {
                            if (_controller.soulsFound > 0) {
                              return Text(
                                "Detected ${_controller.soulsFound} potential ${_getModeSoulsLabel(mode)}",
                                style: TextStyle(
                                  fontSize: 14,
                                  color: modeColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              );
                            }
                            
                            if (_controller.minDistanceToStation != null && _controller.minDistanceToStation! > 0.2) {
                              return const Column(
                                children: [
                                  Text(
                                    "TOO FAR FROM STATION",
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.orangeAccent,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    "Get within 200m to detect nearby souls",
                                    style: TextStyle(fontSize: 11, color: Colors.white38),
                                  ),
                                ],
                              );
                            }

                            return const SizedBox.shrink();
                          },
                        ),

                        // 最近站点与定位脉冲按钮区域（并排）
                        const SizedBox(height: 18),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Row(
                            children: [
                              _buildCompactPulseButton(modeColor),
                              const SizedBox(width: 10),
                              Expanded(child: _buildRecentHotspotsButton(theme)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      }
    );
  }

  void _checkAndShowHighMatchCandidate() {
    if (!mounted) return;
    if (!widget.isRadarTabActive) return;
    if (_isShowingDialog) return;

    // Requirement 1: Must be inside an active hotspot
    if (_controller.currentStationHotspot == null) {
      _detectionDelayTimer?.cancel();
      return;
    }

    // Requirement 2: Must wait until radar page finishes location loading and scanning
    if (!_controller.isLocationLoaded || _controller.isScanning) {
      _detectionDelayTimer?.cancel();
      return;
    }

    // Requirement 3: Add a 2-second delay for smooth performance and UX
    _detectionDelayTimer?.cancel();
    _detectionDelayTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted) return;
      if (!widget.isRadarTabActive) return;
      if (_isShowingDialog) return;
      if (ModalRoute.of(context)?.isCurrent != true) return;
      if (_controller.currentStationHotspot == null) return;
      if (!_controller.isLocationLoaded || _controller.isScanning) return;

      final currentMode = _controller.scanMode.isEmpty ? 'friends' : _controller.scanMode.first;

      final highMatchCandidates = _latestCandidates.where((candidate) {
        final uid = candidate.profile.uid;
        final isHighMatch = candidate.compatibilityScore >= 80;
        final notLiked = !_likedUserIds.contains(uid);
        final notSkipped = !_skippedUserIds.contains(uid);

        // Filter candidates based on current Radar Mode (Find Friends vs Find Couple)
        final lookingForLower = candidate.profile.lookingFor.toLowerCase().trim();
        final matchesMode = currentMode == 'couple'
            ? (lookingForLower.contains('couple') ||
                lookingForLower.contains('dating') ||
                lookingForLower.contains('relat') ||
                lookingForLower == 'both' ||
                lookingForLower.isEmpty)
            : (lookingForLower.contains('friend') ||
                lookingForLower.contains('network') ||
                lookingForLower == 'both' ||
                lookingForLower.isEmpty);

        return isHighMatch && notLiked && notSkipped && matchesMode;
      }).toList();

      if (highMatchCandidates.isEmpty) return;

      final candidate = highMatchCandidates.first;
      _isShowingDialog = true;

      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return HighMatchDialog(
            candidate: candidate,
            onInterested: () async {
              Navigator.pop(dialogContext);
              _skippedUserIds.add(candidate.profile.uid);

              try {
                final becameMatched = await _matchService.likeUser(candidate.profile.uid);

                if (!mounted) return;

                if (becameMatched) {
                  _showMatchDialog(candidate);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Liked ${candidate.profile.name}! Waiting for mutual Like.'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }
            },
            onSkip: () {
              Navigator.pop(dialogContext);
              _skippedUserIds.add(candidate.profile.uid);
            },
            onViewProfile: () {
              Navigator.pop(dialogContext);
              _skippedUserIds.add(candidate.profile.uid);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PublicUserProfileView(candidate: candidate),
                ),
              );
            },
          );
        },
      ).then((_) {
        _isShowingDialog = false;
        if (mounted) {
          _checkAndShowHighMatchCandidate();
        }
      });
    });
  }

  void _showMatchDialog(MatchCandidate candidate) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.favorite, color: Color(0xFFF43F5E)),
            SizedBox(width: 10),
            Text("It's a Match!"),
          ],
        ),
        content: Text('You and ${candidate.profile.name} liked each other! You can now start chatting.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Later'),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(dialogContext);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ChatConversationView(
                    targetUserUid: candidate.profile.uid,
                    targetUserName: candidate.profile.name,
                  ),
                ),
              );
            },
            icon: const Icon(Icons.chat_bubble_outline),
            label: const Text('Open Chat'),
          ),
        ],
      ),
    );
  }
}

class HighMatchDialog extends StatelessWidget {
  const HighMatchDialog({
    super.key,
    required this.candidate,
    required this.onInterested,
    required this.onSkip,
    required this.onViewProfile,
  });

  final MatchCandidate candidate;
  final VoidCallback onInterested;
  final VoidCallback onSkip;
  final VoidCallback onViewProfile;

  ImageProvider? _decodeProfileImage(String base64String) {
    if (base64String.isEmpty) return null;
    try {
      final cleanBase64 = base64String.contains(',')
          ? base64String.split(',').last
          : base64String;
      return MemoryImage(base64Decode(cleanBase64));
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = candidate.profile;
    final profileImage = _decodeProfileImage(profile.profileImageBase64);
    final score = candidate.compatibilityScore.round();

    return Dialog(
      backgroundColor: const Color(0xFF1E293B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      elevation: 16,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // High Match Tag Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF10B981), Color(0xFF059669)],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF10B981).withValues(alpha: 0.3),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.bolt, color: Colors.white, size: 18),
                  const SizedBox(width: 4),
                  Text(
                    "High Match Soul ($score%)",
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Profile Avatar with Glowing Border
            GestureDetector(
              onTap: onViewProfile,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFF10B981),
                    width: 3,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF10B981).withValues(alpha: 0.3),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: CircleAvatar(
                  radius: 45,
                  backgroundColor: const Color(0xFF334155),
                  backgroundImage: profileImage,
                  child: profileImage == null
                      ? Text(
                          profile.name.isNotEmpty ? profile.name[0].toUpperCase() : '?',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : null,
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Name & Age
            Text(
              "${profile.name}, ${profile.age}",
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 6),

            // Distance & Location
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.location_on, size: 14, color: Color(0xFF60A5FA)),
                const SizedBox(width: 4),
                Text(
                  candidate.distanceKm != null
                      ? "${(candidate.distanceKm! * 1000).round()}m away"
                      : "Nearby",
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Shared Interests Chips
            if (candidate.commonInterests.isNotEmpty) ...[
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 6,
                runSpacing: 6,
                children: candidate.commonInterests.take(3).map((interest) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF334155),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      "#$interest",
                      style: const TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
            ],

            // Prompt text
            const Text(
              "High compatibility soul detected nearby!\nAre you interested?",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 20),

            // Action Buttons (Skip vs Interested)
            Row(
              children: [
                // Skip Button
                Expanded(
                  child: OutlinedButton(
                    onPressed: onSkip,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white70,
                      side: const BorderSide(color: Colors.white24),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      "Skip",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Interested Button
                Expanded(
                  child: ElevatedButton(
                    onPressed: onInterested,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF43F5E),
                      foregroundColor: Colors.white,
                      elevation: 4,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.favorite, size: 18),
                        SizedBox(width: 6),
                        Text(
                          "Interested",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // View Profile Text Link
            TextButton(
              onPressed: onViewProfile,
              child: const Text(
                "View Full Profile",
                style: TextStyle(
                  color: Color(0xFF60A5FA),
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
