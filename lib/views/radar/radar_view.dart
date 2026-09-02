import 'package:flutter/material.dart';
import '../../controllers/radar/radar_controller.dart';
import '../../controllers/auth_controller.dart';
import '../../models/radar/radar_models.dart';
import 'radar_painter.dart';

class RadarView extends StatefulWidget {
  const RadarView({
    super.key,
    required this.authController,
  });

  final AuthController authController;

  @override
  State<RadarView> createState() => _RadarViewState();
}

class _RadarViewState extends State<RadarView> with SingleTickerProviderStateMixin {
  late final RadarController _controller;
  late AnimationController _animationController;
  bool _isRadiusExpanded = false;

  @override
  void initState() {
    super.initState();
    // Discovery Radius is stored in km in the profile, convert to meters for radar (50m - 200m)
    final user = widget.authController.currentUser;
    final initialRadius = user != null 
        ? (user.discoveryRadius * 1000).clamp(50.0, 200.0) 
        : 200.0;
    
    _controller = RadarController(initialRadius: initialRadius);
    _controller.startLocationTracking();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    // Listen to profile changes to update radar radius dynamically
    widget.authController.addListener(_onAuthChanged);
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
              Row(
                children: [
                  const Icon(Icons.location_on_outlined, color: Colors.white54, size: 18),
                  const SizedBox(width: 12),
                  Text(
                    "Coordinates: ${record.station.latitude.toStringAsFixed(4)}, ${record.station.longitude.toStringAsFixed(4)}",
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ],
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
                                                  record.station.name,
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
                                                        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                                                        borderRadius: BorderRadius.circular(6),
                                                      ),
                                                      child: Text(
                                                        record.station.type.name.toUpperCase(),
                                                        style: TextStyle(
                                                          color: Theme.of(context).colorScheme.primary,
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
                                    return ListTile(
                                      leading: CircleAvatar(
                                        backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                                        child: Icon(Icons.history, color: Theme.of(context).colorScheme.primary, size: 20),
                                      ),
                                      title: Text(record.station.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).colorScheme;

    return ListenableBuilder(
      listenable: _controller,
      builder: (context, child) {
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
                      gradient: LinearGradient(colors: [theme.primary, theme.secondary]),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(color: theme.secondary.withValues(alpha: 0.3), blurRadius: 8, spreadRadius: 1)
                      ],
                    ),
                    child: _controller.currentStationHotspot == null 
                      ? const SizedBox.shrink()
                      : Row(
                        children: [
                          const Icon(Icons.stars, color: Colors.white, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              "ACTIVE HOTSPOT: ${_controller.currentStationHotspot?.name}",
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const Text("BONUS LUCK", style: TextStyle(color: Colors.white70, fontSize: 10)),
                        ],
                      ),
                  ),

                  // 距离最近站点显示
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
                                "Scanning for nearby stations...",
                                style: TextStyle(fontSize: 12, color: Colors.white38),
                              ),
                            ],
                          );
                        }

                        if (_controller.nearestStation != null && _controller.minDistanceToStation != null) {
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
                                  "Nearest: ${_controller.nearestStation!.name} ",
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
                          "No stations detected in range",
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
                          Text(
                            "My Location: ${_controller.currentPosition!.latitude.toStringAsFixed(4)}, ${_controller.currentPosition!.longitude.toStringAsFixed(4)}",
                            style: const TextStyle(fontSize: 10, color: Colors.white38),
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

                            return const Text(
                              "Scanning for nearby souls...",
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white70,
                                fontWeight: FontWeight.bold,
                              ),
                            );
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
}
