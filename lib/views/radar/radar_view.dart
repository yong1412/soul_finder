import 'package:flutter/material.dart';
import '../../controllers/radar/radar_controller.dart';
import '../../models/radar/radar_models.dart';
import 'radar_painter.dart';

class RadarView extends StatefulWidget {
  const RadarView({super.key});

  @override
  State<RadarView> createState() => _RadarViewState();
}

class _RadarViewState extends State<RadarView> with SingleTickerProviderStateMixin {
  late final RadarController _controller;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _controller = RadarController();
    _controller.startLocationTracking();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
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
                      color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
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
            return Container(
              height: MediaQuery.of(context).size.height * 0.6,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(2))),
                  const Padding(
                    padding: EdgeInsets.all(24.0),
                    child: Text("History Logs", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                  const Divider(height: 1, color: Colors.white10),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      itemCount: _controller.recentStations.length,
                      itemBuilder: (context, index) {
                        final record = _controller.recentStations[index];
                        final timeStr = "${record.timestamp.hour.toString().padLeft(2, '0')}:${record.timestamp.minute.toString().padLeft(2, '0')}";
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
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
                  ),
                ],
              ),
            );
          }
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).colorScheme;

    return ListenableBuilder(
      listenable: _controller,
      builder: (context, child) {
        return Column(
          children: [
            // Top Selection Area
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              child: Column(
                children: [
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment<String>(
                        value: 'friends',
                        label: Text('Find Friends'),
                        icon: Icon(Icons.people_alt),
                      ),
                      ButtonSegment<String>(
                        value: 'couple',
                        label: Text('Find Couple'),
                        icon: Icon(Icons.favorite),
                      ),
                    ],
                    selected: _controller.scanMode,
                    onSelectionChanged: (Set<String> newSelection) {
                      _controller.setScanMode(newSelection);
                    },
                    style: SegmentedButton.styleFrom(
                      backgroundColor: theme.surface,
                      selectedBackgroundColor: _controller.scanMode.first == 'couple' 
                          ? theme.secondary.withOpacity(0.3)
                          : theme.primary.withOpacity(0.3),
                      side: BorderSide(color: Colors.white.withOpacity(0.1)),
                    ),
                  ),
                  
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
                        BoxShadow(color: theme.secondary.withOpacity(0.3), blurRadius: 8, spreadRadius: 1)
                      ],
                    ),
                    child: Row(
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
                  if (_controller.nearestStation != null && _controller.minDistanceToStation != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.directions_bus, size: 14, color: theme.primary.withOpacity(0.7)),
                          const SizedBox(width: 6),
                          Text(
                            "Nearest: ${_controller.nearestStation!.name} ",
                            style: const TextStyle(fontSize: 12, color: Colors.white70),
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
                      ),
                    ),
                ],
              ),
            ),

            // Radar section
            Expanded(
              child: Stack(
                children: [
                  Center(
                    child: Container(
                      width: 320,
                      height: 320,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: theme.primary.withOpacity(0.1), width: 1),
                        color: Colors.black12,
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
                                  color: _controller.scanMode.first == 'couple' ? theme.secondary : theme.primary,
                                  dots: _controller.dots,
                                ),
                              );
                            },
                          ),
                          
                          // Center Icon
                          Container(
                            height: 50,
                            width: 50,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: theme.surface,
                              border: Border.all(color: Colors.white24, width: 2),
                              boxShadow: [
                                BoxShadow(
                                  color: (_controller.scanMode.first == 'couple' ? theme.secondary : theme.primary).withOpacity(0.3),
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
                                  _controller.scanMode.first == 'couple' ? Icons.favorite : Icons.person,
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
                    bottom: 30,
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
                        Text(
                          _controller.soulsFound > 0 
                            ? "Detected ${_controller.soulsFound} potential ${_controller.scanMode.first == 'couple' ? 'matches' : 'friends'}" 
                            : "Scanning for nearby souls...",
                          style: TextStyle(
                            fontSize: 14, 
                            color: _controller.scanMode.first == 'couple' ? theme.secondary : Colors.white70,
                            fontWeight: FontWeight.bold
                          ),
                        ),

                        // 最近站点按钮区域
                        const SizedBox(height: 25),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 40),
                          child: InkWell(
                            onTap: () {
                              if (_controller.recentStations.isEmpty) {
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
                              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                              decoration: BoxDecoration(
                                color: _controller.recentStations.isEmpty 
                                    ? Colors.white.withOpacity(0.05) 
                                    : theme.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(15),
                                border: Border.all(
                                  color: _controller.recentStations.isEmpty ? Colors.white10 : theme.primary.withOpacity(0.3)
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.history_toggle_off, 
                                    size: 18, 
                                    color: _controller.recentStations.isEmpty ? Colors.white24 : theme.primary
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    "VIEW RECENT HOTSPOTS",
                                    style: TextStyle(
                                      fontSize: 11, 
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1.1,
                                      color: _controller.recentStations.isEmpty ? Colors.white24 : Colors.white
                                    ),
                                  ),
                                  if (_controller.recentStations.isNotEmpty) ...[
                                    const Spacer(),
                                    Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(color: theme.primary, shape: BoxShape.circle),
                                      child: Text("${_controller.recentStations.length}", style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)),
                                    )
                                  ]
                                ],
                              ),
                            ),
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
