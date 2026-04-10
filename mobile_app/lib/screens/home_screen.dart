import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';
import '../models/advisor_response.dart';
import '../screens/developers_screen.dart';
import '../screens/privacy_policy_screen.dart';
import '../theme.dart';
import '../widgets/advice_panel_widgets.dart';
import '../widgets/domain_card.dart';
import '../widgets/growth_card.dart';
import '../widgets/viz_numbers_card.dart';
import '../widgets/insights_chart_cards.dart';
import '../widgets/idea_comparison_card.dart';

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
  final _titleBController = TextEditingController();
  final _abstractBController = TextEditingController();
  final _scrollController = ScrollController();
  final _resultsKey = GlobalKey();

  bool _isLoading = false;
  AdvisorResponse? _result;
  AdvisorResponse? _compareIdeaB;
  String _compareVerdict = '';
  bool _enableCompare = false;
  String? _error;
  /// Web: .result-tabs — Overview, Trends, Insights, Similar Papers
  int _adviceTabIndex = 0;

  @override
  void dispose() {
    _titleController.dispose();
    _abstractController.dispose();
    _titleBController.dispose();
    _abstractBController.dispose();
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
    final abstractA = _abstractController.text.trim();
    if (title.isEmpty || abstractA.isEmpty) {
      setState(() => _error =
          'Please enter title and abstract for Idea A (both are required by the API).');
      return;
    }

    if (_enableCompare) {
      final titleB = _titleBController.text.trim();
      final abstractB = _abstractBController.text.trim();
      if (titleB.isEmpty || abstractB.isEmpty) {
        setState(() => _error =
            'Please provide both title and abstract for Idea B.');
        return;
      }
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _isLoading = true;
      _error = null;
      _result = null;
      _compareIdeaB = null;
      _compareVerdict = '';
    });

    try {
      if (_enableCompare) {
        final cmp = await ApiService.compareIdeas(
          titleA: title,
          abstractA: abstractA,
          titleB: _titleBController.text.trim(),
          abstractB: _abstractBController.text.trim(),
        );
        setState(() {
          _result = cmp.ideaAResult;
          _compareIdeaB = cmp.ideaBResult;
          _compareVerdict = cmp.finalVerdict;
          _isLoading = false;
          _adviceTabIndex = 0;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Comparison complete.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } else {
        final result = await ApiService.getAdvice(
          title: title,
          abstract_: abstractA,
        );
        setState(() {
          _result = result;
          _isLoading = false;
          _adviceTabIndex = 0;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Done.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
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
                  await _launchAppSpecificBrowser(chromeUri);
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
                  await _launchAppSpecificBrowser(firefoxUri);
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

  /// Chrome/Firefox custom schemes throw [PlatformException] if the app is not installed.
  Future<void> _launchAppSpecificBrowser(Uri schemeUri) async {
    try {
      final launched = await launchUrl(
        schemeUri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) await _launchDefaultBrowser();
    } catch (_) {
      await _launchDefaultBrowser();
    }
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

  void _openDevelopersScreen() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const DevelopersScreen(),
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
    final mq = MediaQuery.of(context);
    final screenWidth = mq.size.width;
    final isTabletWidth = screenWidth >= 768;
    // Web: .page max-width 560px; horizontal max(1.5rem, safe-area)
    final maxContentWidth = isTabletWidth ? 600.0 : 560.0;
    final minGutter = isTabletWidth ? 64.0 : 24.0;
    final scrollBottomPad = 100.0 + mq.padding.bottom;

    return Scaffold(
      bottomNavigationBar: _buildFooterBar(),
      body: SafeArea(
        minimum: EdgeInsets.only(
          top: 48,
          left: minGutter,
          right: minGutter,
        ),
        bottom: false,
        child: SingleChildScrollView(
          controller: _scrollController,
          // Align top-center — never use Center here: unbounded height breaks Column layout.
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxContentWidth),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                    // Header (web: padding-top already max(3rem, safe) via SafeArea.minimum)
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
                    // Web: 6.25rem + safe-area below last content (fixed footer)
                    SizedBox(height: scrollBottomPad),
                  ],
                ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Web: clamp(2rem, 5vw, 2.75rem) for .title
        final w = constraints.maxWidth;
        final titleSize = (w * 0.05).clamp(32.0, 44.0);
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
                  fontSize: titleSize,
                  fontWeight: FontWeight.w700,
                  height: 1.15,
                  letterSpacing: -0.03 * titleSize,
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
      },
    );
  }

  Widget _buildForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'IDEA A',
          style: GoogleFonts.outfit(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.06 * 12.5,
            color: AppColors.textMuted,
          ),
        ),
        const SizedBox(height: 10),
        // Title label
        const _FieldLabel('Title'),
        const SizedBox(height: 6),
        TextField(
          controller: _titleController,
          style: const TextStyle(color: AppColors.text, fontSize: 16),
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
          style: const TextStyle(color: AppColors.text, fontSize: 16),
          decoration: const InputDecoration(
            hintText: 'Paste or type your abstract...',
          ),
          maxLines: 5,
          minLines: 4,
          textInputAction: TextInputAction.done,
        ),
        const SizedBox(height: 16),
        InkWell(
          onTap: () => setState(() => _enableCompare = !_enableCompare),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  width: 22,
                  height: 22,
                  child: Checkbox(
                    value: _enableCompare,
                    onChanged: (v) =>
                        setState(() => _enableCompare = v ?? false),
                    activeColor: AppColors.accent,
                    checkColor: AppColors.bg,
                    side: const BorderSide(color: AppColors.border),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Add Idea B for comparison',
                    style: GoogleFonts.outfit(
                      fontSize: 14.1,
                      color: AppColors.textMuted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_enableCompare) ...[
          const SizedBox(height: 16),
          Container(height: 1, color: AppColors.border),
          const SizedBox(height: 16),
          Text(
            'IDEA B (FOR COMPARISON)',
            style: GoogleFonts.outfit(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.06 * 12.5,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 10),
          const _FieldLabel('Title'),
          const SizedBox(height: 6),
          TextField(
            controller: _titleBController,
            style: const TextStyle(color: AppColors.text, fontSize: 16),
            decoration: const InputDecoration(
              hintText: 'e.g. Sparse Foundation Models for Edge Devices',
            ),
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 20),
          const _FieldLabel('Abstract'),
          const SizedBox(height: 6),
          TextField(
            controller: _abstractBController,
            style: const TextStyle(color: AppColors.text, fontSize: 16),
            decoration: const InputDecoration(
              hintText: 'Paste or type abstract for Idea B...',
            ),
            maxLines: 5,
            minLines: 4,
            textInputAction: TextInputAction.done,
          ),
        ],
        const SizedBox(height: 20),
        LayoutBuilder(
          builder: (context, c) {
            final narrow = c.maxWidth < 400;
            final stackExamples = c.maxWidth <= 560;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _PrimaryButton(
                  label: _enableCompare
                      ? 'Run analysis / compare'
                      : 'Run analysis',
                  isLoading: _isLoading,
                  expand: narrow,
                  onPressed: _isLoading ? null : _submit,
                ),
                const SizedBox(height: 10),
                if (stackExamples)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _ExampleButton(
                        label: 'Eg 1 — Transformers',
                        expand: true,
                        onPressed: () => _fillExample(1),
                      ),
                      const SizedBox(height: 10),
                      _ExampleButton(
                        label: 'Eg 2 — NeRF',
                        expand: true,
                        onPressed: () => _fillExample(2),
                      ),
                    ],
                  )
                else
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _ExampleButton(
                        label: 'Eg 1 — Transformers',
                        onPressed: () => _fillExample(1),
                      ),
                      _ExampleButton(
                        label: 'Eg 2 — NeRF',
                        onPressed: () => _fillExample(2),
                      ),
                    ],
                  ),
              ],
            );
          },
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
              text: 'Run analysis',
              style: TextStyle(
                  color: AppColors.text, fontWeight: FontWeight.w600),
            ),
            const TextSpan(
                text:
                    ' to analyze Idea A. Enable “Add Idea B” and use '),
            const TextSpan(
              text: 'Run analysis / compare',
              style: TextStyle(
                  color: AppColors.text, fontWeight: FontWeight.w600),
            ),
            const TextSpan(text: ' to compare two ideas. Click '),
            const TextSpan(
              text: 'Eg 1 — Transformers',
              style: TextStyle(
                  color: AppColors.text, fontWeight: FontWeight.w600),
            ),
            const TextSpan(text: ' or '),
            const TextSpan(
              text: 'Eg 2 — NeRF',
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
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 16),
      child: Row(
        children: [
          const CupertinoActivityIndicator(
            radius: 6,
            color: AppColors.accent,
          ),
          const SizedBox(width: 10),
          Text(
            _enableCompare ? 'Comparing ideas…' : 'Calling advisor…',
            style: const TextStyle(fontSize: 14, color: AppColors.textMuted),
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
    // Comparison: single card only (web-style compare focus).
    if (_compareIdeaB != null) {
      return Column(
        key: _resultsKey,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          IdeaComparisonCard(
            ideaA: r,
            ideaB: _compareIdeaB!,
            finalVerdict: _compareVerdict,
          ),
        ],
      );
    }

    return Column(
      key: _resultsKey,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        Text(
          'Advice',
          style: GoogleFonts.syne(
            fontSize: 17.6,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.02 * 17.6,
            color: AppColors.textMuted,
          ),
        ),
        const SizedBox(height: 16),
        _buildAdviceTabBar(),
        const SizedBox(height: 12),
        _buildAdviceTabContent(r),
      ],
    );
  }

  static const _adviceTabLabels = [
    'Overview',
    'Trends',
    'Insights',
    'Similar Papers',
  ];

  Widget _buildAdviceTabBar() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Container(
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
          color: Colors.white.withValues(alpha: 0.03),
        ),
        child: Row(
          children: List.generate(_adviceTabLabels.length, (i) {
            final active = _adviceTabIndex == i;
            return Padding(
              padding: EdgeInsets.only(
                right: i < _adviceTabLabels.length - 1 ? 5 : 0,
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => setState(() => _adviceTabIndex = i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      gradient: active
                          ? const LinearGradient(
                              colors: [AppColors.accent, Color(0xFF26A89A)],
                            )
                          : null,
                      border: Border.all(
                        color: active
                            ? Colors.white.withValues(alpha: 0.18)
                            : Colors.transparent,
                      ),
                    ),
                    child: Text(
                      _adviceTabLabels[i],
                      style: GoogleFonts.outfit(
                        fontSize: 13.1,
                        fontWeight: FontWeight.w600,
                        color: active ? AppColors.bg : AppColors.textMuted,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildAdviceTabContent(AdvisorResponse r) {
    switch (_adviceTabIndex) {
      case 0:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AdviceOverviewCard(result: r),
          ],
        );
      case 1:
        return _buildTrendsTab(r);
      case 2:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DomainCard(result: r),
            const SizedBox(height: 16),
            AdviceNarrativeCard(result: r),
          ],
        );
      case 3:
        return SimilarPapersCard(result: r);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildTrendsTab(AdvisorResponse r) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'TRENDS',
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
            final isMobile = constraints.maxWidth < 380;
            final confidenceCard = ChartConfidenceCard(result: r);
            final growthScoreCard = ChartGrowthCard(result: r);
            final confidenceVsGrowthCard = SizedBox(
              height: 260,
              child: ChartScatterCard(result: r),
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
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: confidenceCard),
                      const SizedBox(width: 12),
                      Expanded(child: growthScoreCard),
                    ],
                  ),
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
        GrowthCard(result: r),
      ],
    );
  }

  Widget _buildFooterBar() {
    final mq = MediaQuery.of(context);
    final bottomInset = math.max(12.0, mq.padding.bottom);
    final leftInset = math.max(16.0, mq.padding.left);
    final rightInset = math.max(16.0, mq.padding.right);
    return Material(
      color: const Color(0xFF0A0B0F).withValues(alpha: 0.88),
      child: Container(
        padding: EdgeInsets.fromLTRB(leftInset, 12, rightInset, bottomInset),
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: Colors.white.withValues(alpha: 0.04)),
          ),
        ),
        // Bounded height so Scaffold does not give the bar unbounded height (links looked "centered" on full screen).
        child: SizedBox(
          height: 48,
          child: Center(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _FooterLink(label: 'Developers', onTap: _openDevelopersScreen),
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
  final bool expand;
  final VoidCallback? onPressed;

  const _PrimaryButton({
    required this.label,
    required this.isLoading,
    this.expand = false,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final child = Container(
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
                ? const Center(
                    child: CupertinoActivityIndicator(
                      radius: 7,
                      color: AppColors.bg,
                    ),
                  )
                : Center(
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.syne(
                        color: AppColors.bg,
                        fontWeight: FontWeight.w600,
                        fontSize: 15.2,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
          ),
        ),
      ),
    );
    if (expand) {
      return SizedBox(width: double.infinity, child: child);
    }
    return child;
  }
}

class _ExampleButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final bool expand;

  const _ExampleButton({
    required this.label,
    required this.onPressed,
    this.expand = false,
  });

  @override
  Widget build(BuildContext context) {
    final btn = OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.text,
        backgroundColor: AppColors.surface,
        side: const BorderSide(color: AppColors.border),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        minimumSize: expand ? const Size(double.infinity, 44) : null,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
      ),
      child: Text(label, textAlign: TextAlign.center),
    );
    if (expand) {
      return SizedBox(width: double.infinity, child: btn);
    }
    return btn;
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
