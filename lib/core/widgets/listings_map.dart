import 'package:flutter/material.dart';
import 'package:real_estate_app/app/theme/app_theme.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class ListingsMap extends StatefulWidget {
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
  State<ListingsMap> createState() => _ListingsMapState();
}

class _ListingsMapState extends State<ListingsMap> {
  late final MapController _mapController;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final center = widget.initialCenter ??
        (widget.markers.isNotEmpty
            ? LatLng(widget.markers.first.lat, widget.markers.first.lng)
            : ListingsMap._defaultCenter);
    final zoom = widget.initialZoom ??
        (widget.markers.length == 1 ? 14.0 : ListingsMap._defaultZoom);

    final map = FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: center,
        initialZoom: zoom,
        // Absorb all gestures so they don't propagate to parent
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all,
        ),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.example.real_estate_app',
        ),
        MarkerLayer(
          markers: widget.markers
              .map((m) => Marker(
                    point: LatLng(m.lat, m.lng),
                    width: 40,
                    height: 40,
                    child: GestureDetector(
                      onTap: () => widget.onMarkerTap?.call(m.id),
                      child: Icon(
                        Icons.place,
                        color: widget.selectedId == m.id
                            ? context.appColors.primary
                            : context.appColors.error,
                        size: 40,
                      ),
                    ),
                  ))
              .toList(),
        ),
      ],
    );

    if (widget.height == double.infinity) {
      return map;
    }
    return SizedBox(
      height: widget.height,
      child: map,
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
