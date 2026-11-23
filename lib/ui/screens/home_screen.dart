import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/file_manager_provider.dart';
import '../../providers/media_provider.dart';
import '../../core/icon_fonts/broken_icons.dart';
import '../widgets/swipable_storage_overview.dart';
import '../widgets/quick_categories_grid.dart';
import '../widgets/recent_files_section.dart';
import '../widgets/nfile_drawer.dart';
import '../widgets/nfile_icon.dart';
import 'directory_screen.dart';
import 'more_settings_screen.dart';

class HomeScreen extends StatefulWidget {
  final VoidCallback toggleTheme;
  const HomeScreen({super.key, required this.toggleTheme});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

// TickerProviderStateMixin (not the Single... variant): this state drives two
// AnimationControllers, and a SingleTickerProvider can only hand out one ticker.
class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver, TickerProviderStateMixin {
  int _currentIndex = 0;
  DateTime? _lastBrowseTapTime;
  DateTime? _lastPressedAt;
  late AnimationController _refreshIconController;
  late AnimationController _settingsIconController;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshIconController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
    _settingsIconController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    _currentIndex = context.read<FileManagerProvider>().defaultToBrowseScreen ? 1 : 0;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MediaProvider>().loadMedia();
    });
  }

  @override
  void dispose() {
    _refreshIconController.dispose();
    _settingsIconController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      context.read<MediaProvider>().refreshMediaBackground();
    }
  }

  Future<void> _handleRefresh() async {
    if (_isRefreshing) return;
    setState(() {
      _isRefreshing = true;
    });
    _refreshIconController.repeat();
    try {
      await Future.wait([
        context.read<FileManagerProvider>().updateStorageSpace(),
        context.read<MediaProvider>().loadMedia(forceRefresh: true),
      ]);
    } catch (_) {
    } finally {
      if (mounted) {
        _refreshIconController.stop();
        setState(() {
          _isRefreshing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Dashboard refreshed successfully'),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 1),
          ),
        );
      }
    }
  }

  void _showExitConfirmationDialog(BuildContext context) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Exit Confirmation',
      barrierColor: Colors.black.withOpacity(0.5),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, anim1, anim2) {
        return const SizedBox.shrink();
      },
      transitionBuilder: (context, anim1, anim2, child) {
        final theme = Theme.of(context);
        return ScaleTransition(
          scale: CurvedAnimation(parent: anim1, curve: Curves.easeOutBack),
          child: FadeTransition(
            opacity: anim1,
            child: PopScope(
              canPop: false,
              onPopInvoked: (didPop) {
                if (didPop) return;
                SystemNavigator.pop();
              },
              child: AlertDialog(
                backgroundColor: theme.colorScheme.surface,
                elevation: 10,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                title: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.errorContainer.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: FloppyIcon(
                        Broken.logout,
                        color: theme.colorScheme.error,
                        size: 32,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Exit Application',
                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                content: const Text(
                  'Are you sure you want to exit? Press back again or tap Exit to close the app.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 15, height: 1.4),
                ),
                actionsAlignment: MainAxisAlignment.spaceEvenly,
                actionsPadding: const EdgeInsets.only(bottom: 20, left: 16, right: 16),
                actions: [
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.error,
                      foregroundColor: theme.colorScheme.onError,
                      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    onPressed: () => SystemNavigator.pop(),
                    child: const Text('Exit', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FileManagerProvider>();
    final theme = Theme.of(context);
    final canPopHomeScreen = _currentIndex == 1 && !provider.isSelectionMode && provider.canGoBack;

    return PopScope(
      canPop: canPopHomeScreen,
      onPopInvoked: (didPop) {
        if (didPop) return;
        if (_currentIndex == 1) {
          if (!provider.canGoBack) {
            setState(() {
              _currentIndex = 0;
            });
            context.read<MediaProvider>().refreshMediaBackground();
          }
        } else {
          if (provider.exitOption == 'double_press') {
            final now = DateTime.now();
            if (_lastPressedAt == null || now.difference(_lastPressedAt!) > const Duration(seconds: 2)) {
              _lastPressedAt = now;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text(
                    'Press back again to exit',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                  backgroundColor: theme.colorScheme.primary,
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 2),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              );
            } else {
              SystemNavigator.pop();
            }
          } else {
            _showExitConfirmationDialog(context);
          }
        }
      },
      child: Scaffold(
        drawer: FloppyDrawer(
          toggleTheme: widget.toggleTheme,
          onNavigateTab: (index) => setState(() => _currentIndex = index),
        ),
        body: IndexedStack(
          index: _currentIndex,
          children: [
            _buildHomeTab(),
            DirectoryScreen(
              toggleTheme: widget.toggleTheme,
              onNavigateTab: (index) => setState(() => _currentIndex = index),
            ),
            const MoreSettingsScreen(embedded: true),
          ],
        ),
        bottomNavigationBar: provider.showHomeBrowseNav
            ? NavigationBar(
                height: provider.hideNavLabels ? 66.0 : null,
                labelBehavior: provider.hideNavLabels
                    ? NavigationDestinationLabelBehavior.alwaysHide
                    : null,
                selectedIndex: _currentIndex,
                onDestinationSelected: (index) {
                  if (index == 0) {
                    context.read<MediaProvider>().refreshMediaBackground();
                  } else if (index == 1) {
                    final now = DateTime.now();
                    if (_currentIndex == 1 && _lastBrowseTapTime != null && now.difference(_lastBrowseTapTime!) < const Duration(milliseconds: 800)) {
                      provider.loadDirectory(provider.rootPath);
                    }
                    _lastBrowseTapTime = now;
                  }
                  setState(() => _currentIndex = index);
                },
                destinations: [
                  NavigationDestination(
                    icon: FloppyIcon(Broken.home),
                    selectedIcon: FloppyIcon(Broken.home_1),
                    label: 'Home',
                  ),
                  NavigationDestination(
                    icon: FloppyIcon(Broken.folder),
                    selectedIcon: FloppyIcon(Broken.folder_open),
                    label: 'Browse',
                  ),
                  NavigationDestination(
                    icon: RotationTransition(
                      turns: Tween(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _settingsIconController, curve: Curves.elasticIn)),
                      child: const FloppyIcon(Broken.settings),
                    ),
                    label: 'Settings',
                  ),
                ],
              )
            : null,
      ),
    );
  }

  Widget _buildHomeTab() {
    final theme = Theme.of(context);
    return SafeArea(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'My Files',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        onPressed: _handleRefresh,
                        tooltip: 'Refresh Dashboard',
                        icon: RotationTransition(
                          turns: _refreshIconController,
                          child: const FloppyIcon(Broken.refresh),
                        ),
                      ),
                      IconButton(
                        onPressed: widget.toggleTheme,
                        icon: FloppyIcon(
                          theme.brightness == Brightness.dark ? Broken.sun_1 : Broken.moon,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SwipableStorageOverview(
              onBrowseVolume: (path) {
                final provider = context.read<FileManagerProvider>();
                provider.loadDirectory(path);
                setState(() => _currentIndex = 1);
              },
            ),
            const SizedBox(height: 8),
            QuickCategoriesGrid(
              onNavigateTab: (index) => setState(() => _currentIndex = index),
            ),
            const SizedBox(height: 8),
            RecentFilesSection(
              onNavigateTab: (index) => setState(() => _currentIndex = index),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
