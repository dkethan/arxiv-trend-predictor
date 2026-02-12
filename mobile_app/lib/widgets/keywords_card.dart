import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme.dart';

/// Matches the web app's .keywords-card:
/// teal mono pills with soft accent background (same as web).
class KeywordsCard extends StatelessWidget {
  final List<String> keywords;

  const KeywordsCard({super.key, required this.keywords});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: appCardDecoration,
      child: keywords.isEmpty
          ? const Text(
              'No keywords suggested.',
              style: TextStyle(
                fontSize: 15,
                color: AppColors.textMuted,
              ),
            )
          : Wrap(
              spacing: 8,
              runSpacing: 8,
              children: keywords
                  .map((kw) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 13.6,
                          vertical: 6.4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.accentSoft,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: AppColors.accent.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          kw,
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 12.8,
                            fontWeight: FontWeight.w500,
                            color: AppColors.accent,
                          ),
                        ),
                      ))
                  .toList(),
            ),
    );
  }
}
