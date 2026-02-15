import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
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
    this.onReverseGeocode,
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
  final void Function(String address)? onReverseGeocode;
  final double height;

  @override
  State<LocationPickerMap> createState() => _LocationPickerMapState();
}

class _LocationPickerMapState extends State<LocationPickerMap> {
  static const _defaultCenter = LatLng(55.75, 37.62);
  static const _defaultZoom = 10.0;
  late LatLng _point;
  Timer? _reverseTimer;

  double? get _lat => widget.initialLat ?? widget._legacyLat;
  double? get _lng => widget.initialLng ?? widget._legacyLng;

  void _notifyChange(double lat, double lng) {
    widget.onLocationChanged?.call(lat, lng);
    widget._legacyOnChanged?.call(lat, lng);

    // Debounced reverse geocoding
    if (widget.onReverseGeocode != null) {
      _reverseTimer?.cancel();
      _reverseTimer = Timer(const Duration(milliseconds: 500), () {
        _reverseGeocode(lat, lng);
      });
    }
  }

  Future<void> _reverseGeocode(double lat, double lng) async {
    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/reverse', {
        'format': 'json',
        'lat': lat.toString(),
        'lon': lng.toString(),
        'accept-language': 'ru',
        'addressdetails': '1',
      });
      final res = await http.get(uri, headers: {'User-Agent': 'RealEstateApp/1.0'});
      if (res.statusCode != 200) return;
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final addr = data['address'] as Map<String, dynamic>?;
      if (addr == null) return;

      final city = addr['city'] ?? addr['town'] ?? addr['village'] ?? '';
      final road = addr['road'] ?? '';
      final house = addr['house_number'] ?? '';

      final parts = <String>[];
      if (city != '') parts.add(city as String);
      if (road != '') parts.add(road as String);
      if (house != '') parts.add(house as String);

      if (parts.isNotEmpty && mounted) {
        widget.onReverseGeocode!(parts.join(', '));
      }
    } catch (_) {}
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
  void dispose() {
    _reverseTimer?.cancel();
    super.dispose();
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
