import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'home_screen.dart';
import '../theme.dart';

class CreatorsScreen extends StatelessWidget {
  const CreatorsScreen({super.key});

  static const List<_Creator> _creators = [
    _Creator(
      name: 'Jayashree Johnson',
      imageUrl: 'https://github.com/jayashreejohnson.png',
      githubUrl: 'https://github.com/jayashreejohnson',
      linkedInUrl: 'https://www.linkedin.com/in/jayashreejohnson/',
    ),
    _Creator(
      name: 'Kamal Domandula',
      imageUrl: 'https://github.com/kamaldomandula.png',
      githubUrl: 'https://github.com/kamaldomandula',
      linkedInUrl: 'https://www.linkedin.com/in/kamaldomandula/',
    ),
    _Creator(
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
    return Scaffold(
      bottomNavigationBar: _buildFooterBar(context),
      appBar: AppBar(
        title: const Text('Creators'),
      ),
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 88),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Meet the contributors behind arXiv Trend Advisor.',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 14),
              ..._creators.map(
                (creator) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _CreatorCard(
                    creator: creator,
                    onOpenGithub: () => _openExternal(
                      context,
                      url: creator.githubUrl,
                      fallbackMessage: 'Could not open GitHub profile.',
                    ),
                    onOpenLinkedIn: () => _openExternal(
                      context,
                      url: creator.linkedInUrl,
                      fallbackMessage: 'Could not open LinkedIn profile.',
                    ),
                  ),
                ),
              ),
            ],
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
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _FooterLink(label: 'Home', onTap: () => _openHome(context)),
              const _FooterDot(),
              _FooterLink(
                label: 'Project Link',
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
    );
  }
}

class _CreatorCard extends StatelessWidget {
  final _Creator creator;
  final VoidCallback onOpenGithub;
  final VoidCallback onOpenLinkedIn;

  const _CreatorCard({
    required this.creator,
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
            radius: 32,
            backgroundColor: AppColors.surfaceElevated,
            backgroundImage: NetworkImage(creator.imageUrl),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  creator.name,
                  style: const TextStyle(
                    color: AppColors.text,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Contributor',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 10),
                _InlineActionLink(
                  label: 'GitHub Profile',
                  onTap: onOpenGithub,
                ),
                const SizedBox(height: 6),
                _InlineActionLink(
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

class _InlineActionLink extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _InlineActionLink({
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
          color: AppColors.accent,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _Creator {
  final String name;
  final String imageUrl;
  final String githubUrl;
  final String linkedInUrl;

  const _Creator({
    required this.name,
    required this.imageUrl,
    required this.githubUrl,
    required this.linkedInUrl,
  });
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
          fontSize: 13,
          color: AppColors.accent,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
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
