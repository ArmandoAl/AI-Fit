import '../../../core/platform/app_image.dart';
import '../../profile/data/profile_repository.dart';

/// Saves the photos Gemini uses as identity references for new outfit images.
class PhotoUploadService {
  final ProfileRepository _profileRepository;

  PhotoUploadService({ProfileRepository? profileRepository})
    : _profileRepository = profileRepository ?? ProfileRepository();

  Future<void> uploadOnboardingPhotos({
    required String userId,
    required List<AppImage> facePhotos,
    required List<AppImage> bodyPhotos,
  }) async {
    if (facePhotos.isEmpty && bodyPhotos.isEmpty) {
      throw ArgumentError('At least one face or body photo is required.');
    }

    await _profileRepository.ensureProfileExists(userId);
    if (facePhotos.isNotEmpty) {
      await _profileRepository.uploadFacePhotos(
        userId: userId,
        photos: facePhotos,
      );
    }
    if (bodyPhotos.isNotEmpty) {
      await _profileRepository.uploadBodyPhotos(
        userId: userId,
        photos: bodyPhotos,
      );
    }
    await _profileRepository.completeOnboarding(userId);
  }
}
