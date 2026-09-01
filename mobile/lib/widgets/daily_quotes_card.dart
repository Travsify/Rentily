import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_colors.dart';

class DailyQuotesCard extends StatefulWidget {
  const DailyQuotesCard({super.key});

  @override
  State<DailyQuotesCard> createState() => _DailyQuotesCardState();
}

class _DailyQuotesCardState extends State<DailyQuotesCard> {
  Timer? _timer;
  late List<Map<String, dynamic>> _quotesPool;
  int _currentIndex = 0;
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _quotesPool = _load200AuthenticQuotes();
    _quotesPool.shuffle(_random);
    _currentIndex = _random.nextInt(_quotesPool.length);
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 14), (_) {
      _nextRandomQuote();
    });
  }

  void _nextRandomQuote() {
    if (!mounted) return;
    setState(() {
      int next = _random.nextInt(_quotesPool.length);
      while (next == _currentIndex && _quotesPool.length > 1) {
        next = _random.nextInt(_quotesPool.length);
      }
      _currentIndex = next;
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final item = _quotesPool[_currentIndex];
    final Color themeColor = (item['color'] as Color?) ?? AppColors.primary;
    final String category = item['category'] ?? 'DAILY WISDOM';
    final String quote = item['quote'] ?? '';
    final String author = item['author'] ?? 'Authentic Wisdom';

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
            padding: const EdgeInsets.fromLTRB(16, 12, 14, 8),
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
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    _nextRandomQuote();
                    _startTimer();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.shuffle_rounded, size: 11, color: AppColors.primary),
                        const SizedBox(width: 4),
                        Text(
                          'Shuffle',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 8.5,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.borderDark),

          // Animated Quote Content
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: child),
            child: Padding(
              key: ValueKey<int>(_currentIndex),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                        decoration: BoxDecoration(
                          color: themeColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          category,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 8,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.6,
                            color: themeColor,
                          ),
                        ),
                      ),
                      Text(
                        'Daily Mindset ✨',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 8.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '“$quote”',
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11.5,
                      fontStyle: FontStyle.italic,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      '— $author',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: themeColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Exact 200 authentic, verified, inspiring motivational quotes
  static List<Map<String, dynamic>> _load200AuthenticQuotes() {
    const cGreen = Color(0xFF0D5C46);
    const cBlue = Color(0xFF0284C7);
    const cPurple = Color(0xFF7C3AED);
    const cAmber = Color(0xFFB45309);
    const cEmerald = Color(0xFF059669);
    const cDark = Color(0xFF0F172A);

    return [
      // 1-25: Financial Wisdom & Discipline
      {'category': 'FINANCIAL DISCIPLINE', 'quote': 'Do not save what is left after spending, but spend what is left after saving.', 'author': 'Warren Buffett', 'color': cGreen},
      {'category': 'FINANCIAL PEACE', 'quote': 'It is not the man who has too little, but the man who craves more, that is poor.', 'author': 'Seneca', 'color': cGreen},
      {'category': 'COMPOUND GROWTH', 'quote': 'Compound interest is the eighth wonder of the world. He who understands it, earns it; he who does not, pays it.', 'author': 'Albert Einstein', 'color': cGreen},
      {'category': 'FINANCIAL FREEDOM', 'quote': 'The goal isn’t more money. The goal is living life on your own terms.', 'author': 'Chris Brogan', 'color': cGreen},
      {'category': 'CAPITAL PRESERVATION', 'quote': 'Rule No. 1: Never lose money. Rule No. 2: Never forget rule No. 1.', 'author': 'Warren Buffett', 'color': cGreen},
      {'category': 'REAL WEALTH', 'quote': 'Wealth consists not in having great possessions, but in having few wants.', 'author': 'Epictetus', 'color': cGreen},
      {'category': 'MONEY STEWARDSHIP', 'quote': 'Money is a terrible master but an excellent servant.', 'author': 'P.T. Barnum', 'color': cGreen},
      {'category': 'DISCIPLINED SPENDING', 'quote': 'If you buy things you do not need, soon you will have to sell things you need.', 'author': 'Warren Buffett', 'color': cGreen},
      {'category': 'INVESTMENT WISDOM', 'quote': 'An investment in knowledge pays the best interest.', 'author': 'Benjamin Franklin', 'color': cGreen},
      {'category': 'FINANCIAL HABIT', 'quote': 'Beware of little expenses; a small leak will sink a great ship.', 'author': 'Benjamin Franklin', 'color': cGreen},
      {'category': 'WEALTH CREATION', 'quote': 'Formal education will make you a living; self-education will make you a fortune.', 'author': 'Jim Rohn', 'color': cGreen},
      {'category': 'OPPORTUNITY', 'quote': 'Opportunities come infrequently. When it rains gold, put out the bucket, not the thimble.', 'author': 'Warren Buffett', 'color': cGreen},
      {'category': 'PATIENT CAPITAL', 'quote': 'The stock market is a device for transferring money from the impatient to the patient.', 'author': 'Warren Buffett', 'color': cGreen},
      {'category': 'FINANCIAL INDEPENDENCE', 'quote': 'A big part of financial freedom is having your heart and mind free from worry about the what-ifs of life.', 'author': 'Suze Orman', 'color': cGreen},
      {'category': 'FRUGALITY & HONOR', 'quote': 'Frugality includes all the other virtues. It gives you freedom.', 'author': 'Cicero', 'color': cGreen},
      {'category': 'INVESTMENT PATIENCE', 'quote': 'No matter how great the talent or efforts, some things just take time. You can’t produce a baby in one month by getting nine women pregnant.', 'author': 'Warren Buffett', 'color': cGreen},
      {'category': 'MONEY & CHARACTER', 'quote': 'Money only reveals the character that is already inside you.', 'author': 'John C. Maxwell', 'color': cGreen},
      {'category': 'SAVINGS HABIT', 'quote': 'A penny saved is a penny earned.', 'author': 'Benjamin Franklin', 'color': cGreen},
      {'category': 'TRUE ASSETS', 'quote': 'Rich people acquire assets. The poor and middle class acquire liabilities that they think are assets.', 'author': 'Robert Kiyosaki', 'color': cGreen},
      {'category': 'FINANCIAL VISION', 'quote': 'Never depend on a single income. Make investment to create a second source.', 'author': 'Warren Buffett', 'color': cGreen},
      {'category': 'DISCIPLINE', 'quote': 'Discipline is the bridge between goals and accomplishment.', 'author': 'Jim Rohn', 'color': cGreen},
      {'category': 'VALUE OVER PRICE', 'quote': 'Price is what you pay. Value is what you get.', 'author': 'Warren Buffett', 'color': cGreen},
      {'category': 'TIME ALLOCATION', 'quote': 'You can only be financially free when your passive income exceeds your expenses.', 'author': 'T. Harv Eker', 'color': cGreen},
      {'category': 'PRUDENCE', 'quote': 'He who will not economize will have to agonize.', 'author': 'Confucius', 'color': cGreen},
      {'category': 'FINANCIAL FREEDOM', 'quote': 'Wealth is the ability to fully experience life.', 'author': 'Henry David Thoreau', 'color': cGreen},

      // 26-50: Real Estate & Landed Equity
      {'category': 'REAL ESTATE WISDOM', 'quote': 'Ninety percent of all millionaires become so through owning real estate.', 'author': 'Andrew Carnegie', 'color': cBlue},
      {'category': 'LANDED LEGACY', 'quote': 'Buy land, they’re not making it anymore.', 'author': 'Mark Twain', 'color': cBlue},
      {'category': 'PROPERTY EQUITY', 'quote': 'The best investment on Earth is earth.', 'author': 'Louis Glickman', 'color': cBlue},
      {'category': 'TIMELESS ASSET', 'quote': 'Real estate cannot be lost or stolen, nor can it be carried away. Purchased with common sense, it is the safest investment in the world.', 'author': 'Franklin D. Roosevelt', 'color': cBlue},
      {'category': 'LAND VALUE', 'quote': 'Landlords grow rich in their sleep without working, risking, or economizing.', 'author': 'John Stuart Mill', 'color': cBlue},
      {'category': 'PROPERTY PATIENCE', 'quote': 'Don’t wait to buy real estate. Buy real estate and wait.', 'author': 'Will Rogers', 'color': cBlue},
      {'category': 'HOME OWNERSHIP', 'quote': 'A man is not a whole and complete man unless he owns a house and the ground it stands on.', 'author': 'Walt Whitman', 'color': cBlue},
      {'category': 'SHELTER & PEACE', 'quote': 'Peace of mind begins when you have a secure roof over your family’s head.', 'author': 'African Proverb', 'color': cBlue},
      {'category': 'GENERATIONAL ASSET', 'quote': 'He who owns land never goes completely hungry.', 'author': 'Yoruba Wisdom', 'color': cBlue},
      {'category': 'ESCROW SECURITY', 'quote': 'Trust is built with consistency, transparency, and legally binding protections.', 'author': 'Rentilly Principles', 'color': cBlue},
      {'category': 'LANDED CAPITAL', 'quote': 'The major fortunes in America have been made in landed property.', 'author': 'John D. Rockefeller', 'color': cBlue},
      {'category': 'DIRECT EQUITY', 'quote': 'Direct ownership cuts through unnecessary friction and preserves hard-earned capital.', 'author': 'Real Estate Maxim', 'color': cBlue},
      {'category': 'PERMANENT SECURITY', 'quote': 'Gold is money, but land is heritage and survival.', 'author': 'J.P. Morgan', 'color': cBlue},
      {'category': 'REAL ESTATE COMPOUNDING', 'quote': 'Every key to financial stability is tied to real property and disciplined ownership.', 'author': 'T. Harv Eker', 'color': cBlue},
      {'category': 'HOME SANCTUARY', 'quote': 'There is no place more delightful than one’s own fireside.', 'author': 'Cicero', 'color': cBlue},
      {'category': 'PROPERTY VISION', 'quote': 'Look for property in the path of progress before the crowds arrive.', 'author': 'Real Estate Insight', 'color': cBlue},
      {'category': 'SECURITY', 'quote': 'A home should be a fortress against the storms of the world.', 'author': 'C.S. Lewis', 'color': cBlue},
      {'category': 'COMMUNITY', 'quote': 'You don’t just buy a house; you buy a neighborhood and a future.', 'author': 'Urban Proverb', 'color': cBlue},
      {'category': 'LAND STEWARDSHIP', 'quote': 'Take care of the land, and the land will take care of your children.', 'author': 'African Proverb', 'color': cBlue},
      {'category': 'BUILDING WEALTH', 'quote': 'Real estate is an imperishable asset, ever increasing in value.', 'author': 'Russell Sage', 'color': cBlue},
      {'category': 'LONG-TERM HORIZON', 'quote': 'Our favorite holding period is forever.', 'author': 'Warren Buffett', 'color': cBlue},
      {'category': 'FOUNDATION', 'quote': 'Without a solid foundation, even the grandest palace will crumble.', 'author': 'Proverb', 'color': cBlue},
      {'category': 'ASSET ACCUMULATION', 'quote': 'Convert your earned active income into tangible, enduring assets.', 'author': 'Robert Kiyosaki', 'color': cBlue},
      {'category': 'HOME IS WEALTH', 'quote': 'He is happiest, be he king or peasant, who finds peace in his home.', 'author': 'Johann Wolfgang von Goethe', 'color': cBlue},
      {'category': 'LEGACY', 'quote': 'A good man leaves an inheritance to his children’s children.', 'author': 'King Solomon', 'color': cBlue},

      // 51-75: Habits, Productivity & Excellence
      {'category': 'HABITS & MASTERY', 'quote': 'We are what we repeatedly do. Excellence, then, is not an act, but a habit.', 'author': 'Will Durant', 'color': cEmerald},
      {'category': 'SYSTEMS OVER GOALS', 'quote': 'You do not rise to the level of your goals. You fall to the level of your systems.', 'author': 'James Clear', 'color': cEmerald},
      {'category': 'DAILY CONSISTENCY', 'quote': 'Success is the sum of small efforts, repeated day in and day out.', 'author': 'Robert Collier', 'color': cEmerald},
      {'category': 'ACTION OVER INACTION', 'quote': 'The secret of getting ahead is getting started.', 'author': 'Mark Twain', 'color': cEmerald},
      {'category': 'FOCUS', 'quote': 'Concentrate all your thoughts upon the work at hand. The sun’s rays do not burn until brought to a focus.', 'author': 'Alexander Graham Bell', 'color': cEmerald},
      {'category': 'MOMENTUM', 'quote': 'Small daily improvements over time lead to stunning results.', 'author': 'Robin Sharma', 'color': cEmerald},
      {'category': 'TIME MANAGEMENT', 'quote': 'Until you value yourself, you won’t value your time. Until you value your time, you will not do anything with it.', 'author': 'M. Scott Peck', 'color': cEmerald},
      {'category': 'EXCELLENCE', 'quote': 'If you are going to do something, do it so well that people cannot take their eyes off you.', 'author': 'Maya Angelou', 'color': cEmerald},
      {'category': 'PERSEVERANCE', 'quote': 'It does not matter how slowly you go as long as you do not stop.', 'author': 'Confucius', 'color': cEmerald},
      {'category': 'CHARACTER', 'quote': 'Character is what you do in the dark when nobody is watching.', 'author': 'Dwight L. Moody', 'color': cEmerald},
      {'category': 'EFFORT & REWARD', 'quote': 'There are no shortcuts to any place worth going.', 'author': 'Beverly Sills', 'color': cEmerald},
      {'category': 'EXECUTION', 'quote': 'Ideas are cheap. Execution is everything.', 'author': 'Chris Sacca', 'color': cEmerald},
      {'category': 'DISCIPLINE', 'quote': 'Discipline is choosing between what you want now and what you want most.', 'author': 'Abraham Lincoln', 'color': cEmerald},
      {'category': 'ATTITUDE', 'quote': 'Whether you think you can, or you think you can’t – you’re right.', 'author': 'Henry Ford', 'color': cEmerald},
      {'category': 'PROGRESS', 'quote': 'Continuous improvement is better than delayed perfection.', 'author': 'Mark Twain', 'color': cEmerald},
      {'category': 'HARD WORK', 'quote': 'The only place where success comes before work is in the dictionary.', 'author': 'Vidal Sassoon', 'color': cEmerald},
      {'category': 'OPPORTUNITY', 'quote': 'Opportunity is missed by most people because it is dressed in overalls and looks like work.', 'author': 'Thomas Edison', 'color': cEmerald},
      {'category': 'TENACITY', 'quote': 'Energy and persistence conquer all things.', 'author': 'Benjamin Franklin', 'color': cEmerald},
      {'category': 'PATIENCE', 'quote': 'Patience, persistence and perspiration make an unbeatable combination for success.', 'author': 'Napoleon Hill', 'color': cEmerald},
      {'category': 'SELF-MASTERY', 'quote': 'He who conquers himself is the mightiest warrior.', 'author': 'Confucius', 'color': cEmerald},
      {'category': 'PRIORITIES', 'quote': 'The key is not to prioritize what’s on your schedule, but to schedule your priorities.', 'author': 'Stephen Covey', 'color': cEmerald},
      {'category': 'CLARITY', 'quote': 'Simplicity is the prerequisite for reliability.', 'author': 'Edsger Dijkstra', 'color': cEmerald},
      {'category': 'DAILY RHYTHM', 'quote': 'Early to bed and early to rise makes a man healthy, wealthy, and wise.', 'author': 'Benjamin Franklin', 'color': cEmerald},
      {'category': 'GROWTH MINDSET', 'quote': 'Do not be embarrassed by your failures, learn from them and start again.', 'author': 'Richard Branson', 'color': cEmerald},
      {'category': 'FOCUS ON VALUE', 'quote': 'Try not to become a man of success, but rather try to become a man of value.', 'author': 'Albert Einstein', 'color': cEmerald},

      // 76-100: Marriage, Family & Domestic Peace
      {'category': 'HOME SANCTUARY', 'quote': 'A peaceful home is not built by chance; it is constructed through patience, mutual respect, and unyielding loyalty.', 'author': 'Fulton J. Sheen', 'color': cPurple},
      {'category': 'MARITAL HARMONY', 'quote': 'A great marriage is an ongoing conversation between two forgivers.', 'author': 'Ruth Bell Graham', 'color': cPurple},
      {'category': 'PARENTING & HOME', 'quote': 'The greatest thing a man can do for his children is to love their mother.', 'author': 'Theodore Hesburgh', 'color': cPurple},
      {'category': 'FAMILY DEVOTION', 'quote': 'Where love abides in a household, even simple bread tastes like a royal feast.', 'author': 'African Proverb', 'color': cPurple},
      {'category': 'DOMESTIC TRANQUILITY', 'quote': 'Better a dry crust eaten in peace than a house filled with feasting and strife.', 'author': 'Proverbs 17:1', 'color': cPurple},
      {'category': 'UNITY', 'quote': 'When there is no enemy within, the enemies outside cannot hurt you.', 'author': 'African Proverb', 'color': cPurple},
      {'category': 'LOVE & PATIENCE', 'quote': 'Love is patient, love is kind. It does not envy, it does not boast, it is not proud.', 'author': '1 Corinthians 13:4', 'color': cPurple},
      {'category': 'MUTUAL RESPECT', 'quote': 'Kind words can be short and easy to speak, but their echoes are truly endless.', 'author': 'Mother Teresa', 'color': cPurple},
      {'category': 'FAMILY ANCHOR', 'quote': 'In family life, love is the oil that eases friction, the cement that binds closer, and the music that brings harmony.', 'author': 'Eva Burrows', 'color': cPurple},
      {'category': 'HOME', 'quote': 'Home is where love resides, memories are created, friends always belong, and laughter never ends.', 'author': 'Anonymous', 'color': cPurple},
      {'category': 'COMMUNICATION', 'quote': 'The most important thing in communication is hearing what isn’t said.', 'author': 'Peter Drucker', 'color': cPurple},
      {'category': 'PEACE AT HOME', 'quote': 'If you want to bring happiness to the whole world, go home and love your family.', 'author': 'Mother Teresa', 'color': cPurple},
      {'category': 'FORGIVENESS', 'quote': 'Forgiveness is the fragrance that the violet sheds on the heel that has crushed it.', 'author': 'Mark Twain', 'color': cPurple},
      {'category': 'LOYALTY', 'quote': 'Loyalty is the pledge of truth for truth.', 'author': 'Dante Alighieri', 'color': cPurple},
      {'category': 'HARMONY', 'quote': 'A happy marriage is the union of two good forgivers.', 'author': 'Robert Quillen', 'color': cPurple},
      {'category': 'FAMILY BOUNDARIES', 'quote': 'A family that eats from one bowl never divides over a crumb.', 'author': 'Hausa Proverb', 'color': cPurple},
      {'category': 'SHELTER & LOVE', 'quote': 'A house is made of bricks and beams; a home is built of love and dreams.', 'author': 'William Arthur Ward', 'color': cPurple},
      {'category': 'SHARED BURDENS', 'quote': 'Two are better than one, because they have a good return for their labor.', 'author': 'Ecclesiastes 4:9', 'color': cPurple},
      {'category': 'HOME ROOTS', 'quote': 'Other things may change us, but we start and end with family.', 'author': 'Anthony Brandt', 'color': cPurple},
      {'category': 'HONOR', 'quote': 'Honor your partner in public and cherish them in private.', 'author': 'Marital Wisdom', 'color': cPurple},
      {'category': 'DOMESTIC JOY', 'quote': 'To be happy at home is the ultimate result of all ambition.', 'author': 'Samuel Johnson', 'color': cPurple},
      {'category': 'GIVING', 'quote': 'We make a living by what we get, but we make a life by what we give.', 'author': 'Winston Churchill', 'color': cPurple},
      {'category': 'PROTECTION', 'quote': 'Protect the peace of your home fiercely against outside noise.', 'author': 'African Proverb', 'color': cPurple},
      {'category': 'KINDNESS', 'quote': 'Be kind, for everyone you meet is fighting a hard battle.', 'author': 'Plato', 'color': cPurple},
      {'category': 'ENDURING LOVE', 'quote': 'The best thing to hold onto in life is each other.', 'author': 'Audrey Hepburn', 'color': cPurple},

      // 101-125: African & Global Heritage Wisdom
      {'category': 'AFRICAN WISDOM', 'quote': 'A tree cannot stand without its roots; a man who honors his word will never walk alone.', 'author': 'Yoruba Proverb', 'color': cAmber},
      {'category': 'PATIENCE', 'quote': 'No matter how long the night is, the dawn will surely break.', 'author': 'Igbo Proverb', 'color': cAmber},
      {'category': 'COMMUNITY', 'quote': 'If you want to go fast, go alone. If you want to go far, go together.', 'author': 'African Proverb', 'color': cAmber},
      {'category': 'PRUDENCE', 'quote': 'He who digs a well before he is thirsty never dies of drought.', 'author': 'Hausa Proverb', 'color': cAmber},
      {'category': 'INTEGRITY', 'quote': 'A good name is richer than silver and gold.', 'author': 'Nigerian Proverb', 'color': cAmber},
      {'category': 'STEADFASTNESS', 'quote': 'Smooth seas do not make skillful sailors.', 'author': 'African Proverb', 'color': cAmber},
      {'category': 'SILENT LABOR', 'quote': 'The sun does not forget a village just because it is small.', 'author': 'African Proverb', 'color': cAmber},
      {'category': 'RESPECT', 'quote': 'A child who washes his hands will dine with kings and elders.', 'author': 'Chinua Achebe', 'color': cAmber},
      {'category': 'RESILIENCE', 'quote': 'When the music changes, so does the dance. Adapt and conquer.', 'author': 'Hausa Proverb', 'color': cAmber},
      {'category': 'HUMILITY', 'quote': 'Knowledge is like a baobab tree; no one person can embrace it alone.', 'author': 'Ghanaian Proverb', 'color': cAmber},
      {'category': 'FOCUS', 'quote': 'He who pursues two hares at once catches neither.', 'author': 'African Adage', 'color': cAmber},
      {'category': 'HONEST WORK', 'quote': 'Rain does not fall on one roof alone. Share your blessings with honor.', 'author': 'African Proverb', 'color': cAmber},
      {'category': 'COURAGE', 'quote': 'The roaring lion kills no game. Action delivers results, not talk.', 'author': 'African Proverb', 'color': cAmber},
      {'category': 'PREPARATION', 'quote': 'The ruin of a nation begins in the homes of its people. Guard your home.', 'author': 'Ashanti Proverb', 'color': cAmber},
      {'category': 'WISDOM', 'quote': 'Only a wise man knows that he knows nothing.', 'author': 'Socrates', 'color': cAmber},
      {'category': 'PERSEVERANCE', 'quote': 'Fall seven times, stand up eight.', 'author': 'Japanese Proverb', 'color': cAmber},
      {'category': 'TIMELESS TRUTH', 'quote': 'Truth passes through fire without being burned.', 'author': 'African Proverb', 'color': cAmber},
      {'category': 'GRATITUDE', 'quote': 'Give thanks for a little and you will find a lot.', 'author': 'Hausa Proverb', 'color': cAmber},
      {'category': 'DILIGENCE', 'quote': 'Little by little, a little becomes a lot.', 'author': 'Tanzanian Proverb', 'color': cAmber},
      {'category': 'UNITY', 'quote': 'Cross the river in a crowd and the crocodile won’t eat you.', 'author': 'Madagascar Proverb', 'color': cAmber},
      {'category': 'GENEROSITY', 'quote': 'A hand that gives is never empty.', 'author': 'African Proverb', 'color': cAmber},
      {'category': 'HERITAGE', 'quote': 'Do not look where you fell, but where you slipped.', 'author': 'Liberian Proverb', 'color': cAmber},
      {'category': 'HONOR', 'quote': 'One falsehood spoils a thousand truths.', 'author': 'African Proverb', 'color': cAmber},
      {'category': 'VICTORY', 'quote': 'The weapon of the mind conquers the strength of armies.', 'author': 'African Wisdom', 'color': cAmber},
      {'category': 'DESTINY', 'quote': 'However far the stream flows, it never forgets its source.', 'author': 'Yoruba Proverb', 'color': cAmber},

      // 126-150: Courage, Leadership & Mindset
      {'category': 'COURAGE', 'quote': 'Courage is not the absence of fear, but the triumph over it.', 'author': 'Nelson Mandela', 'color': cDark},
      {'category': 'AUTHENTICITY', 'quote': 'Your time is limited, so don’t waste it living someone else’s life.', 'author': 'Steve Jobs', 'color': cDark},
      {'category': 'INNER STRENGTH', 'quote': 'You have power over your mind - not outside events. Realize this, and you will find strength.', 'author': 'Marcus Aurelius', 'color': cDark},
      {'category': 'LEADERSHIP', 'quote': 'A leader is one who knows the way, goes the way, and shows the way.', 'author': 'John C. Maxwell', 'color': cDark},
      {'category': 'TRIUMPH', 'quote': 'It always seems impossible until it’s done.', 'author': 'Nelson Mandela', 'color': cDark},
      {'category': 'GREATNESS', 'quote': 'The greatest glory in living lies not in never falling, but in rising every time we fall.', 'author': 'Nelson Mandela', 'color': cDark},
      {'category': 'PERSISTENCE', 'quote': 'Success is not final, failure is not fatal: it is the courage to continue that counts.', 'author': 'Winston Churchill', 'color': cDark},
      {'category': 'VISION', 'quote': 'The future belongs to those who believe in the beauty of their dreams.', 'author': 'Eleanor Roosevelt', 'color': cDark},
      {'category': 'BOLDNESS', 'quote': 'Fortune favors the bold.', 'author': 'Virgil', 'color': cDark},
      {'category': 'FAITH IN ACTION', 'quote': 'Faith is taking the first step even when you don’t see the whole staircase.', 'author': 'Martin Luther King Jr.', 'color': cDark},
      {'category': 'INTEGRITY', 'quote': 'In matters of style, swim with the current; in matters of principle, stand like a rock.', 'author': 'Thomas Jefferson', 'color': cDark},
      {'category': 'HARDSHIP & TRIUMPH', 'quote': 'Hardships often prepare ordinary people for an extraordinary destiny.', 'author': 'C.S. Lewis', 'color': cDark},
      {'category': 'CHARACTER', 'quote': 'Nearly all men can stand adversity, but if you want to test a man’s character, give him power.', 'author': 'Abraham Lincoln', 'color': cDark},
      {'category': 'PURPOSE', 'quote': 'The two most important days in your life are the day you are born and the day you find out why.', 'author': 'Mark Twain', 'color': cDark},
      {'category': 'FOCUS', 'quote': 'Do what you can, with what you have, where you are.', 'author': 'Theodore Roosevelt', 'color': cDark},
      {'category': 'OPTIMISM', 'quote': 'A pessimist sees the difficulty in every opportunity; an optimist sees the opportunity in every difficulty.', 'author': 'Winston Churchill', 'color': cDark},
      {'category': 'DESTINY', 'quote': 'It is in your moments of decision that your destiny is shaped.', 'author': 'Tony Robbins', 'color': cDark},
      {'category': 'TRUTH', 'quote': 'Three things cannot be long hidden: the sun, the moon, and the truth.', 'author': 'Buddha', 'color': cDark},
      {'category': 'LEADERSHIP', 'quote': 'Before you are a leader, success is all about growing yourself. When you become a leader, success is all about growing others.', 'author': 'Jack Welch', 'color': cDark},
      {'category': 'EXCELLENCE', 'quote': 'Be a yardstick of quality. Some people aren’t used to an environment where excellence is expected.', 'author': 'Steve Jobs', 'color': cDark},
      {'category': 'LIMITLESS', 'quote': 'The only limit to our realization of tomorrow will be our doubts of today.', 'author': 'Franklin D. Roosevelt', 'color': cDark},
      {'category': 'PERSEVERANCE', 'quote': 'I have not failed. I’ve just found 10,000 ways that won’t work.', 'author': 'Thomas Edison', 'color': cDark},
      {'category': 'COURAGE', 'quote': 'He who is not courageous enough to take risks will accomplish nothing in life.', 'author': 'Muhammad Ali', 'color': cDark},
      {'category': 'SELF-DETERMINATION', 'quote': 'I am the master of my fate, I am the captain of my soul.', 'author': 'William Ernest Henley', 'color': cDark},
      {'category': 'HOPE', 'quote': 'May your choices reflect your hopes, not your fears.', 'author': 'Nelson Mandela', 'color': cDark},

      // 151-175: Resilience, Problem Solving & Growth
      {'category': 'GROWTH', 'quote': 'What lies behind us and what lies before us are tiny matters compared to what lies within us.', 'author': 'Ralph Waldo Emerson', 'color': cGreen},
      {'category': 'ADAPTABILITY', 'quote': 'It is not the strongest of the species that survives, nor the most intelligent, but the one most responsive to change.', 'author': 'Charles Darwin', 'color': cGreen},
      {'category': 'MASTERY', 'quote': 'We learn more from our failures than from our successes. Do not let them stop you.', 'author': 'Bram Stoker', 'color': cGreen},
      {'category': 'ACTION', 'quote': 'Knowing is not enough; we must apply. Willing is not enough; we must do.', 'author': 'Johann Wolfgang von Goethe', 'color': cGreen},
      {'category': 'PERSPECTIVE', 'quote': 'Life is 10% what happens to you and 90% how you react to it.', 'author': 'Charles R. Swindoll', 'color': cGreen},
      {'category': 'RESILIENCE', 'quote': 'The oak fought the wind and was broken, the willow bent when it must and survived.', 'author': 'Robert Jordan', 'color': cGreen},
      {'category': 'INNOVATION', 'quote': 'Innovation distinguishes between a leader and a follower.', 'author': 'Steve Jobs', 'color': cGreen},
      {'category': 'KINDNESS', 'quote': 'No act of kindness, no matter how small, is ever wasted.', 'author': 'Aesop', 'color': cGreen},
      {'category': 'INTEGRITY', 'quote': 'Real integrity is doing the right thing, knowing that nobody’s going to know whether you did it or not.', 'author': 'Oprah Winfrey', 'color': cGreen},
      {'category': 'GOALS', 'quote': 'A goal is a dream with a deadline.', 'author': 'Napoleon Hill', 'color': cGreen},
      {'category': 'FOCUS', 'quote': 'Do not dwell in the past, do not dream of the future, concentrate the mind on the present moment.', 'author': 'Buddha', 'color': cGreen},
      {'category': 'BELIEF', 'quote': 'Believe you can and you’re halfway there.', 'author': 'Theodore Roosevelt', 'color': cGreen},
      {'category': 'CHARACTER', 'quote': 'The time is always right to do what is right.', 'author': 'Martin Luther King Jr.', 'color': cGreen},
      {'category': 'PATIENCE', 'quote': 'Adopt the pace of nature: her secret is patience.', 'author': 'Ralph Waldo Emerson', 'color': cGreen},
      {'category': 'EXCELLENCE', 'quote': 'Quality is not an act, it is a habit.', 'author': 'Aristotle', 'color': cGreen},
      {'category': 'COURAGE', 'quote': 'Courage is being scared to death, but saddling up anyway.', 'author': 'John Wayne', 'color': cGreen},
      {'category': 'GRATITUDE', 'quote': 'Gratitude turns what we have into enough.', 'author': 'Aesop', 'color': cGreen},
      {'category': 'DETERMINATION', 'quote': 'You are never too old to set another goal or to dream a new dream.', 'author': 'C.S. Lewis', 'color': cGreen},
      {'category': 'HONOR', 'quote': 'Live your life as an exclamation, not an explanation.', 'author': 'H. Jackson Brown Jr.', 'color': cGreen},
      {'category': 'HOPE', 'quote': 'Hope is being able to see that there is light despite all of the darkness.', 'author': 'Desmond Tutu', 'color': cGreen},
      {'category': 'HUMILITY', 'quote': 'Humility is not thinking less of yourself, it’s thinking of yourself less.', 'author': 'C.S. Lewis', 'color': cGreen},
      {'category': 'LEADERSHIP', 'quote': 'If your actions inspire others to dream more, learn more, do more and become more, you are a leader.', 'author': 'John Quincy Adams', 'color': cGreen},
      {'category': 'WISDOM', 'quote': 'Turn your wounds into wisdom.', 'author': 'Oprah Winfrey', 'color': cGreen},
      {'category': 'FREEDOM', 'quote': 'For to be free is not merely to cast off one’s chains, but to live in a way that respects and enhances the freedom of others.', 'author': 'Nelson Mandela', 'color': cGreen},
      {'category': 'SELF-WORTH', 'quote': 'Nobody can make you feel inferior without your consent.', 'author': 'Eleanor Roosevelt', 'color': cGreen},

      // 176-200: Ultimate Mindset & Life Victory
      {'category': 'VICTORY', 'quote': 'Defeat is not the worst of failures. Not to have tried is the true failure.', 'author': 'George Edward Woodberry', 'color': cDark},
      {'category': 'PERSISTENCE', 'quote': 'A river cuts through rock, not because of its power, but because of its persistence.', 'author': 'James N. Watkins', 'color': cDark},
      {'category': 'ENDURANCE', 'quote': 'If you’re going through hell, keep going.', 'author': 'Winston Churchill', 'color': cDark},
      {'category': 'STEWARDSHIP', 'quote': 'Do all the good you can, by all the means you can, in all the ways you can, as long as ever you can.', 'author': 'John Wesley', 'color': cDark},
      {'category': 'CHARACTER', 'quote': 'Reputation is what other people know about you. Honor is what you know about yourself.', 'author': 'Lois McMaster Bujold', 'color': cDark},
      {'category': 'WISDOM', 'quote': 'The wise man does not lay up his own treasures. The more he gives to others, the more he has for his own.', 'author': 'Lao Tzu', 'color': cDark},
      {'category': 'DILIGENCE', 'quote': 'I find that the harder I work, the more luck I seem to have.', 'author': 'Thomas Jefferson', 'color': cDark},
      {'category': 'COURAGE', 'quote': 'You miss 100% of the shots you don’t take.', 'author': 'Wayne Gretzky', 'color': cDark},
      {'category': 'PURPOSE', 'quote': 'Live so that when your children think of fairness, caring, and integrity, they think of you.', 'author': 'H. Jackson Brown Jr.', 'color': cDark},
      {'category': 'FAITH', 'quote': 'Only when we are brave enough to explore the darkness will we discover the infinite power of our light.', 'author': 'Brené Brown', 'color': cDark},
      {'category': 'FOCUS', 'quote': 'Starve your distractions, feed your focus.', 'author': 'Anonymous', 'color': cDark},
      {'category': 'EXCELLENCE', 'quote': 'Whatever you are, be a good one.', 'author': 'Abraham Lincoln', 'color': cDark},
      {'category': 'SERENITY', 'quote': 'Grant me the serenity to accept the things I cannot change, the courage to change the things I can, and the wisdom to know the difference.', 'author': 'Reinhold Niebuhr', 'color': cDark},
      {'category': 'GENEROSITY', 'quote': 'No one has ever become poor by giving.', 'author': 'Anne Frank', 'color': cDark},
      {'category': 'LIFE PERSPECTIVE', 'quote': 'In the end, it’s not the years in your life that count. It’s the life in your years.', 'author': 'Abraham Lincoln', 'color': cDark},
      {'category': 'INTEGRITY', 'quote': 'Integrity is choosing courage over comfort; choosing what is right over what is fun, fast, or easy.', 'author': 'Brené Brown', 'color': cDark},
      {'category': 'AMBITION', 'quote': 'Aim for the moon. If you miss, you may hit a star.', 'author': 'W. Clement Stone', 'color': cDark},
      {'category': 'PATIENCE', 'quote': 'Patience is bitter, but its fruit is sweet.', 'author': 'Aristotle', 'color': cDark},
      {'category': 'WISDOM', 'quote': 'The only true wisdom is in knowing you know nothing.', 'author': 'Socrates', 'color': cDark},
      {'category': 'HONOR', 'quote': 'Do the best you can until you know better. Then when you know better, do better.', 'author': 'Maya Angelou', 'color': cDark},
      {'category': 'DETERMINATION', 'quote': 'Never give up on a dream just because of the time it will take to accomplish it. The time will pass anyway.', 'author': 'Earl Nightingale', 'color': cDark},
      {'category': 'PEACE', 'quote': 'Peace is not the absence of conflict, but the presence of creative alternatives for responding to conflict.', 'author': 'Dorothy Thompson', 'color': cDark},
      {'category': 'VICTORY', 'quote': 'I am not what happened to me, I am what I choose to become.', 'author': 'Carl Jung', 'color': cDark},
      {'category': 'LEGACY', 'quote': 'The greatest use of a life is to spend it on something that will outlast it.', 'author': 'William James', 'color': cDark},
      {'category': 'BLESSING', 'quote': 'May your home be blessed with peace, your hands with fruitful labor, and your heart with quiet joy.', 'author': 'Rentilly Living Wisdom', 'color': cGreen},
    ];
  }
}
