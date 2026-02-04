import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:real_estate_app/app/theme/app_theme.dart';
import 'package:real_estate_app/core/auth/auth_service.dart';
import 'package:real_estate_app/core/widgets/location_picker_map.dart';
import 'package:real_estate_app/features/listings/data/listings_repository.dart';
import 'package:real_estate_app/features/listings/domain/listing.dart';

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
  final _addressController = TextEditingController();
  final _roomsController = TextEditingController();
  final _areaController = TextEditingController();
  final _floorController = TextEditingController();
  final _totalFloorsController = TextEditingController();

  PropertyType _propertyType = PropertyType.apartment;
  ListingStatus _status = ListingStatus.active;
  List<String> _images = [];
  double? _lat;
  double? _lng;

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
    _addressController.dispose();
    _roomsController.dispose();
    _areaController.dispose();
    _floorController.dispose();
    _totalFloorsController.dispose();
    super.dispose();
  }

  Future<void> _loadListing() async {
    try {
      final listing = await _repo.getById(widget.listingId);
      setState(() {
        _listing = listing;
        _titleController.text = listing.title;
        _descriptionController.text = listing.description;
        _priceController.text = listing.price.toStringAsFixed(0);
        _addressController.text = listing.address;
        _roomsController.text = listing.rooms?.toString() ?? '';
        _areaController.text = listing.area?.toStringAsFixed(0) ?? '';
        _floorController.text = listing.floor?.toString() ?? '';
        _totalFloorsController.text = listing.totalFloors?.toString() ?? '';
        _propertyType = listing.propertyType;
        _status = listing.status;
        _images = List.from(listing.images);
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
      final urls = await _repo.uploadImages(files.map((f) => File(f.path)).toList());
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

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await _repo.update(
        widget.listingId,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        price: double.parse(_priceController.text),
        address: _addressController.text.trim(),
        propertyType: _propertyType,
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
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null && _listing == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Ошибка')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, style: const TextStyle(color: AppColors.error)),
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
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
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
              onTap: _pickImages,
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.border, width: 2, style: BorderStyle.solid),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.add_photo_alternate_outlined, size: 48, color: AppColors.textMuted),
                    const SizedBox(height: 8),
                    Text(
                      'Добавить фото',
                      style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w500),
                    ),
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
                            image: DecorationImage(
                              image: NetworkImage(_images[index]),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        Positioned(
                          top: 4,
                          right: 12,
                          child: GestureDetector(
                            onTap: () => _removeImage(index),
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
                        if (index == 0)
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

            // Status (Admin only)
            if (isAdmin) ...[
              const Text('Статус', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: ListingStatus.values.map((s) {
                  final selected = _status == s;
                  return ChoiceChip(
                    label: Text(s.label),
                    selected: selected,
                    onSelected: (_) => setState(() => _status = s),
                    selectedColor: AppColors.primary.withOpacity(0.2),
                  );
                }).toList(),
              ),
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
            const SizedBox(height: 16),

            // Price
            TextFormField(
              controller: _priceController,
              decoration: const InputDecoration(labelText: 'Цена, ₽'),
              keyboardType: TextInputType.number,
              validator: (v) {
                if (v == null || v.isEmpty) return 'Обязательное поле';
                if (double.tryParse(v) == null) return 'Некорректное число';
                return null;
              },
            ),
            const SizedBox(height: 16),

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
            TextFormField(
              controller: _addressController,
              decoration: const InputDecoration(labelText: 'Адрес'),
              validator: (v) => v == null || v.isEmpty ? 'Обязательное поле' : null,
            ),
            const SizedBox(height: 24),

            // Map
            const Text('Местоположение', style: TextStyle(fontWeight: FontWeight.w600)),
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

            // Save Button
            ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(56),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Сохранить изменения'),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
