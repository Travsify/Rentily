import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../constants/app_colors.dart';

class MessagesScreen extends StatelessWidget {
  const MessagesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final sampleChats = [
      {
        'name': 'Chief Adebayo Falana',
        'property': 'Luxury 4-Bed Duplex Lekki Phase 1',
        'lastMessage': 'Good day! I have confirmed your 11:00 AM inspection gate pass.',
        'time': '10:45 AM',
        'unread': true,
        'verified': true,
      },
      {
        'name': 'Dr. Somtochukwu Eze',
        'property': 'Ambassadorial Mansion Maitama',
        'lastMessage': 'The C of O deed documents are available for your lawyer to review.',
        'time': 'Yesterday',
        'unread': false,
        'verified': true,
      },
      {
        'name': 'Mrs. Folashade Adeleke',
        'property': 'Waterfront 3-Bed Ikoyi',
        'lastMessage': 'Keys and prepaid meter card are ready for move-in handover.',
        'time': '28 Aug',
        'unread': false,
        'verified': true,
      }
    ];

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Text(
                'Direct Owner Messages',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Chat & voice call direct property owners with privacy masking.',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 14),

              // Anti-Scam Security Notice Banner
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F382A).withOpacity(0.35),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.primaryLight.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.security_rounded, size: 16, color: AppColors.primaryLight),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Keep all communications and payments inside Rentilly Escrow to qualify for the 30-Day Move-In Guarantee.',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Chat List
              Expanded(
                child: ListView.builder(
                  itemCount: sampleChats.length,
                  itemBuilder: (context, index) {
                    final chat = sampleChats[index];
                    final isUnread = chat['unread'] as bool;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceDark,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isUnread
                              ? AppColors.primaryLight.withOpacity(0.5)
                              : AppColors.borderDark.withOpacity(0.4),
                        ),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 22,
                            backgroundColor: AppColors.primaryLight.withOpacity(0.2),
                            child: Text(
                              chat['name'].toString().isNotEmpty ? chat['name'].toString()[0] : 'O',
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.bold,
                                color: AppColors.primaryLight,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          chat['name'].toString(),
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        const Icon(Icons.check_circle, size: 12, color: AppColors.primaryLight),
                                      ],
                                    ),
                                    Text(
                                      chat['time'].toString(),
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 9,
                                        color: AppColors.textMuted,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  chat['property'].toString(),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primaryLight,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  chat['lastMessage'].toString(),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 10,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
