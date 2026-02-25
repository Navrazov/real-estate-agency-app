import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:real_estate_app/core/widgets/yandex_web_embed.dart';

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
  final MapPoint? initialCenter;
  final double? initialZoom;

  static const _defaultCenter = MapPoint(43.3178, 45.6986);
  static const _defaultZoom = 11.0;

  @override
  State<ListingsMap> createState() => _ListingsMapState();
}

class _ListingsMapState extends State<ListingsMap> {
  static const _yandexApiKey = String.fromEnvironment('YANDEX_MAPS_API_KEY');
  WebViewController? _controller;
  bool get _canUseWebView =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  @override
  void initState() {
    super.initState();

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
          'MarkerTap',
          onMessageReceived: (message) {
            widget.onMarkerTap?.call(message.message);
          },
        );
      _loadMapHtml();
    }
  }

  @override
  void didUpdateWidget(covariant ListingsMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_canUseWebView && !_markersEqual(oldWidget.markers, widget.markers)) {
      _loadMapHtml();
    }
  }

  bool _markersEqual(List<MapMarker> a, List<MapMarker> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id ||
          a[i].lat != b[i].lat ||
          a[i].lng != b[i].lng ||
          a[i].title != b[i].title ||
          a[i].subtitle != b[i].subtitle ||
          a[i].price != b[i].price ||
          a[i].imageUrl != b[i].imageUrl) {
        return false;
      }
    }
    return true;
  }

  void _loadMapHtml() {
    if (_yandexApiKey.isEmpty) return;

    final center = widget.initialCenter ??
        (widget.markers.isNotEmpty
            ? MapPoint(widget.markers.first.lat, widget.markers.first.lng)
            : ListingsMap._defaultCenter);
    final zoom = widget.initialZoom ??
        (widget.markers.length == 1 ? 14.0 : ListingsMap._defaultZoom);

    final markersJson = jsonEncode(
      widget.markers
          .map(
            (m) => {
              'id': m.id,
              'lat': m.lat,
              'lng': m.lng,
              'title': m.title ?? 'Объявление',
              'subtitle': m.subtitle ?? '',
              'price': m.price,
              'url': '/listing/${m.id}',
            },
          )
          .toList(),
    );

    final selectedId = widget.selectedId ?? '';

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
      const center = [${center.lat}, ${center.lng}];
      const zoom = $zoom;
      const markers = $markersJson;
      const selectedId = '$selectedId';

      var mapInstance;
      function locateMe() {
        if (!mapInstance || !navigator.geolocation) return;
        navigator.geolocation.getCurrentPosition(function(pos) {
          mapInstance.setCenter([pos.coords.latitude, pos.coords.longitude], 12, { duration: 220 });
        }, function() {}, { enableHighAccuracy: true, timeout: 8000 });
      }

      ymaps.ready(function() {
        mapInstance = new ymaps.Map('map', {
          center,
          zoom,
          controls: ['zoomControl']
        }, {
          suppressMapOpenBlock: true,
          restrictMapArea: [[85.23618, -178.9], [-73.87011, 181]]
        });
        try { mapInstance.behaviors.disable('ruler'); } catch (e) {}

        const clusterer = new ymaps.Clusterer({
          preset: 'islands#invertedBlueClusterIcons',
          groupByCoordinates: false,
          clusterDisableClickZoom: false
        });

        const placemarks = markers.map((m) => {
          const isSelected = selectedId === m.id;
          const placemark = new ymaps.Placemark(
            [m.lat, m.lng],
            {
              hintContent: m.title,
            },
            {
              preset: isSelected ? 'islands#redIcon' : 'islands#blueIcon',
              hasBalloon: false,
              openBalloonOnClick: false
            }
          );
          placemark.events.add('click', function() {
            MarkerTap.postMessage(m.id);
          });
          return placemark;
        });

        clusterer.add(placemarks);
        mapInstance.geoObjects.add(clusterer);

        try {
          if (placemarks.length === 1) {
            const coords = placemarks[0].geometry.getCoordinates();
            mapInstance.setCenter(coords, Math.max(mapInstance.getZoom(), 12), { duration: 180 });
          } else if (placemarks.length > 1) {
            const bounds = clusterer.getBounds();
            if (bounds) {
              mapInstance.setBounds(bounds, { checkZoomRange: true, zoomMargin: 40, duration: 180 });
            }
          }
        } catch (e) {}

      });
    </script>
  </body>
</html>
''';

    _controller?.loadHtmlString(html);
  }

  void _handleWebMessage(Map<String, dynamic> message) {
    final type = message['type'];
    final id = message['id']?.toString();
    if (id == null || id.isEmpty) return;
    if (type == 'markerTap') widget.onMarkerTap?.call(id);
  }

  @override
  Widget build(BuildContext context) {
    if (_yandexApiKey.isEmpty) {
      return SizedBox(
        height: widget.height == double.infinity ? null : widget.height,
        child: const Center(
          child: Text('Не задан YANDEX_MAPS_API_KEY'),
        ),
      );
    }

    final html = _buildMapHtml();
    final map = kIsWeb
        ? YandexWebIFrame(html: html, onMessage: _handleWebMessage)
        : (_canUseWebView && _controller != null)
            ? WebViewWidget(controller: _controller!)
            : const Center(
                child: Text('Карта доступна только на iOS/Android/Web'));
    if (widget.height == double.infinity) {
      return SizedBox.expand(child: map);
    }

    return SizedBox(height: widget.height, child: map);
  }

  String _buildMapHtml() {
    final center = widget.initialCenter ??
        (widget.markers.isNotEmpty
            ? MapPoint(widget.markers.first.lat, widget.markers.first.lng)
            : ListingsMap._defaultCenter);
    final zoom = widget.initialZoom ??
        (widget.markers.length == 1 ? 14.0 : ListingsMap._defaultZoom);

    final markersJson = jsonEncode(
      widget.markers
          .map(
            (m) => {
              'id': m.id,
              'lat': m.lat,
              'lng': m.lng,
              'title': m.title ?? 'Объявление',
              'subtitle': m.subtitle ?? '',
              'price': m.price,
            },
          )
          .toList(),
    );

    final selectedId = widget.selectedId ?? '';

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
      const center = [${center.lat}, ${center.lng}];
      const zoom = $zoom;
      const markers = $markersJson;
      const selectedId = '$selectedId';
      var mapInstance;
      function locateMe() {
        if (!mapInstance || !navigator.geolocation) return;
        navigator.geolocation.getCurrentPosition(function(pos) {
          mapInstance.setCenter([pos.coords.latitude, pos.coords.longitude], 12, { duration: 220 });
        }, function() {}, { enableHighAccuracy: true, timeout: 8000 });
      }
      ymaps.ready(function() {
        mapInstance = new ymaps.Map('map', { center, zoom, controls: ['zoomControl'] }, { suppressMapOpenBlock: true, restrictMapArea: [[85.23618, -178.9], [-73.87011, 181]] });
        try { mapInstance.behaviors.disable('ruler'); } catch (e) {}
        const clusterer = new ymaps.Clusterer({ preset: 'islands#invertedBlueClusterIcons', groupByCoordinates: false, clusterDisableClickZoom: false });
        const placemarks = markers.map((m) => {
          const isSelected = selectedId === m.id;
          const placemark = new ymaps.Placemark(
            [m.lat, m.lng],
            { hintContent: m.title },
            { preset: isSelected ? 'islands#redIcon' : 'islands#blueIcon', hasBalloon: false, openBalloonOnClick: false }
          );
          placemark.events.add('click', function() { window.parent.postMessage({type:'markerTap',id:m.id}, '*'); });
          return placemark;
        });
        clusterer.add(placemarks);
        mapInstance.geoObjects.add(clusterer);
        try {
          if (placemarks.length === 1) {
            const coords = placemarks[0].geometry.getCoordinates();
            mapInstance.setCenter(coords, Math.max(mapInstance.getZoom(), 12), { duration: 180 });
          } else if (placemarks.length > 1) {
            const bounds = clusterer.getBounds();
            if (bounds) mapInstance.setBounds(bounds, { checkZoomRange: true, zoomMargin: 40, duration: 180 });
          }
        } catch (e) {}
      });
    </script>
  </body>
</html>
''';
  }
}

class MapMarker {
  MapMarker(
      {required this.id,
      required this.lat,
      required this.lng,
      this.title,
      this.subtitle,
      this.price,
      this.imageUrl});
  final String id;
  final double lat;
  final double lng;
  final String? title;
  final String? subtitle;
  final double? price;
  final String? imageUrl;
}

class MapPoint {
  const MapPoint(this.lat, this.lng);
  final double lat;
  final double lng;
}
