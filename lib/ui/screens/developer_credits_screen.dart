import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/icon_fonts/broken_icons.dart';
import '../widgets/nfile_icon.dart';

/// Dedicated "Developer Credit" page reached from Settings.
class DeveloperCreditsScreen extends StatelessWidget {
  const DeveloperCreditsScreen({super.key});

  static const List<_CreditLink> _links = [
    _CreditLink(
      label: 'Official Website',
      detail: 'videshkarmakar.carrd.co',
      url: 'https://videshkarmakar.carrd.co',
      icon: Icons.public_rounded,
    ),
    _CreditLink(
      label: 'Spotify',
      detail: 'Videsh Karmakar — Artist Profile',
      url: 'https://open.spotify.com/search/Videsh%20Karmakar',
      icon: Icons.music_note_rounded,
    ),
    _CreditLink(
      label: 'Instagram',
      detail: '@code.red_videsh',
      url: 'https://www.instagram.com/code.red_videsh',
      icon: Icons.camera_alt_rounded,
    ),
    _CreditLink(
      label: 'YouTube',
      detail: '@videshkarmakar2000',
      url: 'https://www.youtube.com/@videshkarmakar2000',
      icon: Icons.play_circle_fill_rounded,
    ),
    _CreditLink(
      label: 'Facebook',
      detail: 'gfx.videsh',
      url: 'https://www.facebook.com/gfx.videsh',
      icon: Icons.facebook,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Developer Credit')),
      body: SafeArea(
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            _headerCard(theme),
            const SizedBox(height: 24),
            Text(
              'Floppy is proudly conceptualized, designed, and developed by '
              'Videsh Karmakar — bringing together software engineering, '
              'product design, and a passion for technology to create a refined '
              'and intuitive digital experience.',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontSize: 13.5,
                height: 1.55,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 28),
            _sectionTitle(theme, 'Connect with the Developer'),
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
              child: Column(
                children: [
                  for (var i = 0; i < _links.length; i++) ...[
                    _linkTile(context, theme, _links[i]),
                    if (i != _links.length - 1)
                      Divider(
                        height: 1,
                        thickness: 1,
                        indent: 56,
                        color: theme.colorScheme.outline.withValues(alpha: 0.08),
                      ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 28),
            _sectionTitle(theme, 'Development & Design'),
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
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _detailRow(theme, 'Product', 'Floppy'),
                    _detailRow(theme, 'Developed & Designed By', 'Videsh Karmakar'),
                    _detailRow(theme, 'Role', 'Founder · Developer · UI/UX Designer'),
                    _detailRow(theme, 'Design & Prototyping', 'Figma · Stitch'),
                    _detailRow(theme, 'Platform', 'Android · iOS coming soon'),
                    _detailRow(theme, 'Update Channel', 'GitHub Releases'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: theme.colorScheme.primary.withValues(alpha: 0.14),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FloppyIcon(
                    Broken.heart,
                    size: 18,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Built independently with a commitment to thoughtful '
                      'design, modern technology, and creating meaningful '
                      'digital experiences.\n\nThank you for being part of Floppy.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 12,
                        height: 1.5,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            Center(
              child: Column(
                children: [
                  Text(
                    'FLOPPY',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                      letterSpacing: 3,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Crafted With Vision. Built With Purpose.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: 11.5,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '© 2026 Videsh Karmakar',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: 11,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _headerCard(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  Color.alphaBlend(
                    theme.colorScheme.primary.withValues(alpha: 0.22),
                    const Color(0xFF181818),
                  ),
                  Color.alphaBlend(
                    theme.colorScheme.primary.withValues(alpha: 0.07),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: isDark ? 0.12 : 0.2),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                ),
                child: const Center(
                  child: FloppyIcon(Broken.user, color: Colors.white, size: 28),
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Videsh Karmakar',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Founder · Developer · UI/UX Designer',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            'Crafted With Vision. Built With Purpose.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.92),
              fontSize: 13.5,
              height: 1.4,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(ThemeData theme, String text) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(
            color: theme.colorScheme.primary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          text,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }

  Widget _linkTile(BuildContext context, ThemeData theme, _CreditLink link) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => _open(context, link),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(link.icon, size: 17, color: theme.colorScheme.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    link.label,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: 13.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    link.detail,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: 11.5,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.open_in_new_rounded,
              size: 16,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(ThemeData theme, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodySmall?.copyWith(
                fontSize: 12,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _open(BuildContext context, _CreditLink link) async {
    final uri = Uri.parse(link.url);
    try {
      if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
    } catch (_) {}
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open ${link.url}')),
      );
    }
  }
}

class _CreditLink {
  final String label;
  final String detail;
  final String url;
  final IconData icon;

  const _CreditLink({
    required this.label,
    required this.detail,
    required this.url,
    required this.icon,
  });
}
