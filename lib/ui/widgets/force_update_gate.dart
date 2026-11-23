import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/icon_fonts/broken_icons.dart';
import '../../providers/update_provider.dart';

/// Checks for updates when the app opens and blocks the UI with a
/// non-dismissible prompt while an installable update is pending.
///
/// The prompt has no close or skip action: back navigation is disabled and the
/// app content underneath stays covered until the update is installed.
class ForceUpdateGate extends StatefulWidget {
  final Widget child;

  const ForceUpdateGate({super.key, required this.child});

  @override
  State<ForceUpdateGate> createState() => _ForceUpdateGateState();
}

class _ForceUpdateGateState extends State<ForceUpdateGate> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<UpdateProvider>().check();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Re-check whenever the app comes back to the foreground, so a release
    // published later is picked up on the next app open/resume.
    if (state == AppLifecycleState.resumed && mounted) {
      context.read<UpdateProvider>().check();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<UpdateProvider>(
      builder: (context, update, _) {
        final blocking = update.isUpdateMandatory;
        return PopScope(
          canPop: !blocking,
          child: Stack(
            fit: StackFit.expand,
            children: [
              widget.child,
              if (blocking) _UpdateBlockingOverlay(update: update),
            ],
          ),
        );
      },
    );
  }
}

class _UpdateBlockingOverlay extends StatelessWidget {
  final UpdateProvider update;

  const _UpdateBlockingOverlay({required this.update});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final release = update.release!;

    return Material(
      color: theme.colorScheme.surface,
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(Broken.warning_2, size: 48, color: theme.colorScheme.primary),
                const SizedBox(height: 20),
                Text(
                  'Update required',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Floppy v${release.version} is available. You are on v${update.currentVersion}. '
                  'Install this update to keep using the app.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.7),
                    height: 1.4,
                  ),
                ),
                if (release.notes.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: theme.colorScheme.outline.withOpacity(0.2)),
                    ),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 160),
                      child: SingleChildScrollView(
                        child: Text(
                          release.notes,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontSize: 12,
                            color: theme.colorScheme.onSurface.withOpacity(0.6),
                            height: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                if (update.isDownloading) ...[
                  LinearProgressIndicator(
                    value: update.status == UpdateStatus.installing ? null : update.progress,
                    minHeight: 4,
                    backgroundColor: theme.colorScheme.primary.withOpacity(0.12),
                    color: theme.colorScheme.primary,
                    borderRadius: const BorderRadius.all(Radius.circular(2)),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    update.status == UpdateStatus.installing
                        ? 'Opening the package installer…'
                        : 'Downloading update… ${(update.progress * 100).round()}%',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                ] else
                  FilledButton(
                    onPressed: update.downloadAndInstall,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text(
                      'Update Now',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                if (update.error != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    update.error!,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.error,
                      height: 1.4,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
