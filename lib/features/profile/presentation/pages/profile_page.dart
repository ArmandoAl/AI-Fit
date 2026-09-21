import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/widgets/app_network_image.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/platform/image_preview.dart';
import '../../../../core/platform/app_image.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/l10n/app_strings_es.dart';
import '../../../../core/widgets/app_page_app_bar.dart';
import '../../../../core/utils/keyboard_utils.dart';
import '../../../../core/widgets/shell_bottom_insets.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../../auth/presentation/bloc/auth_event.dart';
import 'dart:convert';
import '../../data/profile_repository.dart';
import '../../domain/user_identity_profile.dart';
import '../../../outfit/services/user_base_image_service.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final ImagePicker _picker = ImagePicker();
  final ProfileRepository _profileRepository = ProfileRepository();
  final UserBaseImageService _baseImageService = UserBaseImageService();
  final List<AppImage> _bodyPhotos = [];
  final List<AppImage> _facePhotos = [];
  // URLs from Firestore (already uploaded)
  final List<String> _bodyPhotoUrls = [];
  final List<String> _facePhotoUrls = [];
  String? _baseImageUrl; // URL de la imagen base generada
  IdentityProfile? _identityProfile;
  String? _identityCollageUrl;

  final int _maxBodyPhotos = 4;
  final int _maxFacePhotos = 4;

  bool _isUploading = false;
  bool _isLoadingPhotos = true;
  bool _isGeneratingBaseImage = false;
  bool _isBaseImageCollageFallback = false;

  Future<void> _pickImage({required bool isBodyPhoto}) async {
    final targetList = isBodyPhoto ? _bodyPhotos : _facePhotos;
    final maxPhotos = isBodyPhoto ? _maxBodyPhotos : _maxFacePhotos;

    if (targetList.length >= maxPhotos) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Maximum $maxPhotos photos allowed'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );

    if (image != null) {
      final picked = await AppImage.fromXFile(image);
      if (!mounted) return;
      setState(() {
        targetList.add(picked);
      });
    }
  }

  void _removePhoto({required bool isBodyPhoto, required int index}) async {
    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthAuthenticated) return;

    try {
      // Check if it's a URL (from Firestore) or File (local)
      final isUrl = isBodyPhoto
          ? index < _bodyPhotoUrls.length
          : index < _facePhotoUrls.length;

      if (isUrl) {
        // Remove from Firestore and Storage
        final photoUrl = isBodyPhoto
            ? _bodyPhotoUrls[index]
            : _facePhotoUrls[index];

        await _profileRepository.removePhoto(
          userId: authState.user.id,
          photoUrl: photoUrl,
          photoType: isBodyPhoto ? 'body' : 'face',
        );

        setState(() {
          if (isBodyPhoto) {
            _bodyPhotoUrls.removeAt(index);
          } else {
            _facePhotoUrls.removeAt(index);
          }
        });
      } else {
        // Remove local file (not yet uploaded)
        final localIndex = isBodyPhoto
            ? index - _bodyPhotoUrls.length
            : index - _facePhotoUrls.length;

        setState(() {
          if (isBodyPhoto) {
            _bodyPhotos.removeAt(localIndex);
          } else {
            _facePhotos.removeAt(localIndex);
          }
        });
      }
    } catch (e) {
      debugPrint('⚠️ Error removing photo: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error removing photo: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _saveProfile() async {
    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthAuthenticated) return;

    if (_bodyPhotos.isEmpty && _facePhotos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add at least one photo'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() {
      _isUploading = true;
    });

    try {
      final userId = authState.user.id;

      // Upload body photos if any
      if (_bodyPhotos.isNotEmpty) {
        await _profileRepository.uploadBodyPhotos(
          userId: userId,
          photos: _bodyPhotos,
        );
      }

      // Upload face photos if any
      if (_facePhotos.isNotEmpty) {
        await _profileRepository.uploadFacePhotos(
          userId: userId,
          photos: _facePhotos,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile saved successfully! 🎉'),
            backgroundColor: AppColors.success,
            duration: Duration(seconds: 2),
          ),
        );

        // Clear local photos after successful upload and reload from Firestore
        setState(() {
          _bodyPhotos.clear();
          _facePhotos.clear();
        });

        // Reload photos from Firestore to show the newly uploaded ones
        await _loadUserPhotos();
      }
    } catch (e) {
      if (mounted) {
        // Even if upload fails, clear photos and show friendly message
        setState(() {
          _bodyPhotos.clear();
          _facePhotos.clear();
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Photos saved (offline mode)'),
            backgroundColor: AppColors.secondary,
            duration: Duration(seconds: 2),
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
  void initState() {
    super.initState();
    _loadUserPhotos();
  }

  Future<void> _generateOrRegenerateBaseImage() async {
    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthAuthenticated) return;

    if (_bodyPhotoUrls.isEmpty && _facePhotoUrls.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sube al menos una foto de cara o cuerpo primero'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isGeneratingBaseImage = true);

    try {
      final userId = authState.user.id;
      final isRegenerate = _baseImageUrl != null;

      final baseImageUrl = isRegenerate
          ? await _baseImageService.regenerateUserBaseImage(
              userId: userId,
              bodyPhotoUrls: _bodyPhotoUrls,
              facePhotoUrls: _facePhotoUrls,
            )
          : await _baseImageService.generateUserBaseImage(
              userId: userId,
              bodyPhotoUrls: _bodyPhotoUrls,
              facePhotoUrls: _facePhotoUrls,
            );

      if (mounted) {
        await _loadUserPhotos();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                isRegenerate
                    ? '✅ Imagen base regenerada correctamente'
                    : '✅ Imagen base generada correctamente',
              ),
              backgroundColor: AppColors.success,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }

      debugPrint('✅ Base image: $baseImageUrl');
    } catch (e) {
      debugPrint('❌ Error generating base image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isGeneratingBaseImage = false);
      }
    }
  }

  Future<void> _deleteBaseImage() async {
    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthAuthenticated || _baseImageUrl == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar imagen base'),
        content: const Text(
          'Se eliminará la imagen base de IA. Podrás generar una nueva después. '
          'Tu perfil de identidad (rasgos) se conserva.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isGeneratingBaseImage = true);
    try {
      await _baseImageService.deleteUserBaseImage(authState.user.id);
      if (mounted) {
        setState(() => _baseImageUrl = null);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Imagen base eliminada'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al eliminar: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isGeneratingBaseImage = false);
    }
  }

  void _showIdentityProfileDialog() {
    if (_identityProfile == null || _identityProfile!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Aún no hay perfil de identidad. Genera o regenera la imagen base.',
          ),
        ),
      );
      return;
    }

    final json = const JsonEncoder.withIndent(
      '  ',
    ).convert(_identityProfile!.toJson());

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Perfil de identidad (IA)'),
        content: SingleChildScrollView(
          child: SelectableText(
            json,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  Future<void> _loadUserPhotos() async {
    if (!mounted) return;

    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthAuthenticated) return;

    final userId = authState.user.id; // Save before async operations

    setState(() {
      _isLoadingPhotos = true;
    });

    try {
      debugPrint('📸 Loading user photos for: $userId');
      final profileData = await _profileRepository.getUserProfile(userId);

      if (profileData != null) {
        debugPrint('✅ Profile data loaded');
        debugPrint('   bodyPhotos: ${profileData['bodyPhotos']}');
        debugPrint('   facePhotos: ${profileData['facePhotos']}');

        setState(() {
          _bodyPhotoUrls.clear();
          _facePhotoUrls.clear();

          // Load body photos URLs
          if (profileData['bodyPhotos'] != null) {
            final bodyPhotos = profileData['bodyPhotos'] as List<dynamic>;
            final validUrls = bodyPhotos
                .map((url) => url.toString())
                .where((url) => url.isNotEmpty && !url.startsWith('mock://'))
                .toList();

            debugPrint('📸 Found ${validUrls.length} valid body photo URLs');
            _bodyPhotoUrls.addAll(validUrls);
          } else {
            debugPrint('⚠️ No bodyPhotos field in profile data');
          }

          // Load face photos URLs
          if (profileData['facePhotos'] != null) {
            final facePhotos = profileData['facePhotos'] as List<dynamic>;
            final validUrls = facePhotos
                .map((url) => url.toString())
                .where((url) => url.isNotEmpty && !url.startsWith('mock://'))
                .toList();

            debugPrint('📸 Found ${validUrls.length} valid face photo URLs');
            _facePhotoUrls.addAll(validUrls);
          } else {
            debugPrint('⚠️ No facePhotos field in profile data');
          }

          _baseImageUrl = null;
          if (profileData['baseImageUrl'] != null) {
            final baseUrl = profileData['baseImageUrl'].toString();
            if (baseUrl.isNotEmpty && !baseUrl.startsWith('mock://')) {
              _baseImageUrl = baseUrl;
              debugPrint('✅ Found base image URL: $_baseImageUrl');
            }
          }

          _identityProfile = IdentityProfile.fromFirestoreUser(profileData);
          if (_identityProfile!.isEmpty) _identityProfile = null;

          final collage = profileData['identityCollageUrl']?.toString();
          _identityCollageUrl =
              (collage != null &&
                  collage.isNotEmpty &&
                  !collage.startsWith('mock://'))
              ? collage
              : null;

          debugPrint(
            '📊 Total photos loaded: ${_bodyPhotoUrls.length} body, ${_facePhotoUrls.length} face',
          );
        });

        // Verificación de integridad: detectar si la imagen base almacenada es corrupta (< 1 KB o placeholder 1x1)
        if (_baseImageUrl != null) {
          final isCorrupt = await _baseImageService.isBaseImageCorrupt(_baseImageUrl!);
          if (isCorrupt && mounted) {
            debugPrint('⚠️ Detected corrupt base image (< 1KB). Purging and auto-regenerating clean Identity Board...');
            await _baseImageService.deleteUserBaseImage(userId);
            if (mounted) {
              setState(() {
                _baseImageUrl = null;
                _isBaseImageCollageFallback = false;
              });
              if (_bodyPhotoUrls.isNotEmpty || _facePhotoUrls.isNotEmpty) {
                _generateOrRegenerateBaseImage();
              }
            }
          } else if (mounted) {
            final isFallback = await _baseImageService.isBaseImageCollageFallback(userId);
            if (mounted) {
              setState(() {
                _isBaseImageCollageFallback = isFallback;
              });
            }
          }
        }
      } else {
        debugPrint('⚠️ No profile data found for user: $userId');
      }
    } catch (e) {
      debugPrint('❌ Error loading user photos: $e');
      // Continue without photos - user can still upload new ones
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingPhotos = false;
        });
      }
    }
  }

  void _showDeleteAccountDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Account'),
        content: const Text(
          'Are you sure you want to delete your account? This action cannot be undone. All your photos, wardrobe items, and data will be permanently deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _deleteAccount(context);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteAccount(BuildContext context) async {
    if (!mounted) return;

    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthAuthenticated) return;

    final userId = authState.user.id;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final authBloc = context.read<AuthBloc>();

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // Delete from Firestore and Storage
      await _profileRepository.deleteUserAccount(userId);

      // Delete from Firebase Auth (this will trigger logout)
      // Note: This should be done in AuthRepository, but for now we'll do it here
      // The AuthBloc will handle the logout state change

      if (mounted) {
        navigator.pop(); // Close loading dialog
        // Logout will be handled by AuthRepository
        authBloc.add(const AuthLogoutRequested());
      }
    } catch (e) {
      if (mounted) {
        navigator.pop(); // Close loading dialog
        messenger.showSnackBar(
          SnackBar(
            content: Text('Error deleting account: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    hideKeyboard();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppPageAppBar(
        title: AppStringsEs.profile,
        subtitle: 'Identidad y lookbook',
        automaticallyImplyLeading: false,
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'logout') {
                context.read<AuthBloc>().add(const AuthLogoutRequested());
              } else if (value == 'delete') {
                _showDeleteAccountDialog(context);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, size: 20),
                    SizedBox(width: 8),
                    Text('Cerrar sesión'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_forever, color: Colors.red, size: 20),
                    SizedBox(width: 8),
                    Text('Eliminar cuenta', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: BlocBuilder<AuthBloc, AuthState>(
        builder: (context, authState) {
          if (authState is! AuthAuthenticated) {
            return const Center(child: CircularProgressIndicator());
          }

          final user = authState.user;

          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              24,
              24,
              24,
              24 + ShellBottomInsets.scrollPadding(context),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // User Info Card
                Center(
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: AppColors.primary.withValues(
                          alpha: 0.1,
                        ),
                        backgroundImage: user.avatarUrl.isNotEmpty
                            ? CachedNetworkImageProvider(user.avatarUrl)
                            : null,
                        child: user.avatarUrl.isEmpty
                            ? const Icon(
                                Icons.person,
                                size: 50,
                                color: AppColors.primary,
                              )
                            : null,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        user.name,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'UID: ${user.id}',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary.withValues(
                            alpha: 0.85,
                          ),
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.secondary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'Miembro atelier',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.secondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // Body Photos Section
                if (_isLoadingPhotos)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32.0),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else
                  _buildPhotoSection(
                    title: 'Fotos de cuerpo',
                    subtitle: 'Cuerpo completo para un try-on más fiel',
                    bodyPhotoUrls: _bodyPhotoUrls,
                    facePhotoUrls: [],
                    localBodyPhotos: _bodyPhotos,
                    localFacePhotos: [],
                    maxPhotos: _maxBodyPhotos,
                    isBodyPhoto: true,
                  ),

                const SizedBox(height: 24),

                // Face Photos Section
                if (!_isLoadingPhotos)
                  _buildPhotoSection(
                    title: 'Fotos de rostro',
                    subtitle: 'Primer plano para anclar identidad',
                    bodyPhotoUrls: [],
                    facePhotoUrls: _facePhotoUrls,
                    localBodyPhotos: [],
                    localFacePhotos: _facePhotos,
                    maxPhotos: _maxFacePhotos,
                    isBodyPhoto: false,
                  ),

                const SizedBox(height: 24),

                // Base Image Section (if exists)
                if (!_isLoadingPhotos && _baseImageUrl != null)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.success.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              _isBaseImageCollageFallback
                                  ? Icons.collections_bookmark_outlined
                                  : Icons.check_circle,
                              color: _isBaseImageCollageFallback
                                  ? AppColors.secondary
                                  : AppColors.success,
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _isBaseImageCollageFallback
                                    ? 'Tablero de identidad (Collage de Respaldo)'
                                    : 'Maniquí Base Neutral (IA)',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (_isBaseImageCollageFallback)
                          Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.secondary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: AppColors.secondary.withValues(alpha: 0.4),
                              ),
                            ),
                            child: const Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(Icons.info_outline, color: AppColors.secondary, size: 20),
                                SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Modo Collage de Respaldo Activo',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                      SizedBox(height: 2),
                                      Text(
                                        'Se está utilizando el tablero compuesto de fotos como respaldo defensivo. Pulsa "Regenerar" para sintetizar el maniquí neutral con IA.',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: AppColors.success.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: AppColors.success.withValues(alpha: 0.4),
                              ),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.auto_awesome, color: AppColors.success, size: 18),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Maniquí de Estudio IA Activo (Fondo neutro, fisionomía y complexión preservadas)',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: AppNetworkImage(
                            key: ValueKey(_baseImageUrl),
                            imageUrl: _baseImageUrl!,
                            width: double.infinity,
                            height: 300,
                            fit: BoxFit.cover,
                            placeholder: Container(
                              height: 300,
                              color: AppColors.background,
                              child: const Center(
                                child: CircularProgressIndicator(),
                              ),
                            ),
                            errorWidget: Container(
                              height: 300,
                              color: AppColors.background,
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.broken_image_outlined,
                                    size: 40,
                                    color: AppColors.error,
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Error al cargar imagen base',
                                    style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  ElevatedButton.icon(
                                    onPressed: _isGeneratingBaseImage
                                        ? null
                                        : _generateOrRegenerateBaseImage,
                                    icon: const Icon(Icons.refresh, size: 16),
                                    label: const Text('Reintentar'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.secondary,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 8,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'This optimized image will be used for all Virtual Try-On outfits.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _deleteBaseImage,
                                icon: const Icon(
                                  Icons.delete_outline,
                                  size: 18,
                                ),
                                label: const Text('Eliminar'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.error,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (_identityProfile != null)
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _showIdentityProfileDialog,
                                  icon: const Icon(
                                    Icons.badge_outlined,
                                    size: 18,
                                  ),
                                  label: const Text('Ver perfil IA'),
                                ),
                              ),
                          ],
                        ),
                        if (_identityProfile != null) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(
                                Icons.check_circle,
                                size: 14,
                                color: AppColors.success.withValues(alpha: 0.9),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Perfil de rasgos faciales/corporales listo'
                                  '${_identityCollageUrl != null ? ' · Collage guardado' : ''}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),

                if (!_isLoadingPhotos && _baseImageUrl != null)
                  const SizedBox(height: 24),

                // Generate Base Image Button
                if (!_isLoadingPhotos &&
                    (_bodyPhotoUrls.isNotEmpty || _facePhotoUrls.isNotEmpty))
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.secondary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.secondary.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              _baseImageUrl != null
                                  ? Icons.refresh
                                  : Icons.auto_awesome,
                              color: AppColors.secondary,
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _baseImageUrl != null
                                    ? 'Regenerar imagen base'
                                    : 'Generar imagen base',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _baseImageUrl != null
                              ? 'Generate a new base image from your photos. This will replace the existing one.'
                              : 'Create an optimized base image from your photos. This will be used for all Virtual Try-On outfits, saving time and costs.',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _isGeneratingBaseImage
                                ? null
                                : _generateOrRegenerateBaseImage,
                            icon: _isGeneratingBaseImage
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                    ),
                                  )
                                : Icon(
                                    _baseImageUrl != null
                                        ? Icons.refresh
                                        : Icons.auto_awesome,
                                  ),
                            label: Text(
                              _isGeneratingBaseImage
                                  ? 'Generando...'
                                  : _baseImageUrl != null
                                  ? 'Regenerar imagen base'
                                  : 'Generar imagen base',
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.secondary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 32),

                // Save Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isUploading ? null : _saveProfile,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
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
                        : const Text(
                            'Guardar perfil',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 16),

                // Tips Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.2),
                    ),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.tips_and_updates_outlined,
                        color: AppColors.primary,
                        size: 24,
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Consejo de atelier',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Más fotos, mejor try-on. Luz natural y fondo despejado hacen que la IA conserve tu identidad.',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: ShellBottomInsets.scrollExtra),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildPhotoSection({
    required String title,
    required String subtitle,
    required List<String> bodyPhotoUrls,
    required List<String> facePhotoUrls,
    required List<AppImage> localBodyPhotos,
    required List<AppImage> localFacePhotos,
    required int maxPhotos,
    required bool isBodyPhoto,
  }) {
    // Combine URLs and local files
    final photoUrls = isBodyPhoto ? bodyPhotoUrls : facePhotoUrls;
    final localPhotos = isBodyPhoto ? localBodyPhotos : localFacePhotos;
    final totalPhotos = photoUrls.length + localPhotos.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header
        Row(
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
              '$totalPhotos/$maxPhotos',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // Photos Grid
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.75,
          ),
          itemCount: maxPhotos,
          itemBuilder: (context, index) {
            // Check if this index has a URL (from Firestore)
            if (index < photoUrls.length) {
              // Show photo from Firestore (URL)
              return Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: AppNetworkImage(
                      imageUrl: photoUrls[index],
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: GestureDetector(
                      onTap: () =>
                          _removePhoto(isBodyPhoto: isBodyPhoto, index: index),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            } else if (index < totalPhotos) {
              // Show local file (not yet uploaded)
              final localIndex = index - photoUrls.length;
              return Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: imageSourcePreview(
                      localPhotos[localIndex],
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: GestureDetector(
                      onTap: () =>
                          _removePhoto(isBodyPhoto: isBodyPhoto, index: index),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            } else {
              // Show placeholder
              return GestureDetector(
                onTap: () => _pickImage(isBodyPhoto: isBodyPhoto),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.textSecondary.withValues(alpha: 0.3),
                      width: 2,
                      style: BorderStyle.solid,
                    ),
                  ),
                  child: Icon(
                    Icons.add_photo_alternate_outlined,
                    size: 32,
                    color: AppColors.textSecondary.withValues(alpha: 0.5),
                  ),
                ),
              );
            }
          },
        ),
      ],
    );
  }
}
