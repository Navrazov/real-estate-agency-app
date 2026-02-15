import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:real_estate_app/app/theme/app_theme.dart';
import 'package:http/http.dart' as http;

class NominatimResult {
  final String displayName;
  final double lat;
  final double lon;

  NominatimResult({
    required this.displayName,
    required this.lat,
    required this.lon,
  });

  factory NominatimResult.fromJson(Map<String, dynamic> json) {
    return NominatimResult(
      displayName: json['display_name'] as String,
      lat: double.parse(json['lat'] as String),
      lon: double.parse(json['lon'] as String),
    );
  }
}

Future<List<NominatimResult>> _searchNominatim(Map<String, String> params) async {
  final query = {
    'format': 'json',
    'accept-language': 'ru',
    'countrycodes': 'ru',
    'limit': '5',
    ...params,
  };
  final uri = Uri.https('nominatim.openstreetmap.org', '/search', query);
  try {
    final res = await http.get(uri, headers: {'User-Agent': 'RealEstateApp/1.0'});
    if (res.statusCode != 200) return [];
    final list = jsonDecode(res.body) as List<dynamic>;
    return list.map((e) => NominatimResult.fromJson(e as Map<String, dynamic>)).toList();
  } catch (_) {
    return [];
  }
}

String _cleanAddress(String displayName, String city) {
  final parts = displayName.split(',').map((s) => s.trim()).toList();
  return parts.where((p) {
    if (p == city || p == 'Россия' || p == 'Russia') return false;
    if (RegExp(r'^\d{5,6}$').hasMatch(p)) return false;
    if (RegExp(r'район$', caseSensitive: false).hasMatch(p)) return false;
    if (RegExp(r'округ$', caseSensitive: false).hasMatch(p)) return false;
    if (RegExp(r'область$', caseSensitive: false).hasMatch(p)) return false;
    if (RegExp(r'край$', caseSensitive: false).hasMatch(p)) return false;
    if (RegExp(r'республика', caseSensitive: false).hasMatch(p)) return false;
    if (RegExp(r'городской округ', caseSensitive: false).hasMatch(p)) return false;
    if (RegExp(r'муниципальный', caseSensitive: false).hasMatch(p)) return false;
    return true;
  }).join(', ');
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
  final _cityController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityFocus = FocusNode();
  final _addressFocus = FocusNode();

  List<NominatimResult> _citySuggestions = [];
  List<NominatimResult> _addressSuggestions = [];
  bool _cityConfirmed = false;
  String _selectedCity = '';
  bool _loadingCities = false;
  bool _loadingAddresses = false;
  Timer? _cityDebounce;
  Timer? _addressDebounce;

  OverlayEntry? _cityOverlay;
  OverlayEntry? _addressOverlay;
  final _cityKey = GlobalKey();
  final _addressKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    if (widget.initialCity != null && widget.initialCity!.isNotEmpty) {
      _cityController.text = widget.initialCity!;
      _selectedCity = widget.initialCity!;
      _cityConfirmed = true;
    }
    if (widget.initialAddress != null && widget.initialAddress!.isNotEmpty) {
      // Show only the part after city
      final addr = widget.initialAddress!;
      if (_selectedCity.isNotEmpty && addr.startsWith(_selectedCity)) {
        final rest = addr.substring(_selectedCity.length).replaceFirst(RegExp(r'^,\s*'), '');
        _addressController.text = rest;
      } else {
        _addressController.text = addr;
      }
    }
    _cityController.addListener(_onCityChanged);
    _addressController.addListener(_onAddressChanged);
  }

  @override
  void didUpdateWidget(AddressPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.reverseAddress != null &&
        widget.reverseAddress != oldWidget.reverseAddress &&
        _cityConfirmed) {
      final cleaned = widget.reverseAddress!.replaceFirst('$_selectedCity, ', '');
      _addressController.removeListener(_onAddressChanged);
      _addressController.text = cleaned;
      _addressController.addListener(_onAddressChanged);
      widget.onAddressChanged(widget.reverseAddress!);
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
    _hideCityOverlay();
    _hideAddressOverlay();
    super.dispose();
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
      setState(() => _citySuggestions = []);
      _hideCityOverlay();
      return;
    }
    _cityDebounce = Timer(const Duration(milliseconds: 400), () {
      _searchCities(text);
    });
  }

  void _onAddressChanged() {
    _addressDebounce?.cancel();
    final text = _addressController.text.trim();
    if (text.length < 2 || !_cityConfirmed || _selectedCity.isEmpty) {
      setState(() => _addressSuggestions = []);
      _hideAddressOverlay();
      return;
    }
    widget.onAddressChanged('$_selectedCity, $text');
    _addressDebounce = Timer(const Duration(milliseconds: 400), () {
      _searchAddresses(text);
    });
  }

  Future<void> _searchCities(String query) async {
    setState(() => _loadingCities = true);
    final results = await _searchNominatim({'q': query, 'featuretype': 'city'});
    if (!mounted) return;
    setState(() {
      _citySuggestions = results;
      _loadingCities = false;
    });
    if (results.isNotEmpty) {
      _showCityOverlay();
    } else {
      _hideCityOverlay();
    }
  }

  Future<void> _searchAddresses(String query) async {
    setState(() => _loadingAddresses = true);
    final results = await _searchNominatim({'q': '$_selectedCity, $query'});
    if (!mounted) return;
    setState(() {
      _addressSuggestions = results;
      _loadingAddresses = false;
    });
    if (results.isNotEmpty) {
      _showAddressOverlay();
    } else {
      _hideAddressOverlay();
    }
  }

  void _selectCity(NominatimResult result) {
    final parts = result.displayName.split(',');
    final name = parts[0].trim();
    _cityController.removeListener(_onCityChanged);
    _cityController.text = name;
    _cityController.addListener(_onCityChanged);
    _selectedCity = name;
    _cityConfirmed = true;
    _addressController.clear();
    widget.onCityChanged(name);
    widget.onAddressChanged('');
    _hideCityOverlay();
    setState(() => _citySuggestions = []);
    _addressFocus.requestFocus();
  }

  void _selectAddress(NominatimResult result) {
    final clean = _cleanAddress(result.displayName, _selectedCity);
    _addressController.removeListener(_onAddressChanged);
    _addressController.text = clean;
    _addressController.addListener(_onAddressChanged);
    widget.onAddressChanged('$_selectedCity, $clean');
    if (widget.onLocationSelected != null) {
      widget.onLocationSelected!(result.lat, result.lon);
    }
    _hideAddressOverlay();
    setState(() => _addressSuggestions = []);
  }

  void _showCityOverlay() {
    _hideCityOverlay();
    final renderBox = _cityKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final offset = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;
    final surfaceColor = context.appColors.surfaceWhite;
    final borderColor = context.appColors.border;

    _cityOverlay = OverlayEntry(
      builder: (context) => Positioned(
        left: offset.dx,
        top: offset.dy + size.height + 4,
        width: size.width,
        child: Material(
          elevation: 4,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            constraints: const BoxConstraints(maxHeight: 250),
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor),
            ),
            child: ListView.builder(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              itemCount: _citySuggestions.length,
              itemBuilder: (ctx, i) {
                final s = _citySuggestions[i];
                return InkWell(
                  onTap: () => _selectCity(s),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Text(s.displayName, style: const TextStyle(fontSize: 14)),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
    Overlay.of(context).insert(_cityOverlay!);
  }

  void _hideCityOverlay() {
    _cityOverlay?.remove();
    _cityOverlay = null;
  }

  void _showAddressOverlay() {
    _hideAddressOverlay();
    final renderBox = _addressKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final offset = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;
    final surfaceColor = context.appColors.surfaceWhite;
    final borderColor = context.appColors.border;

    _addressOverlay = OverlayEntry(
      builder: (context) => Positioned(
        left: offset.dx,
        top: offset.dy + size.height + 4,
        width: size.width,
        child: Material(
          elevation: 4,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            constraints: const BoxConstraints(maxHeight: 250),
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor),
            ),
            child: ListView.builder(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              itemCount: _addressSuggestions.length,
              itemBuilder: (ctx, i) {
                final s = _addressSuggestions[i];
                final display = _cleanAddress(s.displayName, _selectedCity);
                return InkWell(
                  onTap: () => _selectAddress(s),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Text(display.isNotEmpty ? display : s.displayName, style: const TextStyle(fontSize: 14)),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
    Overlay.of(context).insert(_addressOverlay!);
  }

  void _hideAddressOverlay() {
    _addressOverlay?.remove();
    _addressOverlay = null;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // City
        const Text('Город', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        TextFormField(
          key: _cityKey,
          controller: _cityController,
          focusNode: _cityFocus,
          decoration: InputDecoration(
            hintText: 'Начните вводить город...',
            prefixIcon: const Icon(Icons.location_city),
            suffixIcon: _loadingCities
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                  )
                : _cityConfirmed
                    ? Icon(Icons.check_circle, color: context.appColors.success)
                    : null,
          ),
          enabled: widget.enabled,
          validator: (v) => v == null || v.isEmpty ? 'Выберите город' : null,
        ),
        const SizedBox(height: 16),

        // Address
        const Text('Адрес', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        TextFormField(
          key: _addressKey,
          controller: _addressController,
          focusNode: _addressFocus,
          decoration: InputDecoration(
            hintText: _cityConfirmed ? 'Улица, дом...' : 'Сначала выберите город',
            prefixIcon: const Icon(Icons.location_on_outlined),
            suffixIcon: _loadingAddresses
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                  )
                : null,
          ),
          enabled: widget.enabled && _cityConfirmed,
          validator: (v) => v == null || v.isEmpty ? 'Укажите адрес' : null,
        ),
      ],
    );
  }
}
