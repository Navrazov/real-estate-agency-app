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

  factory GeocodeSuggestion.fromJson(Map<String, dynamic> json) {
    return GeocodeSuggestion(
      title: (json['title'] as String?) ?? '',
      address: (json['address'] as String?) ?? '',
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
    );
  }
}

String _extractCity(String address) {
  final parts = address
      .split(',')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();
  if (parts.isEmpty) return '';
  final cityPart = parts.firstWhere(
    (p) => RegExp(r'(г\.?\s|город\s)', caseSensitive: false).hasMatch(p),
    orElse: () => parts.first,
  );
  return cityPart
      .replaceFirst(RegExp(r'^г\.?\s*', caseSensitive: false), '')
      .replaceFirst(RegExp(r'^город\s*', caseSensitive: false), '')
      .trim();
}

String _withoutCity(String fullAddress, String city) {
  if (fullAddress.isEmpty) return '';
  if (city.isEmpty) return fullAddress.trim();
  final cityRegex =
      RegExp('(^$city[,\\s]*)|(^г\\.?\\s*$city[,\\s]*)', caseSensitive: false);
  return fullAddress
      .trim()
      .replaceFirst(cityRegex, '')
      .replaceFirst(RegExp(r'^,\s*'), '')
      .trim();
}

class AddressPicker extends StatefulWidget {
  const AddressPicker({
    super.key,
    this.initialCity,
    this.initialAddress,
    required this.onCityChanged,
    required this.onAddressChanged,
    this.onLocationSelected,
    this.enabled = true,
    this.reverseAddress,
  });

  final String? initialCity;
  final String? initialAddress;
  final ValueChanged<String> onCityChanged;
  final ValueChanged<String> onAddressChanged;
  final void Function(double lat, double lng)? onLocationSelected;
  final bool enabled;
  final String? reverseAddress;

  @override
  State<AddressPicker> createState() => _AddressPickerState();
}

class _AddressPickerState extends State<AddressPicker> {
  static const _yandexGeocoderApiKey = String.fromEnvironment(
    'YANDEX_GEOCODER_API_KEY',
    defaultValue: String.fromEnvironment('YANDEX_MAPS_API_KEY'),
  );

  final _cityController = TextEditingController();
  final _addressController = TextEditingController();

  final _cityFocus = FocusNode();
  final _addressFocus = FocusNode();

  List<GeocodeSuggestion> _citySuggestions = [];
  List<GeocodeSuggestion> _addressSuggestions = [];

  bool _cityConfirmed = false;
  String _selectedCity = '';
  bool _loadingCities = false;
  bool _loadingAddresses = false;

  Timer? _cityDebounce;
  Timer? _addressDebounce;

  @override
  void initState() {
    super.initState();

    if (widget.initialCity != null && widget.initialCity!.isNotEmpty) {
      _cityController.text = widget.initialCity!;
      _selectedCity = widget.initialCity!;
      _cityConfirmed = true;
    }

    if (widget.initialAddress != null && widget.initialAddress!.isNotEmpty) {
      _addressController.text =
          _withoutCity(widget.initialAddress!, _selectedCity);
    }

    _cityController.addListener(_onCityChanged);
    _addressController.addListener(_onAddressChanged);
  }

  @override
  void didUpdateWidget(covariant AddressPicker oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.reverseAddress != null &&
        widget.reverseAddress != oldWidget.reverseAddress) {
      final city = _extractCity(widget.reverseAddress!);
      final street = _withoutCity(widget.reverseAddress!, city);

      _cityController.removeListener(_onCityChanged);
      _cityController.text = city;
      _cityController.addListener(_onCityChanged);

      _addressController.removeListener(_onAddressChanged);
      _addressController.text = street;
      _addressController.addListener(_onAddressChanged);

      _selectedCity = city;
      _cityConfirmed = city.isNotEmpty;

      widget.onCityChanged(city);
      widget.onAddressChanged(widget.reverseAddress!);

      if (mounted) {
        setState(() {
          _citySuggestions = [];
          _addressSuggestions = [];
        });
      }
    }
  }

  @override
  void dispose() {
    _cityDebounce?.cancel();
    _addressDebounce?.cancel();
    _cityController.dispose();
    _addressController.dispose();
    _cityFocus.dispose();
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

  void _onCityChanged() {
    if (_cityConfirmed) {
      _cityConfirmed = false;
      _selectedCity = '';
      _addressController.clear();
      widget.onCityChanged('');
      widget.onAddressChanged('');
    }

    _cityDebounce?.cancel();
    final text = _cityController.text.trim();

    if (text.length < 2) {
      if (mounted) setState(() => _citySuggestions = []);
      return;
    }

    _cityDebounce = Timer(const Duration(milliseconds: 320), () async {
      if (!mounted) return;
      setState(() => _loadingCities = true);

      try {
        final results = await _search(text, limit: 8);
        if (!mounted) return;
        setState(() => _citySuggestions = results);
      } catch (_) {
        if (!mounted) return;
        setState(() => _citySuggestions = []);
      } finally {
        if (mounted) setState(() => _loadingCities = false);
      }
    });
  }

  void _onAddressChanged() {
    _addressDebounce?.cancel();
    final text = _addressController.text.trim();

    if (text.length < 2 || !_cityConfirmed || _selectedCity.isEmpty) {
      if (mounted) setState(() => _addressSuggestions = []);
      return;
    }

    widget.onAddressChanged('$_selectedCity, $text');

    _addressDebounce = Timer(const Duration(milliseconds: 320), () async {
      if (!mounted) return;
      setState(() => _loadingAddresses = true);

      try {
        final results = await _search('$_selectedCity, $text', limit: 8);
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

  void _selectCity(GeocodeSuggestion suggestion) {
    final city = _extractCity(
        suggestion.address.isNotEmpty ? suggestion.address : suggestion.title);

    _cityController.removeListener(_onCityChanged);
    _cityController.text = city;
    _cityController.addListener(_onCityChanged);

    _selectedCity = city;
    _cityConfirmed = city.isNotEmpty;

    _addressController.removeListener(_onAddressChanged);
    _addressController.clear();
    _addressController.addListener(_onAddressChanged);

    widget.onCityChanged(city);
    widget.onAddressChanged('');

    setState(() {
      _citySuggestions = [];
      _addressSuggestions = [];
    });

    _addressFocus.requestFocus();
  }

  void _selectAddress(GeocodeSuggestion suggestion) {
    final city = _extractCity(suggestion.address);
    final street = _withoutCity(suggestion.address, city);

    if (city.isNotEmpty && city != _selectedCity) {
      _cityController.removeListener(_onCityChanged);
      _cityController.text = city;
      _cityController.addListener(_onCityChanged);
      _selectedCity = city;
      _cityConfirmed = true;
      widget.onCityChanged(city);
    }

    _addressController.removeListener(_onAddressChanged);
    _addressController.text = street;
    _addressController.addListener(_onAddressChanged);

    final fullAddress = suggestion.address.isNotEmpty
        ? suggestion.address
        : '$_selectedCity, $street';
    widget.onAddressChanged(fullAddress);
    widget.onLocationSelected?.call(suggestion.lat, suggestion.lng);

    setState(() => _addressSuggestions = []);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Город', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        TextFormField(
          controller: _cityController,
          focusNode: _cityFocus,
          decoration: InputDecoration(
            hintText: 'Начните вводить город...',
            prefixIcon: const Icon(Icons.location_city),
            suffixIcon: _loadingCities
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2)),
                  )
                : _cityConfirmed
                    ? Icon(Icons.check_circle, color: context.appColors.success)
                    : null,
          ),
          enabled: widget.enabled,
          validator: (v) => v == null || v.isEmpty ? 'Выберите город' : null,
        ),
        if (_citySuggestions.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            constraints: const BoxConstraints(maxHeight: 220),
            decoration: BoxDecoration(
              color: context.appColors.surfaceWhite,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: context.appColors.border),
            ),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _citySuggestions.length,
              itemBuilder: (context, i) {
                final s = _citySuggestions[i];
                return ListTile(
                  dense: true,
                  title: Text(s.address.isNotEmpty ? s.address : s.title,
                      style: const TextStyle(fontSize: 14)),
                  onTap: () => _selectCity(s),
                );
              },
            ),
          ),
        ],
        const SizedBox(height: 16),
        const Text('Адрес', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        TextFormField(
          controller: _addressController,
          focusNode: _addressFocus,
          decoration: InputDecoration(
            hintText:
                _cityConfirmed ? 'Улица, дом...' : 'Сначала выберите город',
            prefixIcon: const Icon(Icons.location_on_outlined),
            suffixIcon: _loadingAddresses
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2)),
                  )
                : null,
          ),
          enabled: widget.enabled && _cityConfirmed,
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
                final city = _extractCity(s.address);
                final display = _withoutCity(s.address, city);
                return ListTile(
                  dense: true,
                  title: Text(
                      display.isNotEmpty
                          ? display
                          : (s.address.isNotEmpty ? s.address : s.title),
                      style: const TextStyle(fontSize: 14)),
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
