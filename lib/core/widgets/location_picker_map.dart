import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class LocationPickerMap extends StatefulWidget {
  const LocationPickerMap({
    super.key,
    this.lat,
    this.lng,
    required this.onChanged,
    this.height = 280,
  });

  final double? lat;
  final double? lng;
  final void Function(double lat, double lng) onChanged;
  final double height;

  @override
  State<LocationPickerMap> createState() => _LocationPickerMapState();
}

class _LocationPickerMapState extends State<LocationPickerMap> {
  static const _defaultCenter = LatLng(55.75, 37.62);
  static const _defaultZoom = 10.0;
  late LatLng _point;

  @override
  void initState() {
    super.initState();
    _point = widget.lat != null && widget.lng != null
        ? LatLng(widget.lat!, widget.lng!)
        : _defaultCenter;
  }

  @override
  void didUpdateWidget(LocationPickerMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.lat != null && widget.lng != null) {
      _point = LatLng(widget.lat!, widget.lng!);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      child: FlutterMap(
        options: MapOptions(
          initialCenter: _point,
          initialZoom: _defaultZoom,
          onTap: (_, pos) {
            setState(() => _point = pos);
            widget.onChanged(pos.latitude, pos.longitude);
          },
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.example.real_estate_app',
          ),
          MarkerLayer(
            markers: [
              Marker(
                point: _point,
                width: 40,
                height: 40,
                child: const Icon(Icons.place, color: Colors.red, size: 40),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
