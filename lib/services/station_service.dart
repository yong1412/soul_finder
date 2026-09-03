import 'package:flutter/services.dart' show rootBundle;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/radar/radar_models.dart';

/// 专职负责加载与解析 Malaysia 轨道交通（LRT/MRT）静态车站数据的服务类
class StationService {
  /// 从 assets/data/stops.csv 文件读取车站数据并返回 Station 模型列表
  static Future<List<Station>> loadStationsFromCsv({
    String assetPath = 'assets/data/stops.csv',
  }) async {
    final List<Station> stations = [];

    try {
      // 1. 读取 assets 里的 CSV 文件内容
      final String rawData = await rootBundle.loadString(assetPath);

      // 2. 按换行符拆分成行
      final List<String> lines = rawData.split('\n');

      if (lines.isEmpty) return stations;

      // 3. 跳过第一行表头 (stop_id,stop_name,stop_lat,stop_lon,category,route_id)
      for (int i = 1; i < lines.length; i++) {
        final String line = lines[i].trim();
        if (line.isEmpty) continue;

        // 按逗号分割出列
        final List<String> fields = line.split(',');

        if (fields.length >= 5) {
          final String id = fields[0].replaceAll('"', '').trim();
          final String name = fields[1].replaceAll('"', '').trim();
          final double? lat = double.tryParse(fields[2].replaceAll('"', '').trim());
          final double? lon = double.tryParse(fields[3].replaceAll('"', '').trim());
          final String category = fields[4].replaceAll('"', '').trim().toUpperCase();

          if (lat != null && lon != null) {
            // 只保留 LRT 和 MRT 站点（严格排除 BRT 和 MR Monorail）
            if (category == 'LRT' || category == 'MRT') {
              final StationType type = (category == 'LRT')
                  ? StationType.lrt
                  : StationType.mrt;

              stations.add(
                Station(
                  id: id,
                  name: name,
                  latitude: lat,
                  longitude: lon,
                  type: type,
                ),
              );
            }
          }
        }
      }
    } catch (e) {
      print('读取车站 CSV 数据出错: $e');
    }

    return stations;
  }

  /// 将车站列表转换成 Google Maps 所需要的 Set<Marker>
  static Set<Marker> convertToMarkers(
    List<Station> stations, {
    void Function(Station station)? onTap,
  }) {
    final Set<Marker> markers = {};

    for (final station in stations) {
      // LRT 使用红色标记，MRT 使用天蓝色标记
      final double hue = (station.type == StationType.lrt)
          ? BitmapDescriptor.hueRed
          : BitmapDescriptor.hueAzure;

      // 组织规范的标题名称，例如 "LRT - KLCC" 或 "MRT - TUN RAZAK EXCHANGE"
      final String typePrefix = station.type == StationType.lrt ? 'LRT' : 'MRT';

      markers.add(
        Marker(
          markerId: MarkerId(station.id),
          position: LatLng(station.latitude, station.longitude),
          infoWindow: InfoWindow(
            title: '$typePrefix - ${station.name}',
            snippet: 'Station Code: ${station.id}',
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(hue),
          onTap: () {
            if (onTap != null) {
              onTap(station);
            }
          },
        ),
      );
    }

    return markers;
  }
}
