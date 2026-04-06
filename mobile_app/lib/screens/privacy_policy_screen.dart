import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'home_screen.dart';
import '../theme.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  static final Uri _projectUrl =
      Uri.parse('https://github.com/dkethan/arxiv-trend-predictor');

  static const List<String> _contactEmails = [
    'jayjohnsonofficial@outlook.com',
    'kamaldinnu45@gmail.com',
    'kethandosapati@gmail.com',
  ];

  Future<void> _openEmail(BuildContext context, String email) async {
    final uri = Uri.parse('mailto:$email');
    try {
      final launched = await launchUrl(uri);
      if (!launched) {
        await Clipboard.setData(ClipboardData(text: email));
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not open email app. Email copied to clipboard.'),
            ),
          );
        }
      }
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: email));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open email app. Email copied to clipboard.'),
          ),
        );
      }
    }
  }

  Future<void> _openExternal(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) {
        await Clipboard.setData(ClipboardData(text: url));
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not open link. Copied to clipboard.'),
            ),
          );
        }
      }
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: url));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open link. Copied to clipboard.'),
          ),
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
        title: const Text('Privacy Policy'),
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
                child: Container(
                  decoration: appCardDecoration,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Effective date: March 19, 2026',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'This Privacy Policy explains how the arXiv Trend Advisor app handles information when you use it.',
                        style: TextStyle(color: AppColors.text, fontSize: 14, height: 1.5),
                      ),
                      const SizedBox(height: 14),
                      const _PolicyHeading(text: 'Information We Process'),
                      const _PolicyBody(
                        text:
                            'When you use the app, you may provide paper title and abstract text. This content is sent to our backend service to generate insights and returned for display.',
                      ),
                      const _PolicyHeading(text: 'Permissions'),
                      const _PolicyBody(
                        text:
                            'The Android app requests internet access so it can call the API. It does not intentionally request sensitive permissions such as camera, microphone, contacts, or location.',
                      ),
                      const _PolicyHeading(text: 'How We Use Information'),
                      const _PolicyBody(
                        text:
                            'Submitted content is used to run domain classification and trend analysis, return advisory results, and improve service reliability.',
                      ),
                      const _PolicyHeading(text: 'Contact'),
                      const Text(
                        'For privacy questions or requests:',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ..._contactEmails.map(
                        (email) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: GestureDetector(
                            onTap: () => _openEmail(context, email),
                            child: Text(
                              email,
                              style: const TextStyle(
                                color: AppColors.accent,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                decoration: TextDecoration.underline,
                              ),
                            ),
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
                onTap: () => _openExternal(context, _projectUrl.toString()),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PolicyHeading extends StatelessWidget {
  final String text;
  const _PolicyHeading({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4, top: 4),
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.text,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _PolicyBody extends StatelessWidget {
  final String text;
  const _PolicyBody({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.textMuted,
          fontSize: 13,
          height: 1.45,
        ),
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
