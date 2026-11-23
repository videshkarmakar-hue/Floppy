import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/icon_fonts/broken_icons.dart';
import '../../providers/update_provider.dart';

/// The "App Update" slot.
///
/// Checks the GitHub releases feed and downloads + installs the new APK from
/// inside the app. It never opens the GitHub release page; releases without an
/// APK asset are reported in-app instead.
class AppUpdateSection extends StatelessWidget {
  const AppUpdateSection({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Consumer<UpdateProvider>(
      builder: (context, update, _) {
        return Container(
          margin: const EdgeInsets.only(top: 32, bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'APP UPDATE',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                height: 1,
                color: theme.colorScheme.outline.withOpacity(0.3),
                margin: const EdgeInsets.symmetric(vertical: 4),
              ),
              const SizedBox(height: 16),
              _buildContent(theme, update),
            ],
          ),
        );
      },
    );
  }

  Widget _buildContent(ThemeData theme, UpdateProvider update) {
    final body = theme.textTheme.bodyMedium?.copyWith(
      fontSize: 14,
      color: theme.colorScheme.onSurface.withOpacity(0.6),
      height: 1.4,
    );
    final small = theme.textTheme.bodySmall?.copyWith(
      fontSize: 12,
      color: theme.colorScheme.onSurface.withOpacity(0.5),
      height: 1.5,
    );

    if (update.isChecking) {
      return Row(
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(width: 12),
          Text('Checking for updates…', style: body),
        ],
      );
    }

    if (update.isUpToDate) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Broken.tick_circle, size: 18, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'You are on the latest version (v${update.currentVersion}).',
                  style: body,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _checkAgainButton(update),
        ],
      );
    }

    if (update.hasReleaseWithoutDirectDownload) {
      // A newer release exists but has no APK asset: explain that in-app and
      // never send the user to the GitHub release page.
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface.withOpacity(0.5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.colorScheme.outline.withOpacity(0.2)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Broken.information, size: 20, color: theme.colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("A direct download isn't available for this release.", style: body),
                      const SizedBox(height: 6),
                      Text(
                        'Version ${update.release!.version} was published without an APK attachment, so it cannot be installed from here.',
                        style: small,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          _checkAgainButton(update),
        ],
      );
    }

    if (update.updateAvailable && update.hasDirectApk) {
      final release = update.release!;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Version ${release.version} is available for Floppy', style: body),
          const SizedBox(height: 6),
          Text('You are on version ${update.currentVersion}.', style: small),
          if (release.notes.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              "What's new",
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              release.notes,
              style: small,
              maxLines: 6,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 20),
          if (update.isDownloading) ...[
            LinearProgressIndicator(
              value: update.status == UpdateStatus.installing ? null : update.progress,
              minHeight: 4,
              backgroundColor: theme.colorScheme.primary.withOpacity(0.12),
              color: theme.colorScheme.primary,
              borderRadius: const BorderRadius.all(Radius.circular(2)),
            ),
            const SizedBox(height: 8),
            Text(
              update.status == UpdateStatus.installing
                  ? 'Opening the package installer…'
                  : 'Downloading update… ${(update.progress * 100).round()}%',
              style: small,
            ),
          ] else
            _updateNowButton(update),
          if (update.error != null) ...[
            const SizedBox(height: 12),
            _errorMessage(theme, update.error!),
          ],
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (update.error != null) ...[
          _errorMessage(theme, update.error!),
          const SizedBox(height: 8),
        ] else
          Text('Check for a newer Floppy release and install it from here.', style: body),
        _checkAgainButton(update, label: update.error == null ? 'Check for updates' : 'Retry'),
      ],
    );
  }

  Widget _updateNowButton(UpdateProvider update) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: update.isDownloading ? null : update.downloadAndInstall,
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: const Text(
          'Update Now',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _checkAgainButton(UpdateProvider update, {String label = 'Check again'}) {
    return TextButton.icon(
      onPressed: update.isChecking || update.isDownloading ? null : update.check,
      icon: const Icon(Broken.refresh, size: 16),
      label: Text(label),
    );
  }

  Widget _errorMessage(ThemeData theme, String message) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Broken.warning_2, size: 16, color: theme.colorScheme.error),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            message,
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: 12,
              color: theme.colorScheme.error,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}
