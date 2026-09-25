import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../constants/app_colors.dart';
import '../../models/external_legal_order.dart';
import '../../models/user_profile.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../widgets/external_legal_order_modal.dart';

class ExternalLegalScreen extends StatefulWidget {
  const ExternalLegalScreen({super.key});

  @override
  State<ExternalLegalScreen> createState() => _ExternalLegalScreenState();
}

class _ExternalLegalScreenState extends State<ExternalLegalScreen> {
  final NumberFormat _currencyFormat = NumberFormat('#,###', 'en_US');
  UserProfile? _currentUser;
  List<ExternalLegalOrder> _orders = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final user = await AuthService.getCurrentUser();
    if (!mounted) return;
    setState(() => _currentUser = user);

    if (user != null) {
      final orders = await ApiService.fetchUserExternalLegalOrders(
        userId: user.id,
        email: user.email,
      );
      if (mounted) {
        setState(() {
          _orders = orders;
          _isLoading = false;
        });
      }
    } else {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _openOrderModal([String? serviceType]) {
    if (_currentUser == null) return;
    ExternalLegalOrderModal.show(
      context,
      user: _currentUser!,
      preselectedService: serviceType,
      onOrderSubmitted: _loadData,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        title: Text(
          'Legal & Title Services ⚖️',
          style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, size: 22, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadData,
          color: AppColors.primary,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Hero Banner
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF042F2E), Color(0xFF064E3B), Color(0xFF0D5C46)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF064E3B).withValues(alpha: 0.25),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF34D399).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'EXTERNAL TITLES & DEEDS',
                          style: GoogleFonts.plusJakartaSans(fontSize: 8.5, fontWeight: FontWeight.w800, color: const Color(0xFF34D399)),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Buy, Sell & Verify with Legal Confidence',
                        style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white, height: 1.25),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Conduct independent title due diligence or draft authentic conveyancing instruments for private, off-market, or developer real estate across Nigeria.',
                        style: GoogleFonts.plusJakartaSans(fontSize: 11, color: Colors.white.withValues(alpha: 0.8), height: 1.35),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // 3 Service Offerings
                Text('AVAILABLE STANDALONE LEGAL SERVICES', style: GoogleFonts.plusJakartaSans(fontSize: 9.5, fontWeight: FontWeight.w800, color: AppColors.textSecondary, letterSpacing: 0.8)),
                const SizedBox(height: 10),

                _buildServiceCard(
                  title: 'Single Document Verification',
                  feeText: '₦50,000 Flat',
                  description: 'Authenticity audit on Survey Plan, Deed, Court Judgment, or Purchase Receipt.',
                  icon: Icons.find_in_page_rounded,
                  badgeColor: const Color(0xFF059669),
                  onTap: () => _openOrderModal('single_doc_50k'),
                ),
                const SizedBox(height: 10),

                _buildServiceCard(
                  title: 'Comprehensive Title & Registry Search',
                  feeText: '₦100,000 Flat',
                  description: 'Multi-document investigation across State Land Registries, Surveyor General charting, Gazette/excision, & Certified Legal Opinion.',
                  icon: Icons.account_balance_rounded,
                  badgeColor: const Color(0xFFD97706),
                  onTap: () => _openOrderModal('multi_doc_100k'),
                ),
                const SizedBox(height: 10),

                _buildServiceCard(
                  title: 'Real Estate Legal Document Preparation',
                  feeText: '3% of Property Value',
                  description: 'Custom drafting of Deed of Assignment, Contract of Sale, Power of Attorney, and Governor\'s Consent filing docket.',
                  icon: Icons.history_edu_rounded,
                  badgeColor: const Color(0xFF1E3A8A),
                  onTap: () => _openOrderModal('doc_preparation_3pct'),
                ),
                const SizedBox(height: 22),

                // Order History Section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('YOUR LEGAL DOCKETS & SEARCHES', style: GoogleFonts.plusJakartaSans(fontSize: 9.5, fontWeight: FontWeight.w800, color: AppColors.textSecondary, letterSpacing: 0.8)),
                    if (_orders.isNotEmpty)
                      Text('${_orders.length} Total', style: GoogleFonts.plusJakartaSans(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppColors.primary)),
                  ],
                ),
                const SizedBox(height: 10),

                if (_isLoading)
                  const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2)))
                else if (_orders.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.borderDark),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.gavel_rounded, size: 36, color: Color(0xFF94A3B8)),
                        const SizedBox(height: 10),
                        Text(
                          'No Active Legal Requests',
                          style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'When you request document verification or legal drafting for external properties, your active dockets and certified reports will appear here.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.textSecondary, height: 1.35),
                        ),
                      ],
                    ),
                  )
                else
                  Column(
                    children: _orders.map((o) => _buildOrderTile(o)).toList(),
                  ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildServiceCard({
    required String title,
    required String feeText,
    required String description,
    required IconData icon,
    required Color badgeColor,
    required VoidCallback onTap,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: badgeColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(icon, color: badgeColor, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                decoration: BoxDecoration(
                  color: badgeColor,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  feeText,
                  style: GoogleFonts.plusJakartaSans(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.textSecondary, height: 1.3),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F172A),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Request Service', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 4),
                  const Icon(Icons.arrow_forward_rounded, size: 14),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderTile(ExternalLegalOrder order) {
    Color statusColor = const Color(0xFFD97706);
    String statusLabel = 'PENDING REVIEW';

    if (order.isCompleted) {
      statusColor = const Color(0xFF16A34A);
      statusLabel = 'COMPLETED & CERTIFIED';
    } else if (order.isInProgress) {
      statusColor = const Color(0xFF2563EB);
      statusLabel = 'SEARCH IN PROGRESS';
    } else if (order.isRejected) {
      statusColor = const Color(0xFFDC2626);
      statusLabel = 'REJECTED';
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: order.isCompleted ? const Color(0xFFBBF7D0) : const Color(0xFFE2E8F0)),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'ORDER #${order.id}',
                style: GoogleFonts.plusJakartaSans(fontSize: 9, fontWeight: FontWeight.w800, color: AppColors.textSecondary, letterSpacing: 0.6),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  statusLabel,
                  style: GoogleFonts.plusJakartaSans(fontSize: 8.5, fontWeight: FontWeight.w800, color: statusColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            order.propertyTitle,
            style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 2),
          Text(
            '${order.propertyAddress}, ${order.propertyState}',
            style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Fee: ₦${_currencyFormat.format(order.feeAmount)}',
                style: GoogleFonts.plusJakartaSans(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppColors.primary),
              ),
              Text(
                DateFormat('dd MMM yyyy').format(order.createdAt),
                style: GoogleFonts.plusJakartaSans(fontSize: 10.5, color: AppColors.textSecondary),
              ),
            ],
          ),
          if (order.reportSummary != null && order.reportSummary!.isNotEmpty) ...[
            const Divider(height: 16, color: Color(0xFFE2E8F0)),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(10)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('LEGAL OPINION & VERDICT', style: GoogleFonts.plusJakartaSans(fontSize: 8.5, fontWeight: FontWeight.w800, color: AppColors.textSecondary)),
                  const SizedBox(height: 3),
                  Text(order.reportSummary!, style: GoogleFonts.plusJakartaSans(fontSize: 10.5, color: const Color(0xFF334155), height: 1.3)),
                  if (order.assignedCounselName != null) ...[
                    const SizedBox(height: 4),
                    Text('Signed by: ${order.assignedCounselName} (${order.assignedCounselNba ?? "NBA"})', style: GoogleFonts.plusJakartaSans(fontSize: 9.5, fontWeight: FontWeight.bold, color: AppColors.primary)),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
