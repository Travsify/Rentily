import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_colors.dart';

class PartnerLegalModal extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<Map<String, dynamic>> sections;

  const PartnerLegalModal({
    super.key,
    required this.title,
    required this.subtitle,
    required this.sections,
  });

  // 1. Partner Legal Desk Modal
  static void showLegalDesk(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const PartnerLegalModal(
        title: 'Partner Legal Desk ⚖️',
        subtitle: 'Corporate Brokerage Mandate & Arbitration Terms',
        sections: [
          {
            'icon': Icons.verified_user_rounded,
            'title': '1. Corporate Brokerage Mandate & Exclusive Representation',
            'content':
                'As an accredited Rentilly Corporate Partner, your listings are protected under Nigerian Commercial Agency Law. Partners warrant that all property listings are backed by an executed Power of Attorney or verified Landlord Representation Mandate.',
          },
          {
            'icon': Icons.savings_rounded,
            'title': '2. 100% Escrow Commission Protection (2.5% / 2.0%)',
            'content':
                'Rentilly platform escrow locks tenant and buyer payments securely. Corporate Partner commissions (2.5% on annual leases and 2.0% on outright sales) are automatically credited to your Escrow Settlement Vault immediately upon tenant move-in confirmation.',
          },
          {
            'icon': Icons.shield_rounded,
            'title': '3. Anti-Ghost Shield & Physical Presence Warranty',
            'content':
                'To safeguard consumer trust and maintain zero-fraud standards, partners must provide an impromptu physical selfie in front of the property. Fabricated listings, duplicate media, or unauthorized postings result in immediate license forfeiture.',
          },
          {
            'icon': Icons.link_rounded,
            'title': '4. Landlord Auto-Link & Anti-Circumvention Policy',
            'content':
                'When you onboard landlords using your unique partner link, all current and future properties listed by that landlord are permanently mapped to your brokerage profile, preventing landlord circumvention.',
          },
          {
            'icon': Icons.gavel_rounded,
            'title': '5. Dispute Resolution & Tribunal Arbitration',
            'content':
                'In the event of an ownership contest or tenancy disagreement, Rentilly Legal Desk arbitrates within 72 hours in coordination with the Lagos Multi-Door Courthouse and state property regulatory authorities.',
          },
        ],
      ),
    );
  }

  // 2. Partner Privacy Policy & Escrow Terms Modal
  static void showPrivacyAndEscrow(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const PartnerLegalModal(
        title: 'Partner Privacy & Escrow Policy 🛡️',
        subtitle: 'Corporate NDPR Compliance & Financial Settlement Rules',
        sections: [
          {
            'icon': Icons.lock_outline_rounded,
            'title': '1. Corporate Data Protection & NDPR Compliance',
            'content':
                'All partner CAC corporate documents, Tax Identification Numbers (TIN), Director BVNs, and office addresses are encrypted using 256-bit AES cryptographic protocols under the Nigeria Data Protection Regulation (NDPR).',
          },
          {
            'icon': Icons.description_outlined,
            'title': '2. Title & Landlord Document Confidentiality',
            'content':
                'Deeds of Assignment, Certificates of Occupancy (C of O), and electricity meter utility bills uploaded during verification are used exclusively for title auditing and are never shared or made public to third parties.',
          },
          {
            'icon': Icons.account_balance_wallet_outlined,
            'title': '3. Dedicated Partner Escrow Settlement Accounts',
            'content':
                'Each accredited partner receives a dedicated virtual settlement account (Flutterwave MFB) for receiving direct payouts, escrow commission disbursements, and instant platform withdrawals to their registered commercial bank.',
          },
          {
            'icon': Icons.security_rounded,
            'title': '4. 48-Hour Inspection & Key Handover Settlement',
            'content':
                'Tenant funds remain in secure tripartite escrow during the move-in inspection window. Once keys are released and the tenant signs off, the system triggers instant commission split to your partner wallet.',
          },
          {
            'icon': Icons.verified_rounded,
            'title': '5. Zero Hidden Deductions Guarantee',
            'content':
                'Rentilly charges zero hidden listing fees or partner subscription charges. Partner commissions are disbursed in full with transparent PDF statements and receipt generation.',
          },
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Header Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.borderDark)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.gavel_rounded, size: 18, color: AppColors.primary),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                        ),
                        Text(
                          subtitle,
                          style: GoogleFonts.plusJakartaSans(fontSize: 10, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 22, color: AppColors.textPrimary),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),

          // Content List
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: sections.length,
              itemBuilder: (context, index) {
                final sec = sections[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(sec['icon'] as IconData, size: 16, color: AppColors.primary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              sec['title'] as String,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        sec['content'] as String,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          color: const Color(0xFF475569),
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          // Bottom Action Button
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(
                  'I Understand & Agree',
                  style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
