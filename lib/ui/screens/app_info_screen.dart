import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/icon_fonts/broken_icons.dart';
import '../widgets/nfile_icon.dart';
import 'app_updates_screen.dart';

/// Dedicated "App Info" page reached from Settings.
///
/// Every value is read from the running build (package_info_plus /
/// device_info_plus) instead of being hard-coded, so it always matches the
/// installed APK.
class AppInfoScreen extends StatefulWidget {
  const AppInfoScreen({super.key});

  @override
  State<AppInfoScreen> createState() => _AppInfoScreenState();
}

class _AppInfoScreenState extends State<AppInfoScreen> {
  PackageInfo? _packageInfo;
  AndroidDeviceInfo? _androidInfo;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      AndroidDeviceInfo? androidInfo;
      if (!kIsWeb && Platform.isAndroid) {
        try {
          androidInfo = await DeviceInfoPlugin().androidInfo;
        } catch (_) {}
      }
      if (!mounted) return;
      setState(() {
        _packageInfo = packageInfo;
        _androidInfo = androidInfo;
        _loadError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadError = 'Could not read app details: $e');
    }
  }

  List<_InfoEntry> get _entries {
    final info = _packageInfo;
    final android = _androidInfo;

    String platform = 'Unknown';
    if (!kIsWeb && Platform.isAndroid) {
      platform = android == null
          ? 'Android'
          : 'Android ${android.version.release} (API ${android.version.sdkInt})';
    } else if (!kIsWeb && Platform.isIOS) {
      platform = 'iOS';
    } else if (!kIsWeb) {
      platform = Platform.operatingSystem;
    }

    String device = '—';
    if (android != null) {
      final manufacturer = android.manufacturer;
      final model = android.model;
      device = '$manufacturer $model'.trim();
    }

    final dartVersion = Platform.version.split(' ').first;

    return [
      _InfoEntry('App Name', info?.appName ?? 'Floppy', Broken.mobile),
      _InfoEntry('Version', info?.version ?? '—', Broken.information),
      _InfoEntry('Build Number', info?.buildNumber ?? '—', Broken.code),
      _InfoEntry(
        'Package ID',
        info?.packageName ?? 'com.videshkarmakar.floppy',
        Broken.folder,
      ),
      _InfoEntry('Build Type', _buildType, Broken.setting_2),
      _InfoEntry('Platform', platform, Icons.android),
      _InfoEntry('Device', device, Broken.devices),
      _InfoEntry(
        'Architecture',
        android != null && android.supportedAbis.isNotEmpty
            ? android.supportedAbis.join(', ')
            : '—',
        Broken.cpu,
      ),
      _InfoEntry('Dart Runtime', dartVersion, Broken.code),
      _InfoEntry('Developer', 'Videsh Karmakar', Broken.user),
      _InfoEntry(
        'Update Source',
        'GitHub · videshkarmakar-hue/Floppy',
        Broken.global,
      ),
    ];
  }

  String get _buildType {
    if (kDebugMode) return 'Debug';
    if (kProfileMode) return 'Profile';
    return 'Release';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final info = _packageInfo;

    return Scaffold(
      appBar: AppBar(title: const Text('App Info')),
      body: SafeArea(
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            _header(theme, info),
            const SizedBox(height: 24),
            if (_loadError != null) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  _loadError!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            Text(
              'Build Details',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Card(
              elevation: 0,
              margin: EdgeInsets.zero,
              color: theme.colorScheme.surface.withValues(alpha: 0.4),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: theme.colorScheme.outline.withValues(alpha: 0.12),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Column(
                  children: [
                    for (var i = 0; i < _entries.length; i++) ...[
                      _row(theme, _entries[i]),
                      if (i != _entries.length - 1)
                        Divider(
                          height: 1,
                          color: theme.colorScheme.outline.withValues(alpha: 0.07),
                        ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _copyDetails(context),
                    icon: const Icon(Broken.copy, size: 16),
                    label: const Text('Copy details'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AppUpdatesScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Broken.refresh, size: 16),
                    label: const Text('Updates'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              'Floppy is built and maintained by Videsh Karmakar. Version '
              'information above is read directly from the installed package.',
              style: theme.textTheme.bodySmall?.copyWith(
                fontSize: 11.5,
                height: 1.5,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(ThemeData theme, PackageInfo? info) {
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  Color.alphaBlend(
                    theme.colorScheme.primary.withValues(alpha: 0.2),
                    const Color(0xFF181818),
                  ),
                  Color.alphaBlend(
                    theme.colorScheme.primary.withValues(alpha: 0.06),
                    const Color(0xFF0C0C0C),
                  ),
                ]
              : [
                  theme.colorScheme.primary,
                  theme.colorScheme.primary.withValues(alpha: 0.82),
                ],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: isDark ? 0.1 : 0.2),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Image.asset(
              'assets/logo/n.webp',
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const FloppyIcon(
                Broken.folder_2,
                color: Colors.white,
                size: 30,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Floppy',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  info == null
                      ? 'Reading version…'
                      : 'Version ${info.version} (${info.buildNumber})',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'A Beautiful File Manager',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(ThemeData theme, _InfoEntry entry) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            entry.icon,
            size: 17,
            color: theme.colorScheme.primary.withValues(alpha: 0.85),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                  ),
                ),
                const SizedBox(height: 2),
                SelectableText(
                  entry.value,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _copyDetails(BuildContext context) async {
    final buffer = StringBuffer('Floppy — App Info\n');
    for (final entry in _entries) {
      buffer.writeln('${entry.label}: ${entry.value}');
    }
    await Clipboard.setData(ClipboardData(text: buffer.toString()));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('App details copied to clipboard')),
    );
  }
}

class _InfoEntry {
  final String label;
  final String value;
  final IconData icon;

  const _InfoEntry(this.label, this.value, this.icon);
}
