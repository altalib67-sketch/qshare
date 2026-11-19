import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// All permissions, requested ONCE (first launch). After that the app
/// never asks again while they are granted; if something was denied,
/// the UI shows one clear fix button instead of re-asking in a loop.
class PermissionsService {
  static const _askedKey = 'qshare_permissions_asked_v1';

  /// True when we already went through the first-launch request.
  static Future<bool> wasAsked() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_askedKey) ?? false;
  }

  static Future<void> markAsked() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_askedKey, true);
  }

  /// Request everything the app needs, in one go.
  /// Returns true when the essentials (camera + files + network
  /// discovery) are granted. "All files access" is requested too but
  /// is reported separately — without it files land in the app folder.
  static Future<PermissionResult> requestAll() async {
    final statuses = await [
      Permission.camera,
      Permission.photos,
      Permission.videos,
      Permission.audio,
      Permission.storage,
      Permission.locationWhenInUse,
      Permission.nearbyWifiDevices,
    ].request();
    // All-files access opens the system settings page (Android 11+),
    // it cannot be granted from a normal dialog.
    var allFiles = await Permission.manageExternalStorage.status;
    if (!allFiles.isGranted) {
      allFiles = await Permission.manageExternalStorage.request();
    }
    await markAsked();
    final essentialsOk =
        statuses[Permission.camera]?.isGranted == true ||
            statuses[Permission.photos]?.isGranted == true;
    return PermissionResult(
      essentialsOk: essentialsOk,
      allFilesAccess: allFiles.isGranted,
      cameraGranted:
          statuses[Permission.camera]?.isGranted ?? false,
    );
  }

  static Future<bool> hasAllFilesAccess() async {
    if (await Permission.manageExternalStorage.isGranted) return true;
    // On Android 10 and below the classic storage permission is enough.
    return await Permission.storage.isGranted;
  }

  static Future<void> openSettings() async {
    await openAppSettings();
  }
}

class PermissionResult {
  PermissionResult({
    required this.essentialsOk,
    required this.allFilesAccess,
    required this.cameraGranted,
  });

  final bool essentialsOk;
  final bool allFilesAccess;
  final bool cameraGranted;
}
