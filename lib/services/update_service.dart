import 'dart:convert';
import 'dart:io';

import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// GitHub repository that publishes Floppy builds.
const String kUpdateRepoOwner = 'videshkarmakar-hue';
const String kUpdateRepoName = 'Floppy';

/// Public releases feed for [kUpdateRepoOwner]/[kUpdateRepoName].
final Uri kReleasesFeedUri = Uri.parse(
  'https://api.github.com/repos/$kUpdateRepoOwner/$kUpdateRepoName/releases',
);

/// Message shown when a release exists but ships no APK asset.
const String kNoDirectDownloadMessage =
    "A direct download isn't available for this release.";

/// Raised when an update cannot be checked, downloaded or installed.
class UpdateException implements Exception {
  final String message;

  const UpdateException(this.message);

  @override
  String toString() => message;
}

/// A downloadable APK attached to a release.
class ReleaseApk {
  final String name;
  final String url;
  final int size;

  const ReleaseApk({required this.name, required this.url, required this.size});
}

/// A Floppy release published on GitHub.
class AppRelease {
  /// Release tag exactly as published, e.g. `v3.0.1`.
  final String tagName;

  /// Tag without the `v` prefix or build metadata, e.g. `3.0.1`.
  final String version;

  final String notes;

  /// Every `.apk` asset attached to the release, in preference order.
  final List<ReleaseApk> apks;

  final DateTime? publishedAt;

  const AppRelease({
    required this.tagName,
    required this.version,
    this.notes = '',
    this.apks = const [],
    this.publishedAt,
  });

  /// Whether this release carries an APK the app can download itself.
  ///
  /// When this is false the app says so in-app and never sends the user
  /// to the GitHub release page.
  bool get hasDirectApk => apks.isNotEmpty;

  ReleaseApk? get defaultApk => apks.isEmpty ? null : apks.first;

  String? get apkUrl => defaultApk?.url;
  String? get apkName => defaultApk?.name;
  int get apkSize => defaultApk?.size ?? 0;

  /// Picks the APK built for this device.
  ///
  /// Releases ship one APK per ABI, so the first of [deviceAbis] that has a
  /// matching split wins; anything else falls back to the preferred asset.
  ReleaseApk? selectApk(List<String> deviceAbis) {
    if (apks.isEmpty) return null;
    for (final abi in deviceAbis) {
      final wanted = abi.toLowerCase();
      for (final apk in apks) {
        if (apk.name.toLowerCase().contains(wanted)) return apk;
      }
    }
    return apks.first;
  }
}

int _apkRank(String name) {
  final lower = name.toLowerCase();
  if (lower.contains('universal')) return 0;
  if (lower.contains('arm64')) return 1;
  if (lower.contains('armeabi')) return 2;
  if (lower.contains('x86')) return 3;
  return 1;
}

/// Outcome of an update check.
class UpdateCheckResult {
  final AppRelease? latest;
  final String currentVersion;

  const UpdateCheckResult({required this.latest, required this.currentVersion});

  bool get updateAvailable =>
      latest != null && compareVersions(latest!.version, currentVersion) > 0;
}

/// Turns `v3.0.1`, `3.0.1+3001` and similar tags into a plain `3.0.1`.
String normalizeVersion(String raw) {
  var value = raw.trim();
  if (value.startsWith('v') || value.startsWith('V')) {
    value = value.substring(1);
  }
  final plus = value.indexOf('+');
  if (plus != -1) {
    value = value.substring(0, plus);
  }
  return value;
}

List<int> _versionParts(String version) {
  return normalizeVersion(version)
      .split(RegExp(r'[.\-_]'))
      .map((segment) {
        final match = RegExp(r'^\d+').stringMatch(segment);
        return match == null ? 0 : int.parse(match);
      })
      .toList();
}

/// Compares two version strings numerically: `1` when [a] is newer than [b].
int compareVersions(String a, String b) {
  final left = _versionParts(a);
  final right = _versionParts(b);
  final length = left.length > right.length ? left.length : right.length;
  for (var i = 0; i < length; i++) {
    final x = i < left.length ? left[i] : 0;
    final y = i < right.length ? right[i] : 0;
    if (x != y) return x > y ? 1 : -1;
  }
  return 0;
}

/// Parses the GitHub `/releases` payload, ignoring drafts and pre-releases.
List<AppRelease> parseReleases(String body) {
  final decoded = jsonDecode(body);
  if (decoded is! List) return const [];

  final releases = <AppRelease>[];
  for (final entry in decoded) {
    if (entry is! Map) continue;
    if (entry['draft'] == true || entry['prerelease'] == true) continue;

    final tag = (entry['tag_name'] ?? '').toString();
    if (tag.isEmpty) continue;

    final apks = <ReleaseApk>[];
    final assets = entry['assets'];
    if (assets is List) {
      for (final asset in assets) {
        if (asset is! Map) continue;
        final name = (asset['name'] ?? '').toString();
        final url = (asset['browser_download_url'] ?? '').toString();
        if (url.isEmpty || !name.toLowerCase().endsWith('.apk')) continue;
        final size = asset['size'];
        apks.add(ReleaseApk(
          name: name,
          url: url,
          size: size is num ? size.toInt() : 0,
        ));
      }
      apks.sort((a, b) => _apkRank(a.name).compareTo(_apkRank(b.name)));
    }

    releases.add(AppRelease(
      tagName: tag,
      version: normalizeVersion(tag),
      notes: (entry['body'] ?? '').toString().trim(),
      apks: apks,
      publishedAt: DateTime.tryParse((entry['published_at'] ?? '').toString()),
    ));
  }
  return releases;
}

/// Returns the highest version in [releases], or null when empty.
AppRelease? pickLatest(List<AppRelease> releases) {
  AppRelease? latest;
  for (final release in releases) {
    if (latest == null || compareVersions(release.version, latest.version) > 0) {
      latest = release;
    }
  }
  return latest;
}

/// Downloads the raw releases payload from [feed].
Future<String> fetchReleaseFeed([Uri? feed]) async {
  final uri = feed ?? kReleasesFeedUri;
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 20);
  try {
    final request = await client.getUrl(uri);
    request.headers.set(HttpHeaders.acceptHeader, 'application/vnd.github+json');
    request.headers.set(HttpHeaders.userAgentHeader, 'Floppy-Updater');
    final response = await request.close();
    final body = await response.transform(utf8.decoder).join();
    if (response.statusCode != HttpStatus.ok) {
      throw UpdateException(
        'The update server returned HTTP ${response.statusCode}.',
      );
    }
    return body;
  } finally {
    client.close(force: true);
  }
}

/// Version of the Floppy build that is currently installed.
Future<String> currentAppVersion() async {
  try {
    final info = await PackageInfo.fromPlatform();
    return info.version.isEmpty ? '0.0.0' : info.version;
  } catch (_) {
    return '0.0.0';
  }
}

/// Checks the feed for a release newer than the installed build.
///
/// [currentVersion] exists so the check can be exercised without a platform
/// channel; production calls omit it and the installed version is used.
Future<UpdateCheckResult> checkForUpdate({Uri? feed, String? currentVersion}) async {
  final installed = currentVersion ?? await currentAppVersion();
  final body = await fetchReleaseFeed(feed);
  return UpdateCheckResult(
    latest: pickLatest(parseReleases(body)),
    currentVersion: installed,
  );
}

Future<Directory> _defaultUpdateDirectory() async {
  // A public folder keeps the APK readable by the system package installer.
  try {
    final downloads = Directory('/storage/emulated/0/Download');
    if (await downloads.exists()) {
      final dir = Directory(p.join(downloads.path, 'Floppy Updates'));
      await dir.create(recursive: true);
      return dir;
    }
  } catch (_) {}
  final temp = await getTemporaryDirectory();
  final dir = Directory(p.join(temp.path, 'updates'));
  await dir.create(recursive: true);
  return dir;
}

/// Downloads the APK of [release] and returns the saved file.
///
/// [destination] overrides where the file is written; production leaves it
/// null so the APK lands in the Download folder.
Future<File> downloadReleaseApk(
  AppRelease release, {
  ReleaseApk? apk,
  void Function(double progress)? onProgress,
  Directory? destination,
}) async {
  final target = apk ?? release.defaultApk;
  if (target == null || target.url.isEmpty) {
    throw const UpdateException(kNoDirectDownloadMessage);
  }

  final directory = destination ?? await _defaultUpdateDirectory();
  final name = target.name.toLowerCase().endsWith('.apk')
      ? target.name
      : 'Floppy-${release.version}.apk';
  final file = File(p.join(directory.path, name));
  if (await file.exists()) {
    await file.delete();
  }

  final client = HttpClient()..connectionTimeout = const Duration(seconds: 20);
  try {
    final request = await client.getUrl(Uri.parse(target.url));
    request.headers.set(HttpHeaders.userAgentHeader, 'Floppy-Updater');
    request.followRedirects = true;
    final response = await request.close();
    if (response.statusCode != HttpStatus.ok) {
      throw UpdateException('Download failed with HTTP ${response.statusCode}.');
    }

    final expected = response.contentLength > 0 ? response.contentLength : target.size;
    final sink = file.openWrite();
    var received = 0;
    try {
      await for (final chunk in response) {
        sink.add(chunk);
        received += chunk.length;
        if (expected > 0 && onProgress != null) {
          onProgress((received / expected).clamp(0.0, 1.0).toDouble());
        }
      }
    } finally {
      await sink.flush();
      await sink.close();
    }

    if (received == 0) {
      throw const UpdateException('The downloaded update file was empty.');
    }
    onProgress?.call(1.0);
    return file;
  } catch (e) {
    if (await file.exists()) {
      try {
        await file.delete();
      } catch (_) {}
    }
    rethrow;
  } finally {
    client.close(force: true);
  }
}

/// User-facing description of an update failure.
String describeUpdateError(Object error) {
  if (error is UpdateException) return error.message;
  if (error is SocketException) {
    return 'Could not reach the update server. Check your connection and try again.';
  }
  if (error is HttpException) {
    return 'The update server returned an error. Try again shortly.';
  }
  if (error is FormatException) {
    return 'The update feed could not be read.';
  }
  return 'Update failed: $error';
}
