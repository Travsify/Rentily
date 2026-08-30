import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../constants/app_colors.dart';
import '../../models/property.dart';
import '../../services/api_service.dart';
import '../home/property_detail_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Property> _results = [];
  bool _isLoading = false;
  final NumberFormat _currencyFormat = NumberFormat('#,###', 'en_US');

  final List<String> _popularNeighborhoods = [
    'Lekki Phase 1',
    'Old Ikoyi',
    'Victoria Island',
    'Ikeja GRA',
    'Maitama',
    'Wuse 2',
    'Guzape',
    'Banana Island'
  ];

  @override
  void initState() {
    super.initState();
    _performSearch('');
  }

  void _performSearch(String query) async {
    setState(() => _isLoading = true);
    final props = await ApiService.asyncFetchProperties(search: query);
    setState(() {
      _results = props;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title
              Text(
                'Search & Discover',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),

              // Search Bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceDark,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.borderDark.withOpacity(0.6)),
                ),
                child: TextField(
                  controller: _searchController,
                  onSubmitted: _performSearch,
                  style: GoogleFonts.plusJakartaSans(fontSize: 12, color: Colors.white),
                  decoration: InputDecoration(
                    icon: const Icon(Icons.search_rounded, size: 18, color: AppColors.textSecondary),
                    hintText: 'Search by estate, neighborhood, or bedroom count...',
                    hintStyle: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.textMuted),
                    border: InputBorder.none,
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 16, color: Colors.grey),
                            onPressed: () {
                              _searchController.clear();
                              _performSearch('');
                            },
                          )
                        : null,
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Quick Neighborhood Chips
              SizedBox(
                height: 32,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _popularNeighborhoods.length,
                  itemBuilder: (context, index) {
                    final n = _popularNeighborhoods[index];
                    return GestureDetector(
                      onTap: () {
                        _searchController.text = n;
                        _performSearch(n);
                      },
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceDark,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.borderDark.withOpacity(0.4)),
                        ),
                        child: Text(
                          n,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),

              // Results Count
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${_results.length} Verified Properties Found',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Results List
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator(color: AppColors.primaryLight))
                    : ListView.builder(
                        itemCount: _results.length,
                        itemBuilder: (context, index) {
                          final prop = _results[index];
                          return GestureDetector(
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => PropertyDetailScreen(property: prop)),
                              );
                            },
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceDark,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: AppColors.borderDark.withOpacity(0.5)),
                              ),
                              child: Row(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Image.network(
                                      prop.images.isNotEmpty ? prop.images[0] : '',
                                      width: 80,
                                      height: 80,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          prop.title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '${prop.neighborhood}, ${prop.state}',
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 10,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              '₦${_currencyFormat.format(prop.basePrice)}',
                                              style: GoogleFonts.plusJakartaSans(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w800,
                                                color: AppColors.primaryLight,
                                              ),
                                            ),
                                            Text(
                                              '${prop.bedrooms} Bed • ${prop.bathrooms} Bath',
                                              style: GoogleFonts.plusJakartaSans(
                                                fontSize: 9,
                                                color: AppColors.textMuted,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
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
