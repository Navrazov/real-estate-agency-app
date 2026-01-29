import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class ListingsMap extends StatelessWidget {
  const ListingsMap({
    super.key,
    required this.markers,
    this.selectedId,
    this.onMarkerTap,
    this.height = 400,
    this.initialCenter,
    this.initialZoom,
  });

  final List<MapMarker> markers;
  final String? selectedId;
  final void Function(String id)? onMarkerTap;
  final double height;
  final LatLng? initialCenter;
  final double? initialZoom;

  static const _defaultCenter = LatLng(55.75, 37.62);
  static const _defaultZoom = 10.0;

  @override
  Widget build(BuildContext context) {
    final center = initialCenter ?? (markers.isNotEmpty ? LatLng(markers.first.lat, markers.first.lng) : _defaultCenter);
    final zoom = initialZoom ?? (markers.length == 1 ? 14.0 : _defaultZoom);
    return SizedBox(
      height: height,
      child: FlutterMap(
        options: MapOptions(
          initialCenter: center,
          initialZoom: zoom,
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.example.real_estate_app',
          ),
          MarkerLayer(
            markers: markers
                .map((m) => Marker(
                      point: LatLng(m.lat, m.lng),
                      width: 40,
                      height: 40,
                      child: GestureDetector(
                        onTap: () => onMarkerTap?.call(m.id),
                        child: Icon(
                          Icons.place,
                          color: selectedId == m.id ? Colors.blue : Colors.red,
                          size: 40,
                        ),
                      ),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }
}

class MapMarker {
  MapMarker({required this.id, required this.lat, required this.lng, this.title});
  final String id;
  final double lat;
  final double lng;
  final String? title;
}
