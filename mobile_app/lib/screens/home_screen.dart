import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/advisor_response.dart';
import '../theme.dart';
import '../widgets/domain_card.dart';
import '../widgets/growth_card.dart';
import '../widgets/keywords_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
        child: SafeArea(
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
              const SizedBox(height: 40),
              // Footer
              _buildFooter(),
              const SizedBox(height: 24),
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
          child: const Text(
            'arXiv Trend\nAdvisor',
            style: TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w700,
              height: 1.15,
              letterSpacing: -1.0,
              color: Colors.white, // needed for ShaderMask
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'See where your idea fits and how it trends on arXiv.',
          style: TextStyle(
            color: AppColors.textMuted,
            fontSize: 15,
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
        text: const TextSpan(
          style: TextStyle(
            fontSize: 13,
            color: AppColors.textMuted,
            height: 1.5,
          ),
          children: [
            TextSpan(text: 'Click '),
            TextSpan(
              text: 'Get advice',
              style: TextStyle(
                  color: AppColors.text, fontWeight: FontWeight.w600),
            ),
            TextSpan(text: ' to get advice. Click '),
            TextSpan(
              text: 'Ex 1',
              style: TextStyle(
                  color: AppColors.text, fontWeight: FontWeight.w600),
            ),
            TextSpan(text: ' or '),
            TextSpan(
              text: 'Ex 2',
              style: TextStyle(
                  color: AppColors.text, fontWeight: FontWeight.w600),
            ),
            TextSpan(text: ' to fill with an example.'),
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
    return Column(
      key: _resultsKey,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        // "Advice" heading
        const Text(
          'Advice',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.3,
            color: AppColors.textMuted,
          ),
        ),
        const SizedBox(height: 16),

        // Domain card
        DomainCard(
          domain: r.domain,
          confidence: r.domainConfidence,
          alternateDomains: r.alternateDomains,
        ),
        const SizedBox(height: 12),

        // Growth card
        GrowthCard(
          label: r.domainGrowthLabel,
          score: r.domainGrowthScore,
        ),
        const SizedBox(height: 12),

        // Keywords card
        KeywordsCard(keywords: r.suggestedKeywords),
        const SizedBox(height: 16),

        // Message
        _buildMessage(r.message),
        const SizedBox(height: 16),

        // Disclaimer
        Text(
          r.disclaimer,
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.textMuted,
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }

  Widget _buildMessage(String message) {
    // Parse **bold** markers from API response
    final parts = <InlineSpan>[];
    final regex = RegExp(r'\*\*(.+?)\*\*');
    int lastEnd = 0;
    for (final match in regex.allMatches(message)) {
      if (match.start > lastEnd) {
        parts.add(TextSpan(text: message.substring(lastEnd, match.start)));
      }
      parts.add(TextSpan(
        text: match.group(1),
        style: const TextStyle(
          color: AppColors.accent,
          fontWeight: FontWeight.w600,
        ),
      ));
      lastEnd = match.end;
    }
    if (lastEnd < message.length) {
      parts.add(TextSpan(text: message.substring(lastEnd)));
    }

    return RichText(
      text: TextSpan(
        style: const TextStyle(
          fontSize: 15,
          color: AppColors.text,
          height: 1.7,
        ),
        children: parts,
      ),
    );
  }

  Widget _buildFooter() {
    return const Center(
      child: Text(
        'Powered by arxiv-trend-predictor API',
        style: TextStyle(fontSize: 12, color: AppColors.textMuted),
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
