import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';
import '../models/advisor_response.dart';
import '../screens/creators_screen.dart';
import '../screens/privacy_policy_screen.dart';
import '../theme.dart';
import '../widgets/domain_card.dart';
import '../widgets/growth_card.dart';
import '../widgets/viz_numbers_card.dart';
import '../widgets/insights_chart_cards.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static final Uri _projectUrl =
      Uri.parse('https://github.com/dkethan/arxiv-trend-predictor');

  final _titleController = TextEditingController();
  final _abstractController = TextEditingController();
  final _scrollController = ScrollController();
  final _resultsKey = GlobalKey();

  bool _isLoading = false;
  AdvisorResponse? _result;
  String? _error;

  @override
  void dispose() {
    _titleController.dispose();
    _abstractController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _fillExample(int n) {
    if (n == 1) {
      _titleController.text =
          'Attention Is All You Need: Transformers for Sequence Modeling';
      _abstractController.text =
          'We propose a new architecture based entirely on self-attention mechanisms, dispensing with recurrence and convolutions. The Transformer achieves state-of-the-art results on machine translation and scales effectively to large datasets.';
    } else {
      _titleController.text =
          'Neural Radiance Fields for View Synthesis and 3D Reconstruction';
      _abstractController.text =
          'We present a method that represents a scene as a continuous 5D function and uses volume rendering to synthesize novel views. By optimizing a fully-connected neural network without convolutional layers, we achieve high-resolution photorealistic results.';
    }
  }

  Future<void> _submit() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      setState(() => _error = 'Please enter a title.');
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _isLoading = true;
      _error = null;
      _result = null;
    });

    try {
      final result = await ApiService.getAdvice(
        title: title,
        abstract_: _abstractController.text.trim(),
      );
      setState(() {
        _result = result;
        _isLoading = false;
      });
      // Scroll to results
      await Future.delayed(const Duration(milliseconds: 150));
      if (_resultsKey.currentContext != null) {
        Scrollable.ensureVisible(
          _resultsKey.currentContext!,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOut,
        );
      }
    } catch (e) {
      setState(() {
        _error = e.toString().contains('TimeoutException')
            ? 'Request timed out. The API may be waking up (free tier). Please try again.'
            : e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _openProjectLink() async {
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surfaceElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textMuted.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 10),
            const ListTile(
              title: Text(
                'Open Project Link',
                style: TextStyle(
                  color: AppColors.text,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(
                'Choose where to open',
                style: TextStyle(color: AppColors.textMuted),
              ),
            ),
            _openWithTile(
              icon: Icons.open_in_browser_rounded,
              label: 'Default browser',
              onTap: () async {
                Navigator.pop(context);
                await _launchDefaultBrowser();
              },
            ),
            if (Platform.isAndroid) ...[
              _openWithTile(
                icon: Icons.public,
                label: 'Chrome',
                onTap: () async {
                  Navigator.pop(context);
                  final chromeUri = Uri.parse(
                    'googlechrome://navigate?url=${Uri.encodeComponent(_projectUrl.toString())}',
                  );
                  final launched = await launchUrl(
                    chromeUri,
                    mode: LaunchMode.externalApplication,
                  );
                  if (!launched) await _launchDefaultBrowser();
                },
              ),
              _openWithTile(
                icon: Icons.travel_explore,
                label: 'Firefox',
                onTap: () async {
                  Navigator.pop(context);
                  final firefoxUri = Uri.parse(
                    'firefox://open-url?url=${Uri.encodeComponent(_projectUrl.toString())}',
                  );
                  final launched = await launchUrl(
                    firefoxUri,
                    mode: LaunchMode.externalApplication,
                  );
                  if (!launched) await _launchDefaultBrowser();
                },
              ),
            ],
            _openWithTile(
              icon: Icons.copy_rounded,
              label: 'Copy link',
              onTap: () async {
                Navigator.pop(context);
                await _copyProjectLinkWithMessage();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _openWithTile({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: AppColors.accent),
      title: Text(
        label,
        style: const TextStyle(color: AppColors.text),
      ),
      onTap: onTap,
    );
  }

  Future<void> _launchDefaultBrowser() async {
    try {
      final launched = await launchUrl(_projectUrl,
          mode: LaunchMode.externalApplication);
      if (!launched) {
        await _copyProjectLinkWithMessage();
      }
    } catch (_) {
      await _copyProjectLinkWithMessage();
    }
  }

  Future<void> _copyProjectLinkWithMessage() async {
    await Clipboard.setData(ClipboardData(text: _projectUrl.toString()));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Could not open browser here. GitHub link copied to clipboard.',
        ),
      ),
    );
  }

  void _openCreatorsScreen() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const CreatorsScreen(),
      ),
    );
  }

  void _openPrivacyPolicyScreen() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const PrivacyPolicyScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: _buildFooterBar(),
      body: SingleChildScrollView(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
        child: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),
              // Header
              _buildHeader(),
              const SizedBox(height: 32),
              // Form
              _buildForm(),
              const SizedBox(height: 8),
              _buildFormNote(),
              // Status
              if (_isLoading) _buildStatus(),
              // Error
              if (_error != null) _buildError(),
              // Results
              if (_result != null) _buildResults(),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.white, AppColors.textMuted],
          ).createShader(bounds),
          child: Text(
            'arXiv Trend Advisor',
            style: GoogleFonts.syne(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              height: 1.15,
              letterSpacing: -0.03 * 32,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'See where your idea fits and how it trends on arXiv.',
          style: GoogleFonts.outfit(
            color: AppColors.textMuted,
            fontSize: 16.8,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }

  Widget _buildForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title label
        const _FieldLabel('Title'),
        const SizedBox(height: 6),
        TextField(
          controller: _titleController,
          style: const TextStyle(color: AppColors.text, fontSize: 15),
          decoration: const InputDecoration(
            hintText: 'e.g. Neural Radiance Fields for View Synthesis',
          ),
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 20),
        // Abstract label
        const _FieldLabel('Abstract'),
        const SizedBox(height: 6),
        TextField(
          controller: _abstractController,
          style: const TextStyle(color: AppColors.text, fontSize: 15),
          decoration: const InputDecoration(
            hintText: 'Optional: paste or type your abstract...',
          ),
          maxLines: 5,
          minLines: 4,
          textInputAction: TextInputAction.done,
        ),
        const SizedBox(height: 20),
        // Buttons row
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _PrimaryButton(
              label: 'Get advice',
              isLoading: _isLoading,
              onPressed: _isLoading ? null : _submit,
            ),
            _ExampleButton(
              label: 'Ex 1 — Transformers',
              onPressed: () => _fillExample(1),
            ),
            _ExampleButton(
              label: 'Ex 2 — NeRF',
              onPressed: () => _fillExample(2),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFormNote() {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 16),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.textMuted,
            height: 1.5,
          ),
          children: [
            const TextSpan(text: 'Click '),
            const TextSpan(
              text: 'Get advice',
              style: TextStyle(
                  color: AppColors.text, fontWeight: FontWeight.w600),
            ),
            const TextSpan(text: ' to get advice. Click '),
            const TextSpan(
              text: 'Ex 1 — Transformers',
              style: TextStyle(
                  color: AppColors.text, fontWeight: FontWeight.w600),
            ),
            const TextSpan(text: ' or '),
            const TextSpan(
              text: 'Ex 2 — NeRF',
              style: TextStyle(
                  color: AppColors.text, fontWeight: FontWeight.w600),
            ),
            const TextSpan(
                text:
                    ' to fill the title and abstract automatically with an example.'),
          ],
        ),
      ),
    );
  }

  Widget _buildStatus() {
    return const Padding(
      padding: EdgeInsets.only(top: 8, bottom: 16),
      child: Row(
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.accent,
            ),
          ),
          SizedBox(width: 10),
          Text(
            'Calling advisor…',
            style: TextStyle(fontSize: 14, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.errorSoft,
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        _error!,
        style: const TextStyle(color: AppColors.error, fontSize: 14),
      ),
    );
  }

  Widget _buildResults() {
    final r = _result!;
    // Web: .result-inner padding 0.25rem 0 1.5rem; .card margin-bottom 1rem
    return Column(
      key: _resultsKey,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        // "Advice" heading (web: .result-heading — 1.1rem, margin 0 0 1.25rem)
        Text(
          'Advice',
          style: GoogleFonts.syne(
            fontSize: 17.6,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.02 * 17.6,
            color: AppColors.textMuted,
          ),
        ),
        const SizedBox(height: 20),

        // Insights block (web: .viz-section — first thing after heading)
        Text(
          'INSIGHTS',
          style: GoogleFonts.syne(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.08 * 12,
            color: AppColors.textMuted,
          ),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final isMobile = constraints.maxWidth < 600;
            final confidenceCard = ChartConfidenceCard(
              result: r,
            );
            final growthScoreCard = ChartGrowthCard(
              result: r,
            );
            final confidenceVsGrowthCard = SizedBox(
              height: 260,
              child: ChartScatterCard(
                result: r,
              ),
            );

            if (isMobile) {
              return Column(
                children: [
                  confidenceCard,
                  const SizedBox(height: 12),
                  growthScoreCard,
                  const SizedBox(height: 12),
                  confidenceVsGrowthCard,
                ],
              );
            }

            return Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: confidenceCard),
                    const SizedBox(width: 12),
                    Expanded(child: growthScoreCard),
                  ],
                ),
                const SizedBox(height: 12),
                confidenceVsGrowthCard,
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        VizNumbersCard(result: r),
        const SizedBox(height: 16),

        // Card 1: Domain (web: .domain-card)
        DomainCard(
          result: r,
        ),
        const SizedBox(height: 16),

        // Card 2: Growth (web: .growth-card)
        GrowthCard(
          result: r,
        ),
      ],
    );
  }

  Widget _buildFooterBar() {
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
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _FooterLink(label: 'Creators', onTap: _openCreatorsScreen),
                const _FooterDot(),
                _FooterLink(label: 'Project Link', onTap: _openProjectLink),
                const _FooterDot(),
                _FooterLink(
                  label: 'Privacy Policy',
                  onTap: _openPrivacyPolicyScreen,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Small local widgets ───

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: AppColors.textMuted,
        letterSpacing: 0.5,
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final bool isLoading;
  final VoidCallback? onPressed;

  const _PrimaryButton({
    required this.label,
    required this.isLoading,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        gradient: const LinearGradient(
          colors: [AppColors.accent, Color(0xFF26A89A)],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.accentSoft,
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 13),
            child: isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.bg,
                    ),
                  )
                : Text(
                    label,
                    style: const TextStyle(
                      color: AppColors.bg,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      letterSpacing: 0.3,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _ExampleButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const _ExampleButton({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.text,
        backgroundColor: AppColors.surface,
        side: const BorderSide(color: AppColors.border),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
      ),
      child: Text(label),
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
