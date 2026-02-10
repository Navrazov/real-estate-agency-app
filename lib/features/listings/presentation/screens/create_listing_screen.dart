import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:real_estate_app/app/theme/app_theme.dart';
import '../../../../core/widgets/location_picker_map.dart';
import '../../../../core/widgets/address_picker.dart';
import '../../data/listings_repository.dart';
import '../../domain/listing.dart';

String _formatNumber(String value) {
  final digits = value.replaceAll(RegExp(r'[^\d]'), '');
  if (digits.isEmpty) return '';
  final num = int.tryParse(digits);
  if (num == null) return digits;
  return num.toString().replaceAllMapped(
    RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
    (m) => '${m[1]} ',
  );
}

class _PriceInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'[^\d]'), '');
    final formatted = _formatNumber(digits);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class CreateListingScreen extends StatefulWidget {
  const CreateListingScreen({super.key});

  @override
  State<CreateListingScreen> createState() => _CreateListingScreenState();
}

class _CreateListingScreenState extends State<CreateListingScreen> {
  final _repo = ListingsRepository();
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  // _addressCtrl removed — using AddressPicker instead
  final _roomsCtrl = TextEditingController();
  final _areaCtrl = TextEditingController();
  final _floorCtrl = TextEditingController();
  final _totalFloorsCtrl = TextEditingController();
  final _installmentMonthsCtrl = TextEditingController();
  final _installmentMonthlyCtrl = TextEditingController();
  final _picker = ImagePicker();

  PropertyType _propertyType = PropertyType.apartment;
  PaymentType _paymentType = PaymentType.cash;
  final List<String> _imageUrls = [];
  String _city = '';
  String _address = '';
  double? _lat;
  double? _lng;
  bool _loading = false;
  bool _uploading = false;
  String? _error;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _priceCtrl.dispose();
    // _addressCtrl removed
    _roomsCtrl.dispose();
    _areaCtrl.dispose();
    _floorCtrl.dispose();
    _totalFloorsCtrl.dispose();
    _installmentMonthsCtrl.dispose();
    _installmentMonthlyCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final files = await _picker.pickMultiImage();
    if (files.isEmpty) return;

    setState(() {
      _error = null;
      _uploading = true;
    });

    try {
      final urls = await _repo.uploadImages(files.map((f) => File(f.path)).toList());
      setState(() => _imageUrls.addAll(urls));
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _uploading = false);
    }
  }

  void _removeImage(int index) {
    setState(() => _imageUrls.removeAt(index));
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final priceStr = _priceCtrl.text.replaceAll(RegExp(r'[^\d]'), '');
    final price = double.tryParse(priceStr);
    if (price == null || price < 0) {
      setState(() => _error = 'Укажите корректную цену');
      return;
    }

    if (_paymentType == PaymentType.installment) {
      final months = int.tryParse(_installmentMonthsCtrl.text);
      final monthlyStr = _installmentMonthlyCtrl.text.replaceAll(RegExp(r'[^\d]'), '');
      final monthly = double.tryParse(monthlyStr);
      if (months == null || months < 1) {
        setState(() => _error = 'Укажите срок рассрочки');
        return;
      }
      if (monthly == null || monthly < 1) {
        setState(() => _error = 'Укажите ежемесячный платёж');
        return;
      }
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final monthlyStr = _installmentMonthlyCtrl.text.replaceAll(RegExp(r'[^\d]'), '');
      final listing = await _repo.create(
        title: _titleCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        price: price,
        paymentType: _paymentType,
        installmentMonths: _paymentType == PaymentType.installment
            ? int.tryParse(_installmentMonthsCtrl.text)
            : null,
        installmentMonthly: _paymentType == PaymentType.installment
            ? double.tryParse(monthlyStr)
            : null,
        address: _address,
        propertyType: _propertyType,
        rooms: _roomsCtrl.text.isNotEmpty ? int.tryParse(_roomsCtrl.text) : null,
        area: _areaCtrl.text.isNotEmpty ? double.tryParse(_areaCtrl.text) : null,
        floor: _floorCtrl.text.isNotEmpty ? int.tryParse(_floorCtrl.text) : null,
        totalFloors: _totalFloorsCtrl.text.isNotEmpty ? int.tryParse(_totalFloorsCtrl.text) : null,
        images: _imageUrls.isEmpty ? null : _imageUrls,
        lat: _lat,
        lng: _lng,
      );
      if (mounted) {
        context.go('/listing/${listing.id}');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Объявление опубликовано!')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Новое объявление'),
        actions: [
          TextButton(
            onPressed: _loading ? null : _submit,
            child: _loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Опубликовать'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_error != null)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.error.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: AppColors.error),
                    const SizedBox(width: 12),
                    Expanded(child: Text(_error!, style: const TextStyle(color: AppColors.error))),
                  ],
                ),
              ),

            // Photos
            const Text('Фотографии', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _uploading ? null : _pickImages,
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.border, width: 2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.add_photo_alternate_outlined,
                      size: 48,
                      color: _uploading ? AppColors.textMuted : AppColors.primary,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _uploading ? 'Загрузка...' : 'Добавить фото',
                      style: TextStyle(
                        color: _uploading ? AppColors.textMuted : AppColors.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_imageUrls.isNotEmpty) ...[
              const SizedBox(height: 12),
              SizedBox(
                height: 100,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _imageUrls.length,
                  itemBuilder: (context, i) {
                    return Stack(
                      children: [
                        Container(
                          width: 100,
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            image: DecorationImage(
                              image: NetworkImage(_imageUrls[i]),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        Positioned(
                          top: 4,
                          right: 12,
                          child: GestureDetector(
                            onTap: () => _removeImage(i),
                            child: Container(
                              width: 24,
                              height: 24,
                              decoration: const BoxDecoration(
                                color: AppColors.error,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.close, size: 16, color: Colors.white),
                            ),
                          ),
                        ),
                        if (i == 0)
                          Positioned(
                            bottom: 4,
                            left: 4,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'Главное',
                                style: TextStyle(color: Colors.white, fontSize: 10),
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ],
            const SizedBox(height: 24),

            // Property Type
            const Text('Тип недвижимости', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: PropertyType.values.map((type) {
                final selected = _propertyType == type;
                return ChoiceChip(
                  label: Text('${type.icon} ${type.label}'),
                  selected: selected,
                  onSelected: (_) => setState(() => _propertyType = type),
                  selectedColor: AppColors.primary.withOpacity(0.2),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            // Title
            TextFormField(
              controller: _titleCtrl,
              decoration: const InputDecoration(
                labelText: 'Заголовок',
                hintText: 'Например: Уютная 2-комнатная квартира',
              ),
              textCapitalization: TextCapitalization.sentences,
              enabled: !_loading,
              validator: (v) => v == null || v.isEmpty ? 'Обязательное поле' : null,
            ),
            const SizedBox(height: 16),

            // Description
            TextFormField(
              controller: _descCtrl,
              decoration: const InputDecoration(
                labelText: 'Описание',
                hintText: 'Опишите особенности объекта...',
              ),
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              enabled: !_loading,
              validator: (v) => v == null || v.isEmpty ? 'Обязательное поле' : null,
            ),
            const SizedBox(height: 16),

            // Price with formatting
            const Text('Стоимость и оплата', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
            const SizedBox(height: 12),
            TextFormField(
              controller: _priceCtrl,
              decoration: const InputDecoration(
                labelText: 'Цена, ₽',
                prefixIcon: Icon(Icons.attach_money),
                hintText: '5 000 000',
                suffixText: '₽',
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [_PriceInputFormatter()],
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              enabled: !_loading,
              validator: (v) {
                if (v == null || v.isEmpty) return 'Обязательное поле';
                final digits = v.replaceAll(RegExp(r'[^\d]'), '');
                if (double.tryParse(digits) == null) return 'Некорректное число';
                return null;
              },
            ),
            Builder(builder: (context) {
              final digits = _priceCtrl.text.replaceAll(RegExp(r'[^\d]'), '');
              if (digits.isEmpty) return const SizedBox.shrink();
              final num = int.tryParse(digits);
              if (num == null) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(top: 4, left: 16),
                child: Text(
                  '${_formatNumber(digits)} ₽',
                  style: TextStyle(fontSize: 13, color: AppColors.primary, fontWeight: FontWeight.w500),
                ),
              );
            }),
            const SizedBox(height: 16),

            // Payment Type
            const Text('Способ оплаты', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Row(
              children: PaymentType.values.map((type) {
                final selected = _paymentType == type;
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: type == PaymentType.cash ? 8 : 0, left: type == PaymentType.installment ? 8 : 0),
                    child: GestureDetector(
                      onTap: () => setState(() => _paymentType = type),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: selected ? AppColors.primary : Colors.grey.shade300,
                            width: selected ? 2 : 1,
                          ),
                          color: selected ? AppColors.primary.withAlpha(20) : Colors.white,
                        ),
                        child: Column(
                          children: [
                            Text(type.icon, style: const TextStyle(fontSize: 24)),
                            const SizedBox(height: 4),
                            Text(
                              type.label,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: selected ? AppColors.primary : AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Installment Details
            if (_paymentType == PaymentType.installment) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  border: Border.all(color: Colors.amber.shade200),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, size: 18, color: Colors.amber.shade700),
                        const SizedBox(width: 8),
                        Text('Условия рассрочки', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.amber.shade800)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _installmentMonthsCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Срок, мес.',
                              hintText: '12',
                              prefixIcon: Icon(Icons.calendar_month),
                            ),
                            keyboardType: TextInputType.number,
                            enabled: !_loading,
                            validator: _paymentType == PaymentType.installment
                                ? (v) => v == null || v.isEmpty ? 'Обязательно' : null
                                : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _installmentMonthlyCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Платёж/мес, ₽',
                              hintText: '50 000',
                              prefixIcon: Icon(Icons.payments_outlined),
                              suffixText: '₽',
                            ),
                            keyboardType: TextInputType.number,
                            inputFormatters: [_PriceInputFormatter()],
                            enabled: !_loading,
                            validator: _paymentType == PaymentType.installment
                                ? (v) => v == null || v.isEmpty ? 'Обязательно' : null
                                : null,
                          ),
                        ),
                      ],
                    ),
                    Builder(builder: (context) {
                      final months = int.tryParse(_installmentMonthsCtrl.text);
                      final monthlyDigits = _installmentMonthlyCtrl.text.replaceAll(RegExp(r'[^\d]'), '');
                      final monthly = double.tryParse(monthlyDigits);
                      if (months == null || monthly == null || months < 1 || monthly < 1) {
                        return const SizedBox.shrink();
                      }
                      final total = (months * monthly).round();
                      return Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Итого за рассрочку: ${_formatNumber(total.toString())} ₽ ($months мес × ${_formatNumber(monthlyDigits)} ₽)',
                            style: TextStyle(fontSize: 13, color: Colors.amber.shade900, fontWeight: FontWeight.w500),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Rooms & Area
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _roomsCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Комнат',
                      prefixIcon: Icon(Icons.bed_outlined),
                    ),
                    keyboardType: TextInputType.number,
                    enabled: !_loading,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _areaCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Площадь, м²',
                      prefixIcon: Icon(Icons.square_foot),
                    ),
                    keyboardType: TextInputType.number,
                    enabled: !_loading,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Floor
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _floorCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Этаж',
                      prefixIcon: Icon(Icons.stairs),
                    ),
                    keyboardType: TextInputType.number,
                    enabled: !_loading,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _totalFloorsCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Этажей всего',
                      prefixIcon: Icon(Icons.apartment),
                    ),
                    keyboardType: TextInputType.number,
                    enabled: !_loading,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Address
            AddressPicker(
              enabled: !_loading,
              onCityChanged: (city) => setState(() => _city = city),
              onAddressChanged: (addr) => setState(() => _address = addr),
              onLocationSelected: (lat, lng) {
                _lat = lat;
                _lng = lng;
              },
            ),
            const SizedBox(height: 24),

            // Map
            const Text('Местоположение на карте', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            const Text(
              'Нажмите на карту или перетащите маркер',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                height: 250,
                child: LocationPickerMap(
                  initialLat: _lat,
                  initialLng: _lng,
                  onLocationChanged: (lat, lng) {
                    _lat = lat;
                    _lng = lng;
                  },
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Submit
            ElevatedButton(
              onPressed: _loading ? null : _submit,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(56),
              ),
              child: _loading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Опубликовать'),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
