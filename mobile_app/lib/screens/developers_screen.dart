import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'home_screen.dart';
import '../theme.dart';

class DevelopersScreen extends StatelessWidget {
  const DevelopersScreen({super.key});

  static const List<_Developer> _developers = [
    _Developer(
      name: 'Jayashree Johnson',
      imageUrl: 'https://github.com/jayashreejohnson.png',
      githubUrl: 'https://github.com/jayashreejohnson',
      linkedInUrl: 'https://www.linkedin.com/in/jayashreejohnson/',
    ),
    _Developer(
      name: 'Kamal Domandula',
      imageUrl: 'https://github.com/kamaldomandula.png',
      githubUrl: 'https://github.com/kamaldomandula',
      linkedInUrl: 'https://www.linkedin.com/in/kamaldomandula/',
    ),
    _Developer(
      name: 'Kethan Dosapati',
      imageUrl: 'https://github.com/dkethan.png',
      githubUrl: 'https://github.com/dkethan',
      linkedInUrl: 'https://www.linkedin.com/in/kethan-dosapati/',
    ),
  ];

  static final Uri _projectUrl =
      Uri.parse('https://github.com/dkethan/arxiv-trend-predictor');

  Future<void> _openExternal(
    BuildContext context, {
    required String url,
    required String fallbackMessage,
  }) async {
    final uri = Uri.parse(url);
    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) {
        await Clipboard.setData(ClipboardData(text: url));
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$fallbackMessage Copied to clipboard.')),
          );
        }
      }
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: url));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$fallbackMessage Copied to clipboard.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTabletWidth = screenWidth >= 768;
    final horizontalPadding = isTabletWidth ? 64.0 : 20.0;
    final maxContentWidth = isTabletWidth ? 600.0 : 680.0;

    return Scaffold(
      bottomNavigationBar: _buildFooterBar(context),
      appBar: AppBar(
        title: const Text('Developers'),
      ),
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(horizontalPadding, 16, horizontalPadding, 88),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxContentWidth),
              child: SizedBox(
                width: double.infinity,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Meet the developers who built arXiv Trend Advisor.',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ..._developers.map(
                      (developer) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _DeveloperCard(
                          developer: developer,
                          onOpenGithub: () => _openExternal(
                            context,
                            url: developer.githubUrl,
                            fallbackMessage: 'Could not open GitHub profile.',
                          ),
                          onOpenLinkedIn: () => _openExternal(
                            context,
                            url: developer.linkedInUrl,
                            fallbackMessage: 'Could not open LinkedIn profile.',
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Center(
                      child: Text(
                        'Developed with data and machine learning to help you explore how ideas trend on arXiv.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _openHome(BuildContext context) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const HomeScreen()),
      (route) => false,
    );
  }

  Widget _buildFooterBar(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(12, 0, 12, bottomInset),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated.withValues(alpha: 0.96),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.32),
            blurRadius: 16,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SizedBox(
        height: 56,
        child: Center(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _FooterLink(label: 'Back to Home', onTap: () => _openHome(context)),
                const _FooterDot(),
                _FooterLink(
                  label: 'Explore Full Project on GitHub',
                  onTap: () => _openExternal(
                    context,
                    url: _projectUrl.toString(),
                    fallbackMessage: 'Could not open project link.',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DeveloperCard extends StatelessWidget {
  final _Developer developer;
  final VoidCallback onOpenGithub;
  final VoidCallback onOpenLinkedIn;

  const _DeveloperCard({
    required this.developer,
    required this.onOpenGithub,
    required this.onOpenLinkedIn,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: appCardDecoration,
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 54,
            backgroundColor: AppColors.surfaceElevated,
            backgroundImage: NetworkImage(developer.imageUrl),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  developer.name,
                  style: const TextStyle(
                    color: AppColors.text,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Developer',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 10),
                const Divider(color: AppColors.border, height: 1),
                const SizedBox(height: 8),
                _IconActionLink(
                  icon: Icons.code_rounded,
                  label: 'GitHub Profile',
                  onTap: onOpenGithub,
                ),
                const SizedBox(height: 6),
                _IconActionLink(
                  icon: Icons.business_center_rounded,
                  label: 'LinkedIn Profile',
                  onTap: onOpenLinkedIn,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _IconActionLink extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _IconActionLink({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: AppColors.text,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.accent,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _FooterLink extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _FooterLink({
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          color: AppColors.accent,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _Developer {
  final String name;
  final String imageUrl;
  final String githubUrl;
  final String linkedInUrl;

  const _Developer({
    required this.name,
    required this.imageUrl,
    required this.githubUrl,
    required this.linkedInUrl,
  });
}

class _FooterDot extends StatelessWidget {
  const _FooterDot();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 6),
      child: Text(
        '·',
        style: TextStyle(
          fontSize: 13,
          color: AppColors.textMuted,
        ),
      ),
    );
  }
}
