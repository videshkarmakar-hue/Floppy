import 'dart:convert';
import 'dart:io';

import 'package:floppy/services/update_service.dart';
import 'package:flutter_test/flutter_test.dart';

String _releaseJson({
  required String tag,
  required List<Map<String, dynamic>> assets,
  bool draft = false,
  bool prerelease = false,
  String body = '- Faster thumbnails',
}) {
  return jsonEncode([
    {
      'tag_name': tag,
      'name': 'Floppy $tag',
      'draft': draft,
      'prerelease': prerelease,
      'published_at': '2026-11-20T10:00:00Z',
      'body': body,
      'assets': assets,
    },
  ]);
}

class _TestFeed {
  final HttpServer server;
  _TestFeed(this.server);

  Uri get feedUri => Uri.parse('http://127.0.0.1:${server.port}/releases');

  Future<void> close() => server.close(force: true);
}

Future<_TestFeed> _startFeed(
  String Function(Uri base) buildJson, {
  List<int> apkBytes = const [],
}) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  final base = Uri.parse('http://127.0.0.1:${server.port}');
  final releasesJson = buildJson(base);

  server.listen((request) async {
    final response = request.response;
    if (request.uri.path == '/releases') {
      response.headers.contentType = ContentType.json;
      response.write(releasesJson);
    } else if (request.uri.path == '/apk') {
      response.headers.contentType =
          ContentType('application', 'vnd.android.package-archive');
      response.contentLength = apkBytes.length;
      response.add(apkBytes);
    } else {
      response.statusCode = HttpStatus.notFound;
    }
    await response.close();
  });

  return _TestFeed(server);
}

void main() {
  group('compareVersions', () {
    test('compares numeric segments and ignores the tag prefix', () {
      expect(compareVersions('v3.0.1', '3.0.0'), 1);
      expect(compareVersions('3.0.0', 'v3.0.0'), 0);
      expect(compareVersions('3.0.0', '3.0.10'), -1);
      expect(compareVersions('3.1', '3.1.0'), 0);
      expect(compareVersions('3.0.0+3000', '3.0.0'), 0);
    });
  });

  group('parseReleases', () {
    test('picks the APK asset of a published release', () {
      final releases = parseReleases(_releaseJson(
        tag: 'v3.0.1',
        assets: [
          {
            'name': 'checksums.txt',
            'size': 40,
            'browser_download_url': 'https://example.com/checksums.txt',
          },
          {
            'name': 'Floppy-3.0.1-arm64-v8a.apk',
            'size': 2048,
            'browser_download_url':
                'https://example.com/Floppy-3.0.1-arm64-v8a.apk',
          },
        ],
      ));

      expect(releases, hasLength(1));
      expect(releases.single.version, '3.0.1');
      expect(releases.single.hasDirectApk, isTrue);
      expect(releases.single.apkName, 'Floppy-3.0.1-arm64-v8a.apk');
      expect(releases.single.apkSize, 2048);
    });

    test('keeps every APK asset and selects the split matching the device ABI', () {
      final release = parseReleases(_releaseJson(
        tag: 'v3.0.4',
        assets: [
          {
            'name': 'Floppy-v3.0.4-armeabi-v7a.apk',
            'size': 10,
            'browser_download_url': 'https://example.com/v7a.apk',
          },
          {
            'name': 'Floppy-v3.0.4-arm64-v8a.apk',
            'size': 20,
            'browser_download_url': 'https://example.com/arm64.apk',
          },
          {
            'name': 'Floppy-v3.0.4-x86_64.apk',
            'size': 30,
            'browser_download_url': 'https://example.com/x86.apk',
          },
        ],
      )).single;

      expect(release.apks, hasLength(3));
      expect(release.selectApk(['arm64-v8a', 'armeabi-v7a'])!.name, contains('arm64-v8a'));
      expect(release.selectApk(['armeabi-v7a'])!.name, contains('armeabi-v7a'));
      expect(release.selectApk(['x86_64'])!.name, contains('x86_64'));
      // An unknown ABI still resolves to a real APK instead of failing.
      expect(release.selectApk(['mips64'])!.name, isNotEmpty);
    });

    test('ignores drafts and pre-releases', () {
      final body = jsonEncode([
        {'tag_name': 'v3.1.0', 'draft': true, 'prerelease': false, 'assets': []},
        {'tag_name': 'v4.0.0', 'draft': false, 'prerelease': true, 'assets': []},
        {'tag_name': 'v3.0.1', 'draft': false, 'prerelease': false, 'assets': []},
      ]);

      final releases = parseReleases(body);
      expect(releases, hasLength(1));
      expect(releases.single.tagName, 'v3.0.1');
    });

    test('exposes no download when the release has no APK asset', () {
      final releases = parseReleases(_releaseJson(
        tag: 'v3.0.2',
        assets: [
          {
            'name': 'source.zip',
            'size': 10,
            'browser_download_url': 'https://example.com/source.zip',
          },
        ],
      ));

      expect(releases.single.hasDirectApk, isFalse);
      expect(releases.single.apkUrl, isNull);
    });

    test('pickLatest returns the highest version', () {
      final releases = [
        const AppRelease(tagName: 'v3.0.1', version: '3.0.1'),
        const AppRelease(tagName: 'v3.0.10', version: '3.0.10'),
        const AppRelease(tagName: 'v3.0.2', version: '3.0.2'),
      ];
      expect(pickLatest(releases)!.version, '3.0.10');
    });
  });

  group('checkForUpdate', () {
    test('detects a newer release that ships an APK', () async {
      final bytes = List<int>.generate(4096, (index) => index % 251);
      final feed = await _startFeed(
        (base) => _releaseJson(
          tag: 'v3.0.1',
          assets: [
            {
              'name': 'Floppy-3.0.1.apk',
              'size': bytes.length,
              'browser_download_url': base.resolve('/apk').toString(),
            },
          ],
        ),
        apkBytes: bytes,
      );
      addTearDown(feed.close);

      final result = await checkForUpdate(feed: feed.feedUri, currentVersion: '3.0.0');

      expect(result.updateAvailable, isTrue);
      expect(result.latest!.version, '3.0.1');
      expect(result.latest!.hasDirectApk, isTrue);
    });

    test('reports no update when the installed build is current', () async {
      final feed = await _startFeed(
        (base) => _releaseJson(tag: 'v3.0.0', assets: const []),
      );
      addTearDown(feed.close);

      final result = await checkForUpdate(feed: feed.feedUri, currentVersion: '3.0.0');

      expect(result.updateAvailable, isFalse);
    });

    test('flags a newer release that has no APK asset', () async {
      final feed = await _startFeed(
        (base) => _releaseJson(
          tag: 'v3.0.2',
          assets: [
            {
              'name': 'release-notes.md',
              'size': 10,
              'browser_download_url': base.resolve('/notes.md').toString(),
            },
          ],
        ),
      );
      addTearDown(feed.close);

      final result = await checkForUpdate(feed: feed.feedUri, currentVersion: '3.0.0');

      expect(result.updateAvailable, isTrue);
      expect(result.latest!.hasDirectApk, isFalse);
      // Nothing to open in a browser: the UI shows an in-app message instead.
      expect(result.latest!.apkUrl, isNull);
    });
  });

  group('downloadReleaseApk', () {
    late Directory destination;

    setUp(() async {
      destination = await Directory.systemTemp.createTemp('floppy_update_test');
    });

    tearDown(() async {
      if (await destination.exists()) {
        await destination.delete(recursive: true);
      }
    });

    test('downloads the APK and reports progress', () async {
      final bytes = List<int>.generate(8192, (index) => index % 256);
      final feed = await _startFeed(
        (base) => _releaseJson(
          tag: 'v3.0.1',
          assets: [
            {
              'name': 'Floppy-3.0.1.apk',
              'size': bytes.length,
              'browser_download_url': base.resolve('/apk').toString(),
            },
          ],
        ),
        apkBytes: bytes,
      );
      addTearDown(feed.close);

      final result = await checkForUpdate(feed: feed.feedUri, currentVersion: '3.0.0');

      var progress = 0.0;
      final file = await downloadReleaseApk(
        result.latest!,
        onProgress: (value) => progress = value,
        destination: destination,
      );

      expect(file.path, endsWith('Floppy-3.0.1.apk'));
      expect(await file.readAsBytes(), equals(bytes));
      expect(progress, 1.0);
    });

    test('refuses to download when the release has no APK asset', () async {
      const release = AppRelease(tagName: 'v3.0.2', version: '3.0.2');

      await expectLater(
        downloadReleaseApk(release, destination: destination),
        throwsA(isA<UpdateException>().having(
          (error) => error.message,
          'message',
          kNoDirectDownloadMessage,
        )),
      );
    });
  });
}
