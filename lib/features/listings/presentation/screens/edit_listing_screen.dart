import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:real_estate_app/app/theme/app_theme.dart';
import 'package:real_estate_app/core/auth/auth_service.dart';
import 'package:real_estate_app/core/widgets/location_picker_map.dart';
import 'package:real_estate_app/core/widgets/address_picker.dart';
import 'package:real_estate_app/core/widgets/skeleton.dart';
import 'package:real_estate_app/features/listings/data/listings_repository.dart';
import 'package:real_estate_app/features/listings/domain/listing.dart';

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

class EditListingScreen extends StatefulWidget {
  const EditListingScreen({super.key, required this.listingId});

  final String listingId;

  @override
  State<EditListingScreen> createState() => _EditListingScreenState();
}

class _EditListingScreenState extends State<EditListingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _repo = ListingsRepository();
  final _picker = ImagePicker();

  Listing? _listing;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  // _addressController removed — using AddressPicker
  final _roomsController = TextEditingController();
  final _areaController = TextEditingController();
  final _floorController = TextEditingController();
  final _totalFloorsController = TextEditingController();
  final _installmentMonthsController = TextEditingController();
  final _installmentMonthlyController = TextEditingController();
  final _developerController = TextEditingController();
  final _complexController = TextEditingController();

  PropertyType _propertyType = PropertyType.apartment;
  ApartmentType? _apartmentType;
  ListingStatus _status = ListingStatus.active;
  PaymentType _paymentType = PaymentType.cash;
  List<String> _images = [];
  String _city = '';
  String _address = '';
  double? _lat;
  double? _lng;
  String? _reverseAddress;

  @override
  void initState() {
    super.initState();
    _loadListing();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    // _addressController removed
    _roomsController.dispose();
    _areaController.dispose();
    _floorController.dispose();
    _totalFloorsController.dispose();
    _installmentMonthsController.dispose();
    _installmentMonthlyController.dispose();
    _developerController.dispose();
    _complexController.dispose();
    super.dispose();
  }

  Future<void> _loadListing() async {
    try {
      final listing = await _repo.getById(widget.listingId);
      setState(() {
        _listing = listing;
        _titleController.text = listing.title;
        _descriptionController.text = listing.description;
        _priceController.text = _formatNumber(listing.price.toStringAsFixed(0));
        _address = listing.address;
        // Extract city from address (first part before comma)
        final addrParts = listing.address.split(',').map((s) => s.trim()).toList();
        if (addrParts.length > 1) {
          _city = addrParts[0];
        }
        _roomsController.text = listing.rooms?.toString() ?? '';
        _areaController.text = listing.area?.toStringAsFixed(0) ?? '';
        _floorController.text = listing.floor?.toString() ?? '';
        _totalFloorsController.text = listing.totalFloors?.toString() ?? '';
        _propertyType = listing.propertyType;
        _status = listing.status;
        _paymentType = listing.paymentType;
        if (listing.installmentMonths != null) {
          _installmentMonthsController.text = listing.installmentMonths.toString();
        }
        if (listing.installmentMonthly != null) {
          _installmentMonthlyController.text = _formatNumber(listing.installmentMonthly!.toStringAsFixed(0));
        }
        _images = List.from(listing.images);
        _apartmentType = listing.apartmentType;
        _developerController.text = listing.developer ?? '';
        _complexController.text = listing.complex ?? '';
        _lat = listing.lat;
        _lng = listing.lng;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _pickImages() async {
    final files = await _picker.pickMultiImage();
    if (files.isEmpty) return;
    setState(() => _error = null);
    try {
      final urls = await _repo.uploadImages(files);
      setState(() => _images.addAll(urls));
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  void _removeImage(int index) {
    setState(() => _images.removeAt(index));
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    if (_images.isEmpty) {
      setState(() => _error = 'Добавьте хотя бы одну фотографию');
      return;
    }

    final priceDigits = _priceController.text.replaceAll(RegExp(r'[^\d]'), '');
    final price = double.tryParse(priceDigits);
    if (price == null || price < 0) {
      setState(() => _error = 'Укажите корректную цену');
      return;
    }

    if (_paymentType == PaymentType.installment) {
      final months = int.tryParse(_installmentMonthsController.text);
      final monthlyDigits = _installmentMonthlyController.text.replaceAll(RegExp(r'[^\d]'), '');
      final monthly = double.tryParse(monthlyDigits);
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
      _saving = true;
      _error = null;
    });

    try {
      final monthlyDigits = _installmentMonthlyController.text.replaceAll(RegExp(r'[^\d]'), '');
      await _repo.update(
        widget.listingId,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        price: price,
        paymentType: _paymentType,
        installmentMonths: _paymentType == PaymentType.installment
            ? int.tryParse(_installmentMonthsController.text)
            : null,
        installmentMonthly: _paymentType == PaymentType.installment
            ? double.tryParse(monthlyDigits)
            : null,
        address: _address,
        propertyType: _propertyType,
        apartmentType: _propertyType == PropertyType.apartment ? _apartmentType : null,
        developer: _propertyType == PropertyType.apartment ? _developerController.text.trim() : null,
        complex: _propertyType == PropertyType.apartment ? _complexController.text.trim() : null,
        status: _status,
        rooms: _roomsController.text.isNotEmpty ? int.parse(_roomsController.text) : null,
        area: _areaController.text.isNotEmpty ? double.parse(_areaController.text) : null,
        floor: _floorController.text.isNotEmpty ? int.parse(_floorController.text) : null,
        totalFloors: _totalFloorsController.text.isNotEmpty ? int.parse(_totalFloorsController.text) : null,
        images: _images,
        lat: _lat,
        lng: _lng,
      );
      if (mounted) {
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Изменения сохранены')),
        );
      }
    } catch (e) {
      setState(() {
        _saving = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = AuthServiceScope.of(context);
    final isAdmin = auth.user?.isAdmin ?? false;

    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Редактирование')),
        body: const SkeletonEditListing(),
      );
    }

    if (_error != null && _listing == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Ошибка')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, style: TextStyle(color: context.appColors.error)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => context.pop(),
                child: const Text('Назад'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Редактирование'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Сохранить'),
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
                  color: context.appColors.error.withAlpha(25),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: context.appColors.error.withAlpha(76)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: context.appColors.error),
                    const SizedBox(width: 12),
                    Expanded(child: Text(_error!, style: TextStyle(color: context.appColors.error))),
                  ],
                ),
              ),

            // Photos
            Row(
              children: [
                const Text('Фотографии', style: TextStyle(fontWeight: FontWeight.w600)),
                Text(' *', style: TextStyle(color: context.appColors.error, fontWeight: FontWeight.w600)),
                const SizedBox(width: 8),
                Text('Минимум 1 фото', style: TextStyle(fontSize: 12, color: context.appColors.textMuted)),
              ],
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _pickImages,
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  border: Border.all(color: context.appColors.border, width: 2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Icon(Icons.add_photo_alternate_outlined, size: 48, color: context.appColors.textMuted),
                    const SizedBox(height: 8),
                    Text('Добавить фото', style: TextStyle(color: context.appColors.primary, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            ),
            if (_images.isNotEmpty) ...[
              const SizedBox(height: 12),
              SizedBox(
                height: 100,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _images.length,
                  itemBuilder: (context, index) {
                    return Stack(
                      children: [
                        Container(
                          width: 100,
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            image: DecorationImage(image: NetworkImage(_images[index]), fit: BoxFit.cover),
                          ),
                        ),
                        Positioned(
                          top: 4,
                          right: 12,
                          child: GestureDetector(
                            onTap: () => _removeImage(index),
                            child: Container(
                              width: 24, height: 24,
                              decoration: BoxDecoration(color: context.appColors.error, shape: BoxShape.circle),
                              child: const Icon(Icons.close, size: 16, color: Colors.white),
                            ),
                          ),
                        ),
                        if (index == 0)
                          Positioned(
                            bottom: 4, left: 4,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: context.appColors.primary, borderRadius: BorderRadius.circular(4)),
                              child: const Text('Главное', style: TextStyle(color: Colors.white, fontSize: 10)),
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
                  selectedColor: context.appColors.primary.withAlpha(51),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            // Apartment Type (only for apartments)
            if (_propertyType == PropertyType.apartment) ...[
              const Text('Тип квартиры', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: ApartmentType.values.map((type) {
                  final selected = _apartmentType == type;
                  return ChoiceChip(
                    label: Text('${type.icon} ${type.label}'),
                    selected: selected,
                    onSelected: (_) => setState(() => _apartmentType = type),
                    selectedColor: context.appColors.primary.withAlpha(51),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _developerController,
                decoration: const InputDecoration(labelText: 'Застройщик'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _complexController,
                decoration: const InputDecoration(labelText: 'Жилой комплекс'),
              ),
              const SizedBox(height: 24),
            ],

            // Status (Admin only)
            if (isAdmin) ...[
              const Text('Статус', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Builder(builder: (context) {
                final statusValues = _listing?.moderationStatus == ModerationStatus.approved
                    ? ListingStatus.values.where((s) => s != ListingStatus.pending).toList()
                    : ListingStatus.values;
                return Wrap(
                  spacing: 8,
                  children: statusValues.map((s) {
                    final selected = _status == s;
                    return ChoiceChip(
                      label: Text(s.label),
                      selected: selected,
                      onSelected: (_) => setState(() => _status = s),
                      selectedColor: context.appColors.primary.withAlpha(51),
                    );
                  }).toList(),
                );
              }),
              const SizedBox(height: 24),
            ],

            // Title
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Заголовок'),
              validator: (v) => v == null || v.isEmpty ? 'Обязательное поле' : null,
            ),
            const SizedBox(height: 16),

            // Description
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(labelText: 'Описание'),
              maxLines: 4,
              validator: (v) => v == null || v.isEmpty ? 'Обязательное поле' : null,
            ),
            const SizedBox(height: 24),

            // Price & Payment
            const Text('Стоимость и оплата', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
            const SizedBox(height: 12),
            TextFormField(
              controller: _priceController,
              decoration: InputDecoration(
                labelText: _paymentType == PaymentType.installment ? 'Первый взнос, ₽' : 'Цена, ₽',
                prefixIcon: const Icon(Icons.attach_money),
                suffixText: '₽',
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [_PriceInputFormatter()],
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Обязательное поле';
                final digits = v.replaceAll(RegExp(r'[^\d]'), '');
                if (double.tryParse(digits) == null) return 'Некорректное число';
                return null;
              },
            ),
            Builder(builder: (context) {
              final digits = _priceController.text.replaceAll(RegExp(r'[^\d]'), '');
              if (digits.isEmpty) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(top: 4, left: 16),
                child: Text('${_formatNumber(digits)} ₽', style: TextStyle(fontSize: 13, color: context.appColors.primary, fontWeight: FontWeight.w500)),
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
                    padding: EdgeInsets.only(
                      right: type == PaymentType.cash ? 8 : 0,
                      left: type == PaymentType.installment ? 8 : 0,
                    ),
                    child: GestureDetector(
                      onTap: () => setState(() => _paymentType = type),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: selected ? context.appColors.primary : context.appColors.border,
                            width: selected ? 2 : 1,
                          ),
                          color: selected ? context.appColors.primary.withAlpha(20) : context.appColors.surfaceWhite,
                        ),
                        child: Column(
                          children: [
                            Text(type.icon, style: const TextStyle(fontSize: 24)),
                            const SizedBox(height: 4),
                            Text(type.label, style: TextStyle(fontWeight: FontWeight.w600, color: selected ? context.appColors.primary : context.appColors.textSecondary)),
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
                  color: context.appColors.accent.withValues(alpha: 0.1),
                  border: Border.all(color: context.appColors.accent.withValues(alpha: 0.3)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, size: 18, color: context.appColors.accent),
                        const SizedBox(width: 8),
                        Text('Условия рассрочки', style: TextStyle(fontWeight: FontWeight.w600, color: context.appColors.accent)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _installmentMonthsController,
                            decoration: const InputDecoration(labelText: 'Срок, мес.', hintText: '12', prefixIcon: Icon(Icons.calendar_month)),
                            keyboardType: TextInputType.number,
                            validator: _paymentType == PaymentType.installment ? (v) => v == null || v.isEmpty ? 'Обязательно' : null : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _installmentMonthlyController,
                            decoration: const InputDecoration(labelText: 'Платёж/мес, ₽', hintText: '50 000', prefixIcon: Icon(Icons.payments_outlined), suffixText: '₽'),
                            keyboardType: TextInputType.number,
                            inputFormatters: [_PriceInputFormatter()],
                            validator: _paymentType == PaymentType.installment ? (v) => v == null || v.isEmpty ? 'Обязательно' : null : null,
                          ),
                        ),
                      ],
                    ),
                    Builder(builder: (context) {
                      final months = int.tryParse(_installmentMonthsController.text);
                      final monthlyDigits = _installmentMonthlyController.text.replaceAll(RegExp(r'[^\d]'), '');
                      final monthly = double.tryParse(monthlyDigits);
                      if (months == null || monthly == null || months < 1 || monthly < 1) return const SizedBox.shrink();
                      final total = (months * monthly).round();
                      return Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(color: context.appColors.accent.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                          child: Text(
                            'Итого за рассрочку: ${_formatNumber(total.toString())} ₽ ($months мес × ${_formatNumber(monthlyDigits)} ₽)',
                            style: TextStyle(fontSize: 13, color: context.appColors.accent, fontWeight: FontWeight.w500),
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
                    controller: _roomsController,
                    decoration: const InputDecoration(labelText: 'Комнат'),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _areaController,
                    decoration: const InputDecoration(labelText: 'Площадь, м²'),
                    keyboardType: TextInputType.number,
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
                    controller: _floorController,
                    decoration: const InputDecoration(labelText: 'Этаж'),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _totalFloorsController,
                    decoration: const InputDecoration(labelText: 'Этажей всего'),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Address
            AddressPicker(
              initialCity: _city,
              initialAddress: _address,
              enabled: !_saving,
              reverseAddress: _reverseAddress,
              onCityChanged: (city) => setState(() => _city = city),
              onAddressChanged: (addr) => setState(() => _address = addr),
              onLocationSelected: (lat, lng) {
                _lat = lat;
                _lng = lng;
              },
            ),
            const SizedBox(height: 24),

            // Map
            const Text('Местоположение', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(
              'Нажмите на карту — адрес заполнится автоматически',
              style: TextStyle(color: context.appColors.textMuted, fontSize: 12),
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
                  onReverseGeocode: (address) {
                    setState(() {
                      _reverseAddress = address;
                      _address = address;
                      final parts = address.split(', ');
                      if (parts.isNotEmpty && _city.isEmpty) {
                        _city = parts[0];
                      }
                    });
                  },
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Save Button
            ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(56)),
              child: _saving
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Сохранить изменения'),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
