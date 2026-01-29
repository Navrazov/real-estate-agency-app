import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/auth/auth_service.dart';
import '../../../../core/widgets/location_picker_map.dart';
import '../../data/listings_repository.dart';

class CreateListingScreen extends StatefulWidget {
  const CreateListingScreen({super.key});

  @override
  State<CreateListingScreen> createState() => _CreateListingScreenState();
}

class _CreateListingScreenState extends State<CreateListingScreen> {
  final _repo = ListingsRepository();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _picker = ImagePicker();
  List<String> _imageUrls = [];
  List<File> _pendingFiles = [];
  double? _lat;
  double? _lng;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _priceCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final x = await _picker.pickMultiImage();
    if (x.isEmpty) return;
    setState(() {
      _error = null;
      _pendingFiles.addAll(x.map((e) => File(e.path)));
    });
  }

  void _removeImage(int index) {
    setState(() {
      if (index < _imageUrls.length) {
        _imageUrls.removeAt(index);
      } else {
        _pendingFiles.removeAt(index - _imageUrls.length);
      }
    });
  }

  Future<void> _submit() async {
    final price = double.tryParse(_priceCtrl.text);
    if (price == null || price < 0) {
      setState(() => _error = 'Укажите корректную цену');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (_pendingFiles.isNotEmpty) {
        final urls = await _repo.uploadImages(_pendingFiles);
        _imageUrls.addAll(urls);
        _pendingFiles.clear();
      }
      final listing = await _repo.create(
        title: _titleCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        price: price,
        address: _addressCtrl.text.trim(),
        images: _imageUrls.isEmpty ? null : _imageUrls,
        lat: _lat,
        lng: _lng,
      );
      if (mounted) context.go('/listing/${listing.id}');
    } catch (e) {
      if (mounted) setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalImages = _imageUrls.length + _pendingFiles.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Новое объявление'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_error != null) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(_error!, style: const TextStyle(color: Colors.red)),
                ),
              ],
              const Text('Фото', style: TextStyle(fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _loading ? null : _pickImages,
                icon: const Icon(Icons.add_photo_alternate),
                label: const Text('Добавить фото'),
              ),
              if (totalImages > 0) ...[
                const SizedBox(height: 8),
                SizedBox(
                  height: 100,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: totalImages,
                    itemBuilder: (context, i) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: i < _imageUrls.length
                                  ? Image.network(_imageUrls[i], width: 100, height: 100, fit: BoxFit.cover)
                                  : Image.file(_pendingFiles[i - _imageUrls.length], width: 100, height: 100, fit: BoxFit.cover),
                            ),
                            Positioned(
                              top: 4,
                              right: 4,
                              child: IconButton(
                                icon: const Icon(Icons.close, color: Colors.white, size: 20),
                                style: IconButton.styleFrom(backgroundColor: Colors.black54, padding: const EdgeInsets.all(4)),
                                onPressed: () => _removeImage(i),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
              const SizedBox(height: 16),
              TextFormField(
                controller: _titleCtrl,
                decoration: const InputDecoration(labelText: 'Заголовок'),
                textCapitalization: TextCapitalization.sentences,
                enabled: !_loading,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descCtrl,
                decoration: const InputDecoration(labelText: 'Описание'),
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                enabled: !_loading,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _priceCtrl,
                decoration: const InputDecoration(labelText: 'Цена (₽)'),
                keyboardType: TextInputType.number,
                enabled: !_loading,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _addressCtrl,
                decoration: const InputDecoration(labelText: 'Адрес'),
                textCapitalization: TextCapitalization.words,
                enabled: !_loading,
              ),
              const SizedBox(height: 16),
              const Text('Местоположение на карте', style: TextStyle(fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: LocationPickerMap(
                  lat: _lat,
                  lng: _lng,
                  onChanged: (lat, lng) => setState(() {
                    _lat = lat;
                    _lng = lng;
                  }),
                  height: 240,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _loading ? null : _submit,
                child: _loading
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Опубликовать'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
