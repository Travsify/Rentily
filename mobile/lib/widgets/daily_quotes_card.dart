import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_colors.dart';

class DailyQuotesCard extends StatefulWidget {
  const DailyQuotesCard({super.key});

  @override
  State<DailyQuotesCard> createState() => _DailyQuotesCardState();
}

class _DailyQuotesCardState extends State<DailyQuotesCard> {
  late final PageController _pageController;
  Timer? _timer;
  int _currentIndex = 0;

  final List<Map<String, dynamic>> _quotes = const [
    {
      'category': 'FINANCIAL WISDOM',
      'quote': 'Do not save what is left after spending, but spend what is left after saving. Wealth is built through disciplined restraint, not excess.',
      'author': 'Warren Buffett',
      'color': Color(0xFF0D5C46),
      'tag': 'FINANCE',
    },
    {
      'category': 'POWER OF HABITS',
      'quote': 'We are what we repeatedly do. Excellence, then, is not an isolated act, but an ingrained daily habit.',
      'author': 'Will Durant',
      'color': Color(0xFF0284C7),
      'tag': 'HABITS',
    },
    {
      'category': 'MARRIAGE & HOME',
      'quote': 'A peaceful home is not built by chance; it is constructed through daily patience, mutual respect, and unyielding loyalty.',
      'author': 'Fulton J. Sheen',
      'color': Color(0xFF7C3AED),
      'tag': 'MARRIAGE',
    },
    {
      'category': 'LIFE PERSPECTIVE',
      'quote': 'The true measure of your wealth is how much you would be worth if you lost all your material money today. Protect your integrity.',
      'author': 'Marcus Aurelius',
      'color': Color(0xFFB45309),
      'tag': 'LIFE',
    },
    {
      'category': 'FINANCIAL DISCIPLINE',
      'quote': 'It is not the man who has too little, but the man who craves more, that is poor. Financial peace is the ultimate dividend.',
      'author': 'Seneca',
      'color': Color(0xFF0D5C46),
      'tag': 'FINANCE',
    },
    {
      'category': 'POWER OF HABITS',
      'quote': 'You do not rise to the level of your goals. You fall to the level of your daily systems. Small adjustments compound over time.',
      'author': 'James Clear',
      'color': Color(0xFF0284C7),
      'tag': 'HABITS',
    },
    {
      'category': 'MARRIAGE & HARMONY',
      'quote': 'A great marriage is an ongoing conversation between two forgivers. Choose understanding over being right.',
      'author': 'Ruth Bell Graham',
      'color': Color(0xFF7C3AED),
      'tag': 'MARRIAGE',
    },
    {
      'category': 'LIFE RESILIENCE',
      'quote': 'Hard work beats raw talent when talent fails to work hard. Character will open doors that privilege can never unlock.',
      'author': 'Tim Notke',
      'color': Color(0xFFB45309),
      'tag': 'LIFE',
    },
    {
      'category': 'FINANCIAL STEWARDSHIP',
      'quote': 'Compound interest is the eighth wonder of the world. He who understands it, earns it; he who does not, pays it.',
      'author': 'Albert Einstein',
      'color': Color(0xFF0D5C46),
      'tag': 'FINANCE',
    },
    {
      'category': 'HABIT & GROWTH',
      'quote': 'Motivation is what gets you started. Discipline is what keeps you growing when the excitement fades.',
      'author': 'Jim Ryun',
      'color': Color(0xFF0284C7),
      'tag': 'HABITS',
    },
    {
      'category': 'MARRIAGE & PEACE',
      'quote': 'The greatest thing a man can do for his children is to love their mother, and the greatest gift a home can give is tranquility.',
      'author': 'Theodore Hesburgh',
      'color': Color(0xFF7C3AED),
      'tag': 'MARRIAGE',
    },
    {
      'category': 'LIFE PURPOSE',
      'quote': 'Your time on earth is finite. Never spend your precious days living someone else’s expectation. Walk boldly in your truth.',
      'author': 'Steve Jobs',
      'color': Color(0xFFB45309),
      'tag': 'LIFE',
    },
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 15), (timer) {
      if (!mounted) return;
      final next = (_currentIndex + 1) % _quotes.length;
      _pageController.animateToPage(
        next,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.borderDark),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.format_quote_rounded, size: 18, color: AppColors.primary),
                    const SizedBox(width: 6),
                    Text(
                      'DAILY INSPIRATION & WISDOM',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.timer_outlined, size: 10, color: AppColors.primary),
                      const SizedBox(width: 3),
                      Text(
                        '15s Auto-refresh',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.borderDark),

          // Sliding Quote Carousel
          SizedBox(
            height: 120,
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: (idx) {
                setState(() => _currentIndex = idx);
                _startTimer(); // Reset 15s timer when user swipes manually
              },
              itemCount: _quotes.length,
              itemBuilder: (context, idx) {
                final item = _quotes[idx];
                final Color themeColor = item['color'] as Color;

                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: themeColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              item['category'] as String,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 8,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.6,
                                color: themeColor,
                              ),
                            ),
                          ),
                          Text(
                            '${idx + 1} / ${_quotes.length}',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '“${item['quote']}”',
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11.5,
                          fontStyle: FontStyle.italic,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                          height: 1.35,
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          '— ${item['author']}',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: themeColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          // Dot indicators
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _quotes.length,
                (i) => Container(
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  width: _currentIndex == i ? 14 : 4,
                  height: 4,
                  decoration: BoxDecoration(
                    color: _currentIndex == i ? AppColors.primary : AppColors.borderDark,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
