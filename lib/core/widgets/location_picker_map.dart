import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:real_estate_app/app/theme/app_theme.dart';

class LocationPickerMap extends StatefulWidget {
  const LocationPickerMap({
    super.key,
    this.initialLat,
    this.initialLng,
    // Legacy support
    double? lat,
    double? lng,
    void Function(double lat, double lng)? onChanged,
    this.onLocationChanged,
    this.height = 280,
  })  : _legacyLat = lat,
        _legacyLng = lng,
        _legacyOnChanged = onChanged;

  final double? initialLat;
  final double? initialLng;
  final double? _legacyLat;
  final double? _legacyLng;
  final void Function(double lat, double lng)? onLocationChanged;
  final void Function(double lat, double lng)? _legacyOnChanged;
  final double height;

  @override
  State<LocationPickerMap> createState() => _LocationPickerMapState();
}

class _LocationPickerMapState extends State<LocationPickerMap> {
  static const _defaultCenter = LatLng(55.75, 37.62);
  static const _defaultZoom = 10.0;
  late LatLng _point;

  double? get _lat => widget.initialLat ?? widget._legacyLat;
  double? get _lng => widget.initialLng ?? widget._legacyLng;

  void _notifyChange(double lat, double lng) {
    widget.onLocationChanged?.call(lat, lng);
    widget._legacyOnChanged?.call(lat, lng);
  }

  @override
  void initState() {
    super.initState();
    _point = _lat != null && _lng != null ? LatLng(_lat!, _lng!) : _defaultCenter;
  }

  @override
  void didUpdateWidget(LocationPickerMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_lat != null && _lng != null) {
      _point = LatLng(_lat!, _lng!);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: FlutterMap(
          options: MapOptions(
            initialCenter: _point,
            initialZoom: _defaultZoom,
            onTap: (_, pos) {
              setState(() => _point = pos);
              _notifyChange(pos.latitude, pos.longitude);
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
                  width: 48,
                  height: 48,
                  child: Icon(
                    Icons.location_on,
                    color: context.appColors.primary,
                    size: 48,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
