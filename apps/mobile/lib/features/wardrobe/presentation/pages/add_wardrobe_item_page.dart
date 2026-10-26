import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/platform/image_preview.dart';
import '../../../../core/l10n/app_strings_es.dart';
import '../../../../core/platform/app_image.dart';
import '../../../../core/services/native_cutout_service.dart';
import '../../domain/wardrobe_palette.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../data/wardrobe_repository_impl.dart';
import '../bloc/wardrobe_bloc.dart';
import '../bloc/wardrobe_event.dart';
import '../widgets/category_selector.dart';

class AddWardrobeItemPage extends StatefulWidget {
  final List<AppImage>? initialImages;

  const AddWardrobeItemPage({super.key, this.initialImages});

  @override
  State<AddWardrobeItemPage> createState() => _AddWardrobeItemPageState();
}

class _AddWardrobeItemPageState extends State<AddWardrobeItemPage> {
  final ImagePicker _picker = ImagePicker();
  final WardrobeRepositoryImpl _repository = WardrobeRepositoryImpl();

  final List<AppImage> _selectedImages = [];
  final List<ItemFormData> _formDataList = [];
  final List<Uint8List?> _nativeCutouts = [];

  bool _isUploading = false;

  // Clothing type options
  static const List<String> _clothingTypes = [
    'top',
    'bottom',
    'one_piece',
    'shoes',
    'outerwear',
    'accessories',
  ];

  // Sub-type options by main type
  static const Map<String, List<String>> _subTypes = {
    'top': ['t-shirt', 'shirt', 'sweater', 'hoodie', 'tank-top', 'blouse'],
    'bottom': ['jeans', 'pants', 'shorts', 'skirt', 'chinos', 'sweatpants'],
    'one_piece': ['dress', 'jumpsuit', 'romper', 'vestido', 'enterizo'],
    'shoes': ['sneakers', 'boots', 'sandals', 'dress-shoes', 'sports-shoes'],
    'outerwear': ['jacket', 'coat', 'blazer', 'cardigan', 'vest'],
    'accessories': [
      'scarf',
      'earrings',
      'necklace',
      'bag',
      'belt',
      'bufanda',
      'aretes',
      'collar',
      'bolso',
    ],
  };

  @override
  void initState() {
    super.initState();
    debugPrint('🔄 AddWardrobeItemPage initState');
    debugPrint('   - initialImages: ${widget.initialImages?.length ?? 0}');
    debugPrint('   - initialImages is null: ${widget.initialImages == null}');

    if (widget.initialImages != null && widget.initialImages!.isNotEmpty) {
      for (var img in widget.initialImages!) {
        debugPrint('   - Image key: ${img.storageKey}');
      }

      _selectedImages.addAll(widget.initialImages!);
      _formDataList.addAll(widget.initialImages!.map((_) => ItemFormData()));
      _nativeCutouts.addAll(widget.initialImages!.map((_) => null));
      debugPrint('✅ Initialized with ${_selectedImages.length} images');
      _extractNativeCutouts(widget.initialImages!);
    } else {
      debugPrint('⚠️ No initial images provided - showing empty state');
    }
  }

  Future<void> _pickImages() async {
    final List<XFile> images = await _picker.pickMultiImage(
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 85,
    );

    if (images.isNotEmpty) {
      final sources = await AppImage.fromXFiles(images);
      if (!mounted) return;
      setState(() {
        _selectedImages.addAll(sources);
        _formDataList.addAll(images.map((_) => ItemFormData()));
        _nativeCutouts.addAll(images.map((_) => null));
      });
      _extractNativeCutouts(sources);
    }
  }

  /// Recorte on-device (Apple Vision) apenas se selecciona la foto: si el
  /// dispositivo/plataforma no lo soporta o falla, deja el slot en `null` y
  /// el flujo de guardado cae al pipeline de Cloud Run sin bloquear al usuario.
  void _extractNativeCutouts(List<AppImage> images) {
    final baseIndex = _selectedImages.length - images.length;
    for (var i = 0; i < images.length; i++) {
      final index = baseIndex + i;
      NativeCutoutService.isolateGarment(images[i].bytes).then((cutout) {
        if (!mounted || cutout == null) return;
        setState(() {
          _nativeCutouts[index] = cutout;
        });
      });
    }
  }

  bool _validateForms() {
    for (int i = 0; i < _formDataList.length; i++) {
      if (_formDataList[i].type == null || _formDataList[i].subType == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${AppStringsEs.fillRequiredFields} (${i + 1})'),
            backgroundColor: AppColors.error,
          ),
        );
        return false;
      }
    }
    return true;
  }

  Future<void> _saveItems() async {
    debugPrint('💾 Save button pressed');
    debugPrint('   - Images: ${_selectedImages.length}');
    debugPrint('   - Form data: ${_formDataList.length}');

    if (!_validateForms()) {
      debugPrint('❌ Form validation failed');
      return;
    }

    debugPrint('✅ Form validation passed');

    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthAuthenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(AppStringsEs.pleaseLogin),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() {
      _isUploading = true;
    });

    try {
      for (int i = 0; i < _selectedImages.length; i++) {
        final image = _selectedImages[i];
        final formData = _formDataList[i];

        // Upload image, save to Supabase immediately (rembg runs in background
        // unless Apple Vision already produced a cutout on-device)
        await _repository.addWardrobeItemWithData(
          image: image,
          type: formData.type!,
          subType: formData.subType!,
          brand: formData.brand,
          nativeCutoutBytes: _nativeCutouts[i],
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(AppStringsEs.itemsAddedSuccess),
            backgroundColor: AppColors.success,
            duration: Duration(seconds: 2),
          ),
        );

        // Refresh wardrobe list
        context.read<WardrobeBloc>().add(const WardrobeItemAdded());

        // Close page
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${AppStringsEs.errorAddingItems}: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    debugPrint(
      '🏗️ AddWardrobeItemPage build - images: ${_selectedImages.length}',
    );
    final isSingleItem = _selectedImages.length == 1;
    debugPrint('🏗️ Is single item: $isSingleItem');

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isSingleItem
              ? AppStringsEs.addItem
              : AppStringsEs.addItems(_selectedImages.length),
        ),
        actions: [
          if (_selectedImages.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: _isUploading
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        ),
                      ),
                    )
                  : TextButton.icon(
                      onPressed: _saveItems,
                      icon: const Icon(Icons.check, color: Colors.white),
                      label: const Text(
                        AppStringsEs.save,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
            ),
        ],
      ),
      body: _selectedImages.isEmpty
          ? _buildEmptyState()
          : (isSingleItem ? _buildSingleItemForm() : _buildMultipleItemsForm()),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.add_photo_alternate_outlined,
            size: 80,
            color: AppColors.textSecondary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 24),
          Text(
            AppStringsEs.noImagesSelected,
            style: TextStyle(fontSize: 18, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: _pickImages,
            icon: const Icon(Icons.photo_library),
            label: const Text(AppStringsEs.selectImages),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSingleItemForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // Image preview
          SizedBox(
            height: 300,
            width: double.infinity,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: _buildImagePreview(0),
            ),
          ),
          const SizedBox(height: 24),
          // Form
          _buildItemForm(0),
        ],
      ),
    );
  }

  Widget _buildMultipleItemsForm() {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _selectedImages.length,
      separatorBuilder: (_, __) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        return Card(
          key: ValueKey('wardrobe_item_card_$index'),
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    height: 200,
                    width: double.infinity,
                    child: _buildImagePreview(index),
                  ),
                ),
                const SizedBox(height: 16),
                _buildItemForm(index, isCompact: true),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Prioriza el cutout de Apple Vision (fondo transparente) sobre la foto
  /// original apenas esté disponible; mismo criterio que usa el catálogo.
  Widget _buildImagePreview(int index) {
    final cutout = _nativeCutouts[index];
    if (cutout != null) {
      return Container(
        color: Colors.white,
        child: Image.memory(cutout, fit: BoxFit.contain),
      );
    }
    return imageSourcePreview(
      _selectedImages[index],
      fit: BoxFit.cover,
      cacheWidth: 600,
    );
  }

  Widget _buildItemForm(int index, {bool isCompact = false}) {
    final formData = _formDataList[index];
    final subTypeOptions = formData.type != null
        ? (_subTypes[formData.type] ?? [])
        : <String>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!isCompact) ...[
          Text(
            AppStringsEs.itemDetails,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
        ],
        // Category Selector Chips
        CategorySelector(
          selectedCategory: formData.type ?? '',
          categories: _clothingTypes,
          padding: EdgeInsets.zero,
          onCategorySelected: (type) {
            setState(() {
              formData.type = type;
              formData.subType = null;
            });
          },
        ),
        const SizedBox(height: 16),
        // Type dropdown
        DropdownButtonFormField<String>(
          key: ValueKey('type_${index}_${formData.type}'),
          initialValue: formData.type,
          decoration: const InputDecoration(
            labelText: AppStringsEs.typeRequired,
            border: OutlineInputBorder(),
          ),
          items: _clothingTypes.map((type) {
            return DropdownMenuItem(
              value: type,
              child: Text(WardrobePalette.labelType(type)),
            );
          }).toList(),
          onChanged: (value) {
            setState(() {
              formData.type = value;
              formData.subType = null; // Reset subType when type changes
            });
          },
        ),
        const SizedBox(height: 16),
        // Sub-type dropdown
        DropdownButtonFormField<String>(
          key: ValueKey('subtype_${index}_${formData.type}_${formData.subType}'),
          initialValue: formData.subType,
          decoration: const InputDecoration(
            labelText: AppStringsEs.subTypeRequired,
            border: OutlineInputBorder(),
          ),
          items: subTypeOptions.map((subType) {
            return DropdownMenuItem(
              value: subType,
              child: Text(WardrobePalette.labelSubtype(subType)),
            );
          }).toList(),
          onChanged: formData.type == null
              ? null
              : (value) {
                  setState(() {
                    formData.subType = value;
                  });
                },
        ),
        const SizedBox(height: 16),
        // Brand (optional)
        TextFormField(
          decoration: const InputDecoration(
            labelText: AppStringsEs.brandOptional,
            border: OutlineInputBorder(),
          ),
          initialValue: formData.brand,
          onChanged: (value) {
            formData.brand = value.isEmpty ? null : value;
          },
        ),
        if (isCompact && index < _selectedImages.length - 1) ...[
          const SizedBox(height: 16),
          const Divider(),
        ],
      ],
    );
  }
}

// Helper class to store form data for each item
class ItemFormData {
  String? type;
  String? subType;
  String? brand;

  ItemFormData({this.type, this.subType, this.brand});
}
