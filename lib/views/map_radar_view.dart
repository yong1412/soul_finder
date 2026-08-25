import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../services/location_service.dart';
import '../services/transport_service.dart';
import '../models/station.dart';

class MapRadarView extends StatefulWidget {
  const MapRadarView({super.key});

  @override
  State<MapRadarView> createState() => _MapRadarViewState();
}

class _MapRadarViewState extends State<MapRadarView> with SingleTickerProviderStateMixin {
  // 模式：寻找朋友 or 寻找伴侣
  Set<String> _scanMode = {'friends'};
  
  late AnimationController _animationController;
  final List<RadarDot> _dots = [];
  
  final LocationService _locationService = LocationService();
  final TransportService _transportService = TransportService();
  Position? _currentPosition;
  bool _isLocationLoaded = false;
  bool _isScanning = false;
  StreamSubscription<Position>? _positionSubscription;
  
  // 附近检测到的“灵魂”数量
  int _soulsFound = 0;
  Station? _currentStationHotspot; // 当前所在的车站热点
  double? _minDistanceToStation; // 距离最近站点的公里数
  Station? _nearestStation; // 最近的站点对象
  
  // 最近访问过的站点记录（包含时间）
  final List<VisitRecord> _recentStations = [];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    _startLocationTracking();
  }

  void _startLocationTracking() async {
    final hasPermission = await _locationService.handleLocationPermission();
    if (!hasPermission) return;

    final position = await _locationService.getCurrentLocation();
    if (position != null && mounted) {
      _updatePosition(position);
    }

    _positionSubscription = _locationService.getLocationStream().listen((position) {
      if (mounted) {
        _updatePosition(position);
      }
    });
  }

  void _updatePosition(Position position) {
    setState(() {
      _currentPosition = position;
      _isLocationLoaded = true;
    });

    _performRadarScan(position);
  }

  // 核心逻辑：扫描附近的“灵魂”
  Future<void> _performRadarScan(Position position) async {
    if (_isScanning) return;
    setState(() => _isScanning = true);
    
    // 1. 利用 Google API 获取附近的车站作为“社交锚点”
    final stations = await _transportService.getNearbyStations(
      position.latitude, 
      position.longitude
    );
    
    if (mounted) {
      setState(() {
        _isScanning = false;
        _generateSoulsFromHotspots(position, stations);
      });
    }
  }

  void _generateSoulsFromHotspots(Position current, List<Station> stations) {
    _dots.clear();
    final random = math.Random();
    
    _currentStationHotspot = null;
    _nearestStation = null;
    double minDistance = double.infinity;

    for (var station in stations) {
      // 使用更精确的距离计算
      double distance = _calculateDistance(
        current.latitude, current.longitude,
        station.latitude, station.longitude
      );

      // 记录全球最近的站点
      if (distance < minDistance) {
        minDistance = distance;
        _nearestStation = station;
      }

      // 如果进入 500 米（0.5km）范围，标记为热点并记录
      if (distance < 0.5) {
        _currentStationHotspot = station;
        _addToRecentStations(station);
      }

      // 为每个车站锚点生成“灵魂”点
      int soulsAtStation = 1 + random.nextInt(3);
      for (int i = 0; i < soulsAtStation; i++) {
        // 在车站坐标附近做随机偏移，模拟真实用户分布
        double offsetLat = (random.nextDouble() - 0.5) * 0.005;
        final double offsetLng = (random.nextDouble() - 0.5) * 0.005;
        
        double relativeLat = (station.latitude + offsetLat) - current.latitude;
        double relativeLng = (station.longitude + offsetLng) - current.longitude;
        
        double radarDist = math.sqrt(relativeLat * relativeLat + relativeLng * relativeLng) * 1000;
        double angle = math.atan2(relativeLat, relativeLng);

        _dots.add(RadarDot(
          distance: (radarDist / 60).clamp(0.1, 0.95),
          angle: angle,
          size: 4.0 + random.nextDouble() * 4,
        ));
      }
    }
    _soulsFound = _dots.length;
    _minDistanceToStation = minDistance == double.infinity ? null : minDistance;
  }

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    var p = 0.017453292519943295;
    var c = math.cos;
    var a = 0.5 - c((lat2 - lat1) * p)/2 + 
          c(lat1 * p) * c(lat2 * p) * 
          (1 - c((lon2 - lon1) * p))/2;
    return 12742 * math.asin(math.sqrt(a));
  }

  void _addToRecentStations(Station station) {
    final now = DateTime.now();
    bool existsRecently = _recentStations.any((r) => 
      r.station.id == station.id && 
      now.difference(r.timestamp).inMinutes < 60
    );

    if (!existsRecently) {
      setState(() {
        _recentStations.insert(0, VisitRecord(
          station: station,
          timestamp: now,
        ));
        if (_recentStations.length > 10) {
          _recentStations.removeLast();
        }
      });
    }
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
                  itemCount: _recentStations.length,
                  itemBuilder: (context, index) {
                    final record = _recentStations[index];
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
      },
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _positionSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).colorScheme;

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
                selected: _scanMode,
                onSelectionChanged: (Set<String> newSelection) {
                  setState(() {
                    _scanMode = newSelection;
                    if (_currentPosition != null) {
                      _performRadarScan(_currentPosition!);
                    }
                  });
                },
                style: SegmentedButton.styleFrom(
                  backgroundColor: theme.surface,
                  selectedBackgroundColor: _scanMode.first == 'couple' 
                      ? theme.secondary.withOpacity(0.3)
                      : theme.primary.withOpacity(0.3),
                  side: BorderSide(color: Colors.white.withOpacity(0.1)),
                ),
              ),
              
              // 热点状态条
              AnimatedContainer(
                duration: const Duration(milliseconds: 500),
                height: _currentStationHotspot != null ? 50 : 0,
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
                        "ACTIVE HOTSPOT: ${_currentStationHotspot?.name}",
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const Text("BONUS LUCK", style: TextStyle(color: Colors.white70, fontSize: 10)),
                  ],
                ),
              ),

              // 距离最近站点显示
              if (_nearestStation != null && _minDistanceToStation != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.directions_bus, size: 14, color: theme.primary.withOpacity(0.7)),
                      const SizedBox(width: 6),
                      Text(
                        "Nearest: ${_nearestStation!.name} ",
                        style: const TextStyle(fontSize: 12, color: Colors.white70),
                      ),
                      Text(
                        "(${(_minDistanceToStation! * 1000).toInt()}m)",
                        style: TextStyle(
                          fontSize: 12, 
                          color: _minDistanceToStation! < 0.5 ? theme.secondary : theme.primary,
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
                              color: _scanMode.first == 'couple' ? theme.secondary : theme.primary,
                              dots: _dots,
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
                              color: (_scanMode.first == 'couple' ? theme.secondary : theme.primary).withOpacity(0.3),
                              blurRadius: 15,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: _isScanning 
                          ? const Padding(
                              padding: EdgeInsets.all(12.0),
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(
                              _scanMode.first == 'couple' ? Icons.favorite : Icons.person,
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
                    if (_currentPosition != null)
                      Text(
                        "My Location: ${_currentPosition!.latitude.toStringAsFixed(4)}, ${_currentPosition!.longitude.toStringAsFixed(4)}",
                        style: const TextStyle(fontSize: 10, color: Colors.white38),
                      ),
                    const SizedBox(height: 10),
                    Text(
                      _soulsFound > 0 
                        ? "Detected $_soulsFound potential ${_scanMode.first == 'couple' ? 'matches' : 'friends'}" 
                        : "Scanning for nearby souls...",
                      style: TextStyle(
                        fontSize: 14, 
                        color: _scanMode.first == 'couple' ? theme.secondary : Colors.white70,
                        fontWeight: FontWeight.bold
                      ),
                    ),

                    // 最近站点按钮区域
                    const SizedBox(height: 25),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40),
                      child: InkWell(
                        onTap: () {
                          if (_recentStations.isEmpty) {
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
                            color: _recentStations.isEmpty 
                                ? Colors.white.withOpacity(0.05) 
                                : theme.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(
                              color: _recentStations.isEmpty ? Colors.white10 : theme.primary.withOpacity(0.3)
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.history_toggle_off, 
                                size: 18, 
                                color: _recentStations.isEmpty ? Colors.white24 : theme.primary
                              ),
                              const SizedBox(width: 12),
                              Text(
                                "VIEW RECENT HOTSPOTS",
                                style: TextStyle(
                                  fontSize: 11, 
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.1,
                                  color: _recentStations.isEmpty ? Colors.white24 : Colors.white
                                ),
                              ),
                              if (_recentStations.isNotEmpty) ...[
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(color: theme.primary, shape: BoxShape.circle),
                                  child: Text("${_recentStations.length}", style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)),
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
}

class RadarDot {
  final double distance;
  final double angle;
  final double size;

  RadarDot({
    required this.distance,
    required this.angle,
    required this.size,
  });
}

class RadarPainter extends CustomPainter {
  final double progress;
  final Color color;
  final List<RadarDot> dots;

  RadarPainter({
    required this.progress,
    required this.color,
    required this.dots,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;

    final paint = Paint()
      ..color = color.withOpacity(0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    // Draw concentric circles
    canvas.drawCircle(center, radius, paint);
    canvas.drawCircle(center, radius * 0.7, paint);
    canvas.drawCircle(center, radius * 0.4, paint);

    // Draw axis lines
    canvas.drawLine(Offset(center.dx - radius, center.dy), Offset(center.dx + radius, center.dy), paint);
    canvas.drawLine(Offset(center.dx, center.dy - radius), Offset(center.dx, center.dy + radius), paint);

    // Draw rotating sweep
    final sweepPaint = Paint()
      ..shader = SweepGradient(
        center: Alignment.center,
        startAngle: 0.0,
        endAngle: math.pi * 2,
        colors: [
          color.withOpacity(0.0),
          color.withOpacity(0.5),
        ],
        stops: const [0.75, 1.0],
        transform: GradientRotation(progress * 2 * math.pi - math.pi / 2),
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawCircle(center, radius, sweepPaint);
    
    // Draw the "front" line of the sweep
    final linePaint = Paint()
      ..color = color.withOpacity(0.8)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;
    
    final angle = progress * 2 * math.pi - math.pi / 2;
    canvas.drawLine(
      center,
      Offset(center.dx + radius * math.cos(angle), center.dy + radius * math.sin(angle)),
      linePaint,
    );

    // Draw dots
    for (var dot in dots) {
      final dotAngle = dot.angle;
      double currentSweepAngle = (progress * 2 * math.pi) % (2 * math.pi);
      double normalizedDotAngle = (dotAngle + math.pi / 2) % (2 * math.pi);
      
      double angleDiff = (currentSweepAngle - normalizedDotAngle);
      if (angleDiff < 0) angleDiff += 2 * math.pi;
      
      if (angleDiff < math.pi / 2) {
        final opacity = 1.0 - (angleDiff / (math.pi / 2));
        final dotPaint = Paint()
          ..color = color.withOpacity(opacity)
          ..style = PaintingStyle.fill;
        
        final dotOffset = Offset(
          center.dx + radius * dot.distance * math.cos(dotAngle),
          center.dy + radius * dot.distance * math.sin(dotAngle),
        );
        
        canvas.drawCircle(dotOffset, dot.size, dotPaint);
        canvas.drawCircle(
          dotOffset, 
          dot.size * 2, 
          Paint()..color = color.withOpacity(opacity * 0.3)..style = PaintingStyle.fill
        );
      }
    }
  }

  @override
  bool shouldRepaint(RadarPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color || oldDelegate.dots != dots;
  }
}
