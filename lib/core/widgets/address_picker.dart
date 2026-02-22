import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:real_estate_app/app/theme/app_theme.dart';

class GeocodeSuggestion {
  GeocodeSuggestion({
    required this.title,
    required this.address,
    required this.lat,
    required this.lng,
  });

  final String title;
  final String address;
  final double lat;
  final double lng;
}

class AddressPicker extends StatefulWidget {
  const AddressPicker({
    super.key,
    this.initialAddress,
    required this.onAddressChanged,
    this.onLocationSelected,
    this.enabled = true,
    this.reverseAddress,
  });

  final String? initialAddress;
  final ValueChanged<String> onAddressChanged;
  final void Function(double lat, double lng)? onLocationSelected;
  final bool enabled;
  final String? reverseAddress;

  @override
  State<AddressPicker> createState() => _AddressPickerState();
}

class _AddressPickerState extends State<AddressPicker> {
  static const _defaultCountry = 'Россия';
  static const _yandexGeocoderApiKey = String.fromEnvironment(
    'YANDEX_GEOCODER_API_KEY',
    defaultValue: String.fromEnvironment('YANDEX_MAPS_API_KEY'),
  );

  final _addressController = TextEditingController();
  final _addressFocus = FocusNode();

  List<GeocodeSuggestion> _addressSuggestions = [];
  bool _loadingAddresses = false;
  Timer? _addressDebounce;

  @override
  void initState() {
    super.initState();
    if (widget.initialAddress != null && widget.initialAddress!.isNotEmpty) {
      _addressController.text = widget.initialAddress!;
    }
    _addressController.addListener(_onAddressChanged);
  }

  @override
  void didUpdateWidget(covariant AddressPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.reverseAddress != null &&
        widget.reverseAddress != oldWidget.reverseAddress) {
      _addressController.removeListener(_onAddressChanged);
      _addressController.text = widget.reverseAddress!;
      _addressController.addListener(_onAddressChanged);
      widget.onAddressChanged(widget.reverseAddress!);
      if (mounted) setState(() => _addressSuggestions = []);
    }
  }

  @override
  void dispose() {
    _addressDebounce?.cancel();
    _addressController.dispose();
    _addressFocus.dispose();
    super.dispose();
  }

  Future<List<GeocodeSuggestion>> _search(String query, {int limit = 8}) async {
    if (_yandexGeocoderApiKey.isEmpty) return [];
    final uri = Uri.https('geocode-maps.yandex.ru', '/1.x/', {
      'apikey': _yandexGeocoderApiKey,
      'format': 'json',
      'lang': 'ru_RU',
      'geocode': query,
      'results': '$limit',
    });
    final res = await http.get(uri, headers: {'Accept': 'application/json'});
    if (res.statusCode >= 400) {
      throw Exception('Geocoder request failed: ${res.statusCode}');
    }

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final collection =
        ((data['response'] as Map<String, dynamic>?)?['GeoObjectCollection']
                as Map<String, dynamic>?) ??
            const {};
    final featureMember =
        (collection['featureMember'] as List<dynamic>? ?? const []);

    return featureMember
        .whereType<Map<String, dynamic>>()
        .map((item) => item['GeoObject'])
        .whereType<Map<String, dynamic>>()
        .map((geo) {
          final point = (geo['Point'] as Map<String, dynamic>?) ?? const {};
          final pos = (point['pos'] as String? ?? '').trim();
          final coords = pos.split(RegExp(r'\s+'));
          if (coords.length < 2) return null;
          final lng = double.tryParse(coords[0]);
          final lat = double.tryParse(coords[1]);
          if (lat == null || lng == null) return null;
          final meta = ((geo['metaDataProperty']
                      as Map<String, dynamic>?)?['GeocoderMetaData']
                  as Map<String, dynamic>?) ??
              const {};
          final text = (meta['text'] as String?)?.trim() ?? '';
          final name = (geo['name'] as String?)?.trim() ?? text;
          return GeocodeSuggestion(
            title: name,
            address: text.isNotEmpty ? text : name,
            lat: lat,
            lng: lng,
          );
        })
        .whereType<GeocodeSuggestion>()
        .toList();
  }

  void _onAddressChanged() {
    _addressDebounce?.cancel();
    final text = _addressController.text.trim();
    widget.onAddressChanged(text);

    if (text.length < 2) {
      if (mounted) setState(() => _addressSuggestions = []);
      return;
    }

    _addressDebounce = Timer(const Duration(milliseconds: 320), () async {
      if (!mounted) return;
      setState(() => _loadingAddresses = true);

      try {
        final results = await _search('$_defaultCountry, $text', limit: 8);
        if (!mounted) return;
        setState(() => _addressSuggestions = results);
      } catch (_) {
        if (!mounted) return;
        setState(() => _addressSuggestions = []);
      } finally {
        if (mounted) setState(() => _loadingAddresses = false);
      }
    });
  }

  void _selectAddress(GeocodeSuggestion suggestion) {
    final fullAddress =
        suggestion.address.isNotEmpty ? suggestion.address : suggestion.title;
    _addressController.removeListener(_onAddressChanged);
    _addressController.text = fullAddress;
    _addressController.addListener(_onAddressChanged);
    widget.onAddressChanged(fullAddress);
    widget.onLocationSelected?.call(suggestion.lat, suggestion.lng);
    setState(() => _addressSuggestions = []);
    _addressFocus.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Адрес', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        TextFormField(
          controller: _addressController,
          focusNode: _addressFocus,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          decoration: InputDecoration(
            hintText: 'Город, улица, дом...',
            hintStyle: TextStyle(color: context.appColors.textMuted),
            prefixIcon: const Icon(Icons.location_on_outlined),
            suffixIcon: _loadingAddresses
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : null,
          ),
          enabled: widget.enabled,
          validator: (v) => v == null || v.isEmpty ? 'Укажите адрес' : null,
        ),
        if (_addressSuggestions.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            constraints: const BoxConstraints(maxHeight: 240),
            decoration: BoxDecoration(
              color: context.appColors.surfaceWhite,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: context.appColors.border),
            ),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _addressSuggestions.length,
              itemBuilder: (context, i) {
                final s = _addressSuggestions[i];
                return ListTile(
                  dense: true,
                  title: Text(
                    s.address.isNotEmpty ? s.address : s.title,
                    style: const TextStyle(fontSize: 15),
                  ),
                  onTap: () => _selectAddress(s),
                );
              },
            ),
          ),
        ],
      ],
    );
  }
}
