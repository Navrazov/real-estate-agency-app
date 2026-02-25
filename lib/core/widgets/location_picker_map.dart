import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:webview_flutter/webview_flutter.dart';
import 'package:real_estate_app/core/widgets/yandex_web_embed.dart';

class LocationPickerMap extends StatefulWidget {
  const LocationPickerMap({
    super.key,
    this.initialLat,
    this.initialLng,
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
  static const _defaultCenter = _MapPoint(43.3178, 45.6986);
  static const _defaultZoom = 11.0;
  static const _yandexApiKey = String.fromEnvironment('YANDEX_MAPS_API_KEY');
  static const _yandexGeocoderApiKey = String.fromEnvironment(
    'YANDEX_GEOCODER_API_KEY',
    defaultValue: String.fromEnvironment('YANDEX_MAPS_API_KEY'),
  );

  WebViewController? _controller;

  Timer? _reverseTimer;
  _MapPoint _point = _defaultCenter;

  double? get _lat => widget.initialLat ?? widget._legacyLat;
  double? get _lng => widget.initialLng ?? widget._legacyLng;
  bool get _canUseWebView =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  @override
  void initState() {
    super.initState();

    if (_lat != null && _lng != null) {
      _point = _MapPoint(_lat!, _lng!);
    }

    if (_canUseWebView) {
      _controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setNavigationDelegate(
          NavigationDelegate(
            onNavigationRequest: (request) {
              if (request.url.startsWith('about:blank')) {
                return NavigationDecision.navigate;
              }
              return NavigationDecision.prevent;
            },
          ),
        )
        ..addJavaScriptChannel(
          'LocationChanged',
          onMessageReceived: (message) {
            _handleLocationMessage(message.message);
          },
        );

      _loadHtml();
    }
  }

  @override
  void didUpdateWidget(covariant LocationPickerMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_lat != null && _lng != null) {
      final next = _MapPoint(_lat!, _lng!);
      if (next.lat != _point.lat || next.lng != _point.lng) {
        _point = next;
        _controller
            ?.runJavaScript('window.setPoint(${_point.lat}, ${_point.lng});')
            .catchError((_) {});
      }
    }
  }

  @override
  void dispose() {
    _reverseTimer?.cancel();
    super.dispose();
  }

  void _notifyChange(double lat, double lng) {
    widget.onLocationChanged?.call(lat, lng);
    widget._legacyOnChanged?.call(lat, lng);

    if (widget.onReverseGeocode != null) {
      _reverseTimer?.cancel();
      _reverseTimer = Timer(const Duration(milliseconds: 450), () {
        _reverseGeocode(lat, lng);
      });
    }
  }

  Future<void> _reverseGeocode(double lat, double lng) async {
    if (_yandexGeocoderApiKey.isEmpty) return;
    try {
      final uri = Uri.https('geocode-maps.yandex.ru', '/1.x/', {
        'apikey': _yandexGeocoderApiKey,
        'format': 'json',
        'lang': 'ru_RU',
        'geocode': '${lng.toStringAsFixed(6)},${lat.toStringAsFixed(6)}',
        'results': '1',
      });
      final res = await http.get(uri, headers: {'Accept': 'application/json'});
      if (res.statusCode >= 400) return;
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final collection =
          ((data['response'] as Map<String, dynamic>?)?['GeoObjectCollection']
                  as Map<String, dynamic>?) ??
              const {};
      final members =
          (collection['featureMember'] as List<dynamic>? ?? const []);
      Map<String, dynamic>? member;
      for (final entry in members) {
        if (entry is Map<String, dynamic>) {
          member = entry;
          break;
        }
      }
      final geo = member?['GeoObject'] as Map<String, dynamic>?;
      final meta = (geo?['metaDataProperty']
              as Map<String, dynamic>?)?['GeocoderMetaData']
          as Map<String, dynamic>?;
      final address = meta?['text'] as String?;
      if (address != null && mounted) {
        widget.onReverseGeocode?.call(address);
      } else if (mounted) {
        widget.onReverseGeocode
            ?.call('${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}');
      }
    } catch (_) {
      if (mounted) {
        widget.onReverseGeocode
            ?.call('${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}');
      }
    }
  }

  void _loadHtml() {
    if (_yandexApiKey.isEmpty) return;

    final html = '''
<!DOCTYPE html>
<html>
  <head>
    <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no" />
    <style>
      html, body, #map { margin: 0; padding: 0; width: 100%; height: 100%; }
      [class*="ymaps-2-1-"][class*="copyright"],
      [class*="ymaps-2-1-"][class*="gototech"],
      [class*="ymaps-2-1-"][class*="map-copyrights-promo"],
      [class*="ymaps-2-1-"][class*="traffic"],
      [class*="ymaps-2-1-"][class*="layers"] { display: none !important; }
      .locate-btn { position: absolute; bottom: 12px; right: 12px; z-index: 10; background: rgba(255,255,255,0.95); color: #334155; border: 1px solid #e2e8f0; border-radius: 8px; padding: 8px 12px; font-size: 12px; font-weight: 600; font-family: Inter, sans-serif; cursor: pointer; box-shadow: 0 1px 3px rgba(0,0,0,0.1); }
    </style>
    <script src="https://api-maps.yandex.ru/2.1/?apikey=$_yandexApiKey&lang=ru_RU" type="text/javascript"></script>
  </head>
  <body>
    <div id="map"></div>
    <button class="locate-btn" onclick="locateMe()">Моя локация</button>
    <script>
      const startPoint = [${_point.lat}, ${_point.lng}];
      const startZoom = ${_lat != null && _lng != null ? 14.0 : _defaultZoom};
      let map;
      let marker;

      function emit(coords) {
        LocationChanged.postMessage(coords[0] + ',' + coords[1]);
      }

      function locateMe() {
        if (!map || !navigator.geolocation) return;
        navigator.geolocation.getCurrentPosition(function(pos) {
          const coords = [pos.coords.latitude, pos.coords.longitude];
          marker.geometry.setCoordinates(coords);
          map.setCenter(coords, 12, { duration: 220 });
          emit(coords);
        }, function() {}, { enableHighAccuracy: true, timeout: 8000 });
      }

      window.setPoint = function(lat, lng) {
        if (!map || !marker) return;
        const coords = [lat, lng];
        marker.geometry.setCoordinates(coords);
        map.setCenter(coords, Math.max(map.getZoom(), 12), { duration: 150 });
      }

      ymaps.ready(function() {
        map = new ymaps.Map('map', {
          center: startPoint,
          zoom: startZoom,
          controls: ['zoomControl']
        }, {
          suppressMapOpenBlock: true,
          restrictMapArea: [[85.23618, -178.9], [-73.87011, 181]]
        });
        try { map.behaviors.disable('ruler'); } catch (e) {}

        marker = new ymaps.Placemark(startPoint, {}, {
          preset: 'islands#redIcon',
          draggable: true
        });

        marker.events.add('dragend', function() {
          emit(marker.geometry.getCoordinates());
        });

        map.events.add('click', function(evt) {
          const coords = evt.get('coords');
          marker.geometry.setCoordinates(coords);
          emit(coords);
        });

        map.geoObjects.add(marker);

      });
    </script>
  </body>
</html>
''';

    _controller?.loadHtmlString(html);
  }

  void _handleLocationMessage(String value) {
    final parts = value.split(',');
    if (parts.length != 2) return;
    final lat = double.tryParse(parts[0]);
    final lng = double.tryParse(parts[1]);
    if (lat == null || lng == null) return;
    _point = _MapPoint(lat, lng);
    _notifyChange(lat, lng);
  }

  void _handleWebMessage(Map<String, dynamic> message) {
    if (message['type'] != 'locationChanged') return;
    final lat = message['lat'];
    final lng = message['lng'];
    if (lat is! num || lng is! num) return;
    _point = _MapPoint(lat.toDouble(), lng.toDouble());
    _notifyChange(_point.lat, _point.lng);
  }

  @override
  Widget build(BuildContext context) {
    if (_yandexApiKey.isEmpty) {
      return SizedBox(
        height: widget.height,
        child: const Center(child: Text('Не задан YANDEX_MAPS_API_KEY')),
      );
    }

    final html = _buildHtml();
    final mapWidget = kIsWeb
        ? YandexWebIFrame(html: html, onMessage: _handleWebMessage)
        : (_canUseWebView && _controller != null)
            ? WebViewWidget(controller: _controller!)
            : const Center(
                child: Text('Карта доступна только на iOS/Android/Web'));

    return SizedBox(
      height: widget.height,
      child: mapWidget,
    );
  }

  String _buildHtml() {
    return '''
<!DOCTYPE html>
<html>
  <head>
    <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no" />
    <style>
      html, body, #map { margin: 0; padding: 0; width: 100%; height: 100%; }
      [class*="ymaps-2-1-"][class*="copyright"],
      [class*="ymaps-2-1-"][class*="gototech"],
      [class*="ymaps-2-1-"][class*="map-copyrights-promo"],
      [class*="ymaps-2-1-"][class*="traffic"],
      [class*="ymaps-2-1-"][class*="layers"] { display: none !important; }
      .locate-btn { position: absolute; bottom: 12px; right: 12px; z-index: 10; background: rgba(255,255,255,0.95); color: #334155; border: 1px solid #e2e8f0; border-radius: 8px; padding: 8px 12px; font-size: 12px; font-weight: 600; font-family: Inter, sans-serif; cursor: pointer; box-shadow: 0 1px 3px rgba(0,0,0,0.1); }
    </style>
    <script src="https://api-maps.yandex.ru/2.1/?apikey=$_yandexApiKey&lang=ru_RU" type="text/javascript"></script>
  </head>
  <body>
    <div id="map"></div>
    <button class="locate-btn" onclick="locateMe()">Моя локация</button>
    <script>
      const startPoint = [${_point.lat}, ${_point.lng}];
      const startZoom = ${_lat != null && _lng != null ? 14.0 : _defaultZoom};
      let map; let marker;
      function emit(coords) {
        if (window.parent && window.parent !== window) {
          window.parent.postMessage({ type: 'locationChanged', lat: coords[0], lng: coords[1] }, '*');
        } else if (window.LocationChanged && window.LocationChanged.postMessage) {
          window.LocationChanged.postMessage(coords[0] + ',' + coords[1]);
        }
      }
      function locateMe() {
        if (!map || !navigator.geolocation) return;
        navigator.geolocation.getCurrentPosition(function(pos) {
          const coords = [pos.coords.latitude, pos.coords.longitude];
          marker.geometry.setCoordinates(coords);
          map.setCenter(coords, 12, { duration: 220 });
          emit(coords);
        }, function() {}, { enableHighAccuracy: true, timeout: 8000 });
      }
      window.setPoint = function(lat, lng) {
        if (!map || !marker) return;
        const coords = [lat, lng];
        marker.geometry.setCoordinates(coords);
        map.setCenter(coords, Math.max(map.getZoom(), 12), { duration: 150 });
      }
      ymaps.ready(function() {
        map = new ymaps.Map('map', { center: startPoint, zoom: startZoom, controls: ['zoomControl'] }, { suppressMapOpenBlock: true, restrictMapArea: [[85.23618, -178.9], [-73.87011, 181]] });
        try { map.behaviors.disable('ruler'); } catch (e) {}
        marker = new ymaps.Placemark(startPoint, {}, { preset: 'islands#redIcon', draggable: true });
        marker.events.add('dragend', function() { emit(marker.geometry.getCoordinates()); });
        map.events.add('click', function(evt) { const coords = evt.get('coords'); marker.geometry.setCoordinates(coords); emit(coords); });
        map.geoObjects.add(marker);
      });
    </script>
  </body>
</html>
''';
  }
}

class _MapPoint {
  const _MapPoint(this.lat, this.lng);
  final double lat;
  final double lng;
}
