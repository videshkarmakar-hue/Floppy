import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:open_filex/open_filex.dart';

import '../services/update_service.dart';

enum UpdateStatus { idle, checking, upToDate, available, downloading, installing, downloaded, failed }

/// Tracks whether a newer Floppy release exists and drives the in-app
/// download + install, so updating never opens GitHub.
class UpdateProvider extends ChangeNotifier {
  UpdateStatus _status = UpdateStatus.idle;
  AppRelease? _release;
  String _currentVersion = '';
  double _progress = 0;
  String? _error;

  UpdateStatus get status => _status;
  AppRelease? get release => _release;
  String get currentVersion => _currentVersion;
  double get progress => _progress;
  String? get error => _error;

  bool get isChecking => _status == UpdateStatus.checking;
  bool get isDownloading =>
      _status == UpdateStatus.downloading || _status == UpdateStatus.installing;
  bool get isUpToDate => _status == UpdateStatus.upToDate;

  bool get updateAvailable =>
      _release != null &&
      _currentVersion.isNotEmpty &&
      compareVersions(_release!.version, _currentVersion) > 0;

  bool get hasDirectApk => _release?.hasDirectApk ?? false;

  /// A newer release exists but has no APK asset, so it cannot be installed
  /// from inside the app.
  bool get hasReleaseWithoutDirectDownload => updateAvailable && !hasDirectApk;

  /// An installable update is pending, so the update slot must stay on screen
  /// and cannot be skipped or closed.
  bool get isUpdateMandatory => updateAvailable && hasDirectApk;

  /// Looks for a newer GitHub release. Safe to call on every app start/resume.
  Future<void> check() async {
    if (_status == UpdateStatus.checking ||
        _status == UpdateStatus.downloading ||
        _status == UpdateStatus.installing) {
      return;
    }

    _status = UpdateStatus.checking;
    _error = null;
    notifyListeners();

    try {
      final result = await checkForUpdate();
      _currentVersion = result.currentVersion;
      _release = result.latest;
      _status = result.updateAvailable ? UpdateStatus.available : UpdateStatus.upToDate;
    } catch (e) {
      _error = describeUpdateError(e);
      _status = UpdateStatus.failed;
    }
    notifyListeners();
  }

  /// Downloads the release APK and hands it to the system package installer.
  Future<void> downloadAndInstall() async {
    final release = _release;
    if (release == null) return;

    if (!release.hasDirectApk) {
      _error = kNoDirectDownloadMessage;
      notifyListeners();
      return;
    }
    if (_status == UpdateStatus.downloading || _status == UpdateStatus.installing) {
      return;
    }

    _status = UpdateStatus.downloading;
    _progress = 0;
    _error = null;
    notifyListeners();

    try {
      final file = await downloadReleaseApk(
        release,
        apk: release.selectApk(await _deviceAbis()),
        onProgress: (value) {
          _progress = value;
          notifyListeners();
        },
      );

      _status = UpdateStatus.installing;
      notifyListeners();

      final result = await OpenFilex.open(
        file.path,
        type: 'application/vnd.android.package-archive',
      );

      if (result.type == ResultType.done) {
        _status = UpdateStatus.downloaded;
        _error = null;
      } else {
        _status = UpdateStatus.failed;
        _error = result.message.isEmpty
            ? 'The package installer did not open. Allow "Install unknown apps" for Floppy and try again.'
            : result.message;
      }
    } catch (e) {
      _error = describeUpdateError(e);
      _status = UpdateStatus.failed;
    }
    notifyListeners();
  }

  /// ABIs this device can run, so the matching split APK is downloaded.
  Future<List<String>> _deviceAbis() async {
    try {
      final info = await DeviceInfoPlugin().androidInfo;
      if (info.supportedAbis.isNotEmpty) return info.supportedAbis;
    } catch (_) {}
    return const ['arm64-v8a', 'armeabi-v7a'];
  }
}
