import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/platform/app_image.dart';
import '../../../../core/services/onboarding_gate_service.dart';
import '../../../../core/services/onboarding_prefs.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/identity_photo_grid.dart';
import '../../../onboarding/services/photo_upload_service.dart';
import '../../../profile/data/profile_repository.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_state.dart';

class PhotoSetupPage extends StatefulWidget {
  const PhotoSetupPage({super.key});

  @override
  State<PhotoSetupPage> createState() => _PhotoSetupPageState();
}

class _PhotoSetupPageState extends State<PhotoSetupPage> {
  static const int _maxPerSection = 4;

  final ImagePicker _picker = ImagePicker();
  final ProfileRepository _profileRepository = ProfileRepository();

  final List<AppImage> _facePhotos = [];
  final List<AppImage> _bodyPhotos = [];
  bool _isUploading = false;
  bool _checkingExisting = true;

  int get _totalSelected => _facePhotos.length + _bodyPhotos.length;

  @override
  void initState() {
    super.initState();
    _redirectIfAlreadyHasPhotos();
  }

  Future<void> _redirectIfAlreadyHasPhotos() async {
    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthAuthenticated) {
      if (mounted) setState(() => _checkingExisting = false);
      return;
    }

    final hasPhotos = await OnboardingGateService.userHasIdentityPhotos(
      authState.user.id,
    );

    if (!mounted) return;

    if (hasPhotos) {
      context.go('/wardrobe');
      return;
    }

    setState(() => _checkingExisting = false);
  }

  Future<void> _pickImage({required bool isBody}) async {
    final list = isBody ? _bodyPhotos : _facePhotos;
    final remainingSlots = _maxPerSection - list.length;
    if (remainingSlots <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isBody
                ? 'Máximo $_maxPerSection fotos de cuerpo alcanzado'
                : 'Máximo $_maxPerSection fotos de cara alcanzado',
          ),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    try {
      final List<XFile> images = await _picker.pickMultiImage(
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 85,
        limit: remainingSlots,
      );

      if (images.isEmpty) return;

      final selected = images.take(remainingSlots).toList();
      final picked = await Future.wait(
        selected.map((img) => AppImage.fromXFile(img)),
      );

      if (!mounted) return;
      setState(() {
        if (isBody) {
          _bodyPhotos.addAll(picked);
        } else {
          _facePhotos.addAll(picked);
        }
      });

      if (images.length > remainingSlots && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Se añadieron las primeras $remainingSlots fotos (máximo por sección alcanzado).',
            ),
            backgroundColor: AppColors.gold,
          ),
        );
      }
    } catch (e) {
      debugPrint('⚠️ Error al seleccionar fotos: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al seleccionar fotos: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _continue() async {
    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthAuthenticated) {
      context.go('/login');
      return;
    }

    if (_totalSelected == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sube al menos una foto de cara o de cuerpo'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isUploading = true);

    final userId = authState.user.id;

    try {
      final photoUploadService = PhotoUploadService(
        profileRepository: _profileRepository,
      );

      await photoUploadService.uploadOnboardingPhotosAndIdentityBoard(
        userId: userId,
        facePhotos: _facePhotos,
        bodyPhotos: _bodyPhotos,
      );

      await OnboardingPrefs.markTipsSeen();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('¡Listo! Tus fotos se guardaron correctamente'),
          backgroundColor: AppColors.success,
          duration: Duration(seconds: 2),
        ),
      );

      await Future<void>.delayed(const Duration(milliseconds: 400));
      if (mounted) context.go('/wardrobe');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al subir: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _skip() async {
    final authState = context.read<AuthBloc>().state;
    await OnboardingPrefs.markTipsSeen();
    if (authState is AuthAuthenticated) {
      await _profileRepository.completeOnboarding(authState.user.id);
    }
    if (!mounted) return;
    context.go('/wardrobe');
  }

  @override
  Widget build(BuildContext context) {
    if (_checkingExisting) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Identidad'),
        actions: [
          TextButton(
            onPressed: _isUploading ? null : _skip,
            child: Text(
              'OMITIR',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Tu lookbook personal',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Sube fotos tuyas (no de Pinterest). Con una sola foto '
                      'de cara o cuerpo ya puedes usar la app; hasta 4 por sección '
                      'mejoran el try-on virtual.',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 28),
                    _sectionHeader(
                      title: 'Cara',
                      subtitle: 'Primer plano, buena luz',
                      count: _facePhotos.length,
                    ),
                    const SizedBox(height: 12),
                    IdentityPhotoGrid(
                      photos: _facePhotos,
                      maxPhotos: _maxPerSection,
                      onAdd: () => _pickImage(isBody: false),
                      onRemove: (i) => setState(() => _facePhotos.removeAt(i)),
                    ),
                    const SizedBox(height: 28),
                    _sectionHeader(
                      title: 'Cuerpo completo',
                      subtitle: 'De frente o perfil, fondo claro',
                      count: _bodyPhotos.length,
                    ),
                    const SizedBox(height: 12),
                    IdentityPhotoGrid(
                      photos: _bodyPhotos,
                      maxPhotos: _maxPerSection,
                      onAdd: () => _pickImage(isBody: true),
                      onRemove: (i) => setState(() => _bodyPhotos.removeAt(i)),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.gold.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: AppColors.gold.withValues(alpha: 0.35),
                        ),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.wb_sunny_outlined,
                            color: AppColors.gold,
                            size: 22,
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Buena iluminación y fondo despejado dan mejores resultados.',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: ElevatedButton(
                onPressed: _isUploading ? null : _continue,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 56),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _isUploading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : Text(
                        'Continuar ($_totalSelected)',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader({
    required String title,
    required String subtitle,
    required int count,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        Text(
          '$count/$_maxPerSection',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.primary,
          ),
        ),
      ],
    );
  }
}
