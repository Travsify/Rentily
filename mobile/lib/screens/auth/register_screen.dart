import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../constants/app_colors.dart';
import '../../constants/nigerian_states_cities.dart';
import '../../services/auth_service.dart';
import '../../services/push_notification_service.dart';
import '../main_navigation_screen.dart';
import '../../widgets/inline_otp_verification_widget.dart';

class RegisterScreen extends StatefulWidget {
  final String initialRole;

  const RegisterScreen({
    super.key,
    this.initialRole = 'renter',
  });

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  int _step = 0; // Current wizard step index

  // User input controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _cityAreaController = TextEditingController();
  
  // Corporate controllers
  final TextEditingController _businessNameController = TextEditingController();
  final TextEditingController _cacNumberController = TextEditingController();
  final TextEditingController _officeStreetController = TextEditingController();
  final TextEditingController _officeLandmarkController = TextEditingController();
  final TextEditingController _managingPartnerIdController = TextEditingController();

  late String _selectedRole; // 'renter', 'partner', 'owner'
  String _selectedState = 'Lagos';
  String _selectedLga = 'Eti-Osa';
  bool _obscurePassword = true;
  bool _agreedToTerms = true;
  bool _isLoading = false;
  bool _isEmailVerified = false;
  bool _isPhoneVerified = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    if (widget.initialRole == 'partner') {
      _selectedRole = 'partner';
    } else if (widget.initialRole == 'owner' || widget.initialRole == 'landlord') {
      _selectedRole = 'owner';
    } else {
      _selectedRole = 'renter';
    }
    _selectedLga = NigerianStatesLgas.getLgasForState(_selectedState).first;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _cityAreaController.dispose();
    _businessNameController.dispose();
    _cacNumberController.dispose();
    _officeStreetController.dispose();
    _officeLandmarkController.dispose();
    _managingPartnerIdController.dispose();
    super.dispose();
  }

  int get _totalSteps => _selectedRole == 'partner' ? 4 : 3;

  String get _stepTitle {
    if (_step == 0) return 'Choose Account Type';
    if (_selectedRole == 'partner') {
      if (_step == 1) return 'Corporate Entity';
      if (_step == 2) return 'Director & Region';
      return 'Security & Credentials';
    } else if (_selectedRole == 'owner') {
      if (_step == 1) return 'Landlord Details';
      return 'Security & Credentials';
    } else {
      if (_step == 1) return 'Personal Details';
      return 'Security & Credentials';
    }
  }

  String get _stepSubtitle {
    if (_step == 0) return 'Select your role to configure your Rentilly portal';
    if (_selectedRole == 'partner') {
      if (_step == 1) return 'Provide your registered corporate firm details';
      if (_step == 2) return 'Enter principal director / broker information';
      return 'Set your corporate password and review partner rules';
    } else if (_selectedRole == 'owner') {
      if (_step == 1) return 'Enter your property owner name & region';
      return 'Set your login credentials and secure password';
    } else {
      if (_step == 1) return 'Enter your legal name, phone number, and state';
      return 'Set your password and login credentials';
    }
  }

  void _goToNextStep() {
    setState(() => _errorMessage = null);

    // Validation for Step 0
    if (_step == 0) {
      setState(() => _step = 1);
      return;
    }

    // Validation for Step 1
    if (_selectedRole == 'partner') {
      if (_step == 1) {
        if (_businessNameController.text.trim().isEmpty) {
          setState(() => _errorMessage = 'Please enter your Registered Business Name (CAC).');
          return;
        }
        if (_cacNumberController.text.trim().isEmpty) {
          setState(() => _errorMessage = 'Please enter your CAC Registration Number (RC / BN).');
          return;
        }
        if (_cityAreaController.text.trim().isEmpty) {
          setState(() => _errorMessage = 'Please enter your City, Town, or Commercial Area.');
          return;
        }
        if (_officeStreetController.text.trim().isEmpty) {
          setState(() => _errorMessage = 'Please enter your office street address (e.g. Suite/Plot/Street).');
          return;
        }
        setState(() => _step = 2);
        return;
      }
      if (_step == 2) {
        if (_nameController.text.trim().isEmpty) {
          setState(() => _errorMessage = 'Please enter Director / Representative Full Legal Name.');
          return;
        }
        setState(() => _step = 3);
        return;
      }
    } else {
      if (_step == 1) {
        if (_nameController.text.trim().isEmpty) {
          setState(() => _errorMessage = 'Please enter your Full Legal Name.');
          return;
        }
        if (_phoneController.text.trim().isEmpty) {
          setState(() => _errorMessage = 'Please enter your phone number.');
          return;
        }
        if (_cityAreaController.text.trim().isEmpty) {
          setState(() => _errorMessage = 'Please enter your City, Town, or Area.');
          return;
        }
        setState(() => _step = 2);
        return;
      }
    }

    // Final Step -> Trigger Registration
    _handleRegister();
  }

  void _goToPreviousStep() {
    if (_step > 0) {
      setState(() {
        _errorMessage = null;
        _step--;
      });
    } else {
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
        );
      }
    }
  }

  void _handleRegister() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = 'Please enter your email and password.');
      return;
    }

    if (password.length < 6) {
      setState(() => _errorMessage = 'Password must be at least 6 characters.');
      return;
    }

    if (!_agreedToTerms) {
      setState(() => _errorMessage = 'Please accept the Rentilly terms of service.');
      return;
    }

    if (!_isEmailVerified) {
      setState(() => _errorMessage = 'Please tap "Verify" on your Email Address and enter your 6-digit code.');
      return;
    }

    if (!_isPhoneVerified) {
      setState(() => _errorMessage = 'Please tap "Verify" on your Mobile Phone Number and enter your 6-digit SMS code.');
      return;
    }

    await _finalizeRegistration();
  }

  Future<void> _finalizeRegistration() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();
    final password = _passwordController.text;
    final effectiveRole = _selectedRole;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    // Synthesize structured address
    final street = _officeStreetController.text.trim();
    final landmark = _officeLandmarkController.text.trim();
    final area = _cityAreaController.text.trim();
    
    String? fullOfficeAddress;
    if (effectiveRole == 'partner') {
      fullOfficeAddress = '$street${landmark.isNotEmpty ? ", Near $landmark" : ""}${area.isNotEmpty ? ", $area" : ""}, $_selectedLga LGA, $_selectedState State';
    }

    final locationState = '${area.isNotEmpty ? "$area, " : ""}$_selectedLga LGA, $_selectedState State';

    final result = await AuthService.register(
      fullName: name.isNotEmpty ? name : (_businessNameController.text.trim().isNotEmpty ? _businessNameController.text.trim() : 'User'),
      email: email,
      phoneNumber: phone.startsWith('0') ? '+234${phone.substring(1)}' : phone,
      password: password,
      role: effectiveRole,
      state: locationState,
      businessName: effectiveRole == 'partner' ? _businessNameController.text.trim() : null,
      cacNumber: effectiveRole == 'partner' ? _cacNumberController.text.trim() : null,
      officeAddress: fullOfficeAddress,
    );

    setState(() => _isLoading = false);

    if (result['success'] == true) {
      // Register new user with OneSignal for push notifications
      await PushNotificationService.setUserTags();

      if (!mounted) return;
      final isPartner = effectiveRole == 'partner';
      final isLandlord = effectiveRole == 'owner' || effectiveRole == 'landlord';

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => MainNavigationScreen(
            initialPartnerMode: isPartner,
            initialLandlordMode: isLandlord,
          ),
        ),
        (route) => false,
      );
    } else {
      setState(() {
        _errorMessage = result['message'] ?? 'Sign up failed. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isFinalStep = _step == (_totalSteps - 1);

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, size: 22, color: AppColors.textPrimary),
          onPressed: _goToPreviousStep,
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (int i = 0; i < _totalSteps; i++) ...[
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                width: i == _step ? 24 : 8,
                height: 6,
                decoration: BoxDecoration(
                  color: i == _step ? AppColors.primary : (i < _step ? const Color(0xFF10B981) : const Color(0xFFE2E8F0)),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              if (i < _totalSteps - 1) const SizedBox(width: 4),
            ],
          ],
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Step Counter Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'STEP ${_step + 1} OF $_totalSteps',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.9,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // Step Title & Subtitle
              Text(
                _stepTitle,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _stepSubtitle,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 18),

              // Error Box
              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded, size: 16, color: AppColors.error),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            color: AppColors.error,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // Card Container for Current Step Content
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: AppColors.borderDark),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: _buildStepContent(),
              ),
              const SizedBox(height: 18),

              // Primary Action Button (Next or Submit)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : (isFinalStep ? _handleRegister : _goToNextStep),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isFinalStep ? AppColors.accentOrange : AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 2,
                    shadowColor: (isFinalStep ? AppColors.accentOrange : AppColors.primary).withValues(alpha: 0.35),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              isFinalStep
                                  ? (_selectedRole == 'partner'
                                      ? 'Create Corporate Account 🏢'
                                      : (_selectedRole == 'owner' ? 'Create Landlord Account 🔑' : 'Create Free Account 🚀'))
                                  : 'Continue to Step ${_step + 2} ➔',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 18),

              // Switch to Login
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Already have an account? ',
                    style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.textSecondary),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Text(
                      'Log In',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepContent() {
    if (_step == 0) {
      return _buildRoleSelectionStep();
    }

    if (_selectedRole == 'partner') {
      if (_step == 1) return _buildPartnerCorporateStep();
      if (_step == 2) return _buildPartnerDirectorStep();
      return _buildCredentialsStep();
    } else if (_selectedRole == 'owner') {
      if (_step == 1) return _buildLandlordDetailsStep();
      return _buildCredentialsStep();
    } else {
      if (_step == 1) return _buildRenterDetailsStep();
      return _buildCredentialsStep();
    }
  }

  // STEP 0: Role Selection (Catchy Luxury Real Estate Theme in Brand Colors)
  Widget _buildRoleSelectionStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Luxury Home Placement Mission Card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF042F2E), Color(0xFF064E3B), Color(0xFF0F766E)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFF4ADE80).withValues(alpha: 0.3), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF064E3B).withValues(alpha: 0.25),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF10B981), Color(0xFF059669)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF10B981).withValues(alpha: 0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Icon(Icons.shield_rounded, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Rentilly: Built by Landlords for Every Tenant/Landlord',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: -0.2,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Zero 20% agent markups. 100% legal escrow protection nationwide across Nigeria.',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 9.5,
                        color: const Color(0xFFE2E8F0),
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        Text(
          'CHOOSE YOUR ACCOUNT PERSONA',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 9,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.1,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 12),

        // Role 1: Renter / Home Buyer
        _buildRoleSelectionCard(
          id: 'renter',
          title: 'Renter / Home Buyer',
          tagline: 'Looking to rent or buy a verified home in Nigeria',
          subtitle: 'Direct connection to verified property owners. Zero agency markups with 100% legal escrow security.',
          icon: Icons.cottage_rounded,
          badgeText: 'MOST POPULAR 🌟',
          badgeColor: const Color(0xFF0D9488),
          accentGradient: const [Color(0xFF0D9488), Color(0xFF059669)],
          highlights: [
            'Zero 20% Middleman Agent Fees',
            '100% Rent & Purchase Escrow Protection',
            'Smart Salary Splitter & 24/7 Power DisCo Tokens',
          ],
          tags: ['₦0 Agent Cut', 'Escrow Shield', 'Verified Listings'],
        ),
        const SizedBox(height: 14),

        // Role 2: Direct Landlord / Owner
        _buildRoleSelectionCard(
          id: 'owner',
          title: 'Property Owner / Landlord',
          tagline: 'Own or manage real estate assets in Nigeria',
          subtitle: 'List apartments, screen verified tenants with BVN/NIN, and get direct automated rent settlements.',
          icon: Icons.vpn_key_rounded,
          badgeText: 'DIRECT ASSET OWNER 🏛️',
          badgeColor: const Color(0xFFD97706),
          accentGradient: const [Color(0xFFD97706), Color(0xFFB45309)],
          highlights: [
            'Direct Automated Rent Settlements to your bank',
            'Verified Tenant Screening with Identity Check',
            'Automated Legal Digital Leases & Tenancy Notices',
          ],
          tags: ['Direct Payouts', 'Verified Tenants', 'Digital Leases'],
        ),
        const SizedBox(height: 14),

        // Role 3: Corporate Partner / Broker
        _buildRoleSelectionCard(
          id: 'partner',
          title: 'Corporate Partner / Broker',
          tagline: 'CAC-accredited agency or corporate real estate broker',
          subtitle: 'Lock mandated developer portfolios, issue certified leases, and withdraw 2.5% escrow commissions.',
          icon: Icons.business_center_rounded,
          badgeText: '2.5% ESCROW COMMISSIONS 💼',
          badgeColor: const Color(0xFF0A2540),
          accentGradient: const [Color(0xFF0A2540), Color(0xFF1E3A8A)],
          highlights: [
            'Guaranteed 2.5% Rent & 2.0% Sales Commissions',
            'CAC Accredited Partner Digital ID & Desk',
            'Dedicated Commissions & Escrow Payout Vault',
          ],
          tags: ['2.5% Commission', 'CAC Accredited', 'Dedicated Vault'],
        ),
        const SizedBox(height: 14),

        // Trust Compliance Footer
        Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.verified_user_rounded, size: 14, color: Color(0xFF10B981)),
              const SizedBox(width: 6),
              Text(
                'NDPR Compliant • Nationwide Coverage Across the Federation 🇳🇬',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRoleSelectionCard({
    required String id,
    required String title,
    required String tagline,
    required String subtitle,
    required IconData icon,
    required String badgeText,
    required Color badgeColor,
    required List<Color> accentGradient,
    required List<String> highlights,
    required List<String> tags,
  }) {
    final isSelected = _selectedRole == id;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _selectedRole = id);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeInOut,
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? badgeColor.withValues(alpha: 0.04) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? badgeColor : const Color(0xFFE2E8F0),
            width: isSelected ? 2.2 : 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected ? badgeColor.withValues(alpha: 0.15) : Colors.black.withValues(alpha: 0.03),
              blurRadius: isSelected ? 16 : 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Bar: Hero Icon Emblem + Badge + Radio Selector
            Row(
              children: [
                // Circular Hero Icon Container
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isSelected ? accentGradient : [const Color(0xFFF1F5F9), const Color(0xFFE2E8F0)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: badgeColor.withValues(alpha: 0.35),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ]
                        : null,
                  ),
                  child: Icon(
                    icon,
                    size: 20,
                    color: isSelected ? Colors.white : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(width: 10),

                // Badge Tag
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: badgeColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: badgeColor.withValues(alpha: 0.3), width: 0.8),
                  ),
                  child: Text(
                    badgeText,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 8.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                      color: badgeColor,
                    ),
                  ),
                ),
                const Spacer(),

                // Radio Selector Checkmark
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected ? badgeColor : Colors.white,
                    border: Border.all(
                      color: isSelected ? badgeColor : const Color(0xFFCBD5E1),
                      width: 1.8,
                    ),
                  ),
                  child: isSelected
                      ? const Center(
                          child: Icon(Icons.check, size: 14, color: Colors.white),
                        )
                      : null,
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Role Title
            Text(
              title,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 15.5,
                fontWeight: FontWeight.w900,
                color: isSelected ? badgeColor : AppColors.textPrimary,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 2),

            // Tagline
            Text(
              tagline,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: isSelected ? badgeColor.withValues(alpha: 0.85) : AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 6),

            // Description
            Text(
              subtitle,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                color: const Color(0xFF475569),
                height: 1.35,
              ),
            ),
            const SizedBox(height: 10),

            // Value Proposition Highlights (Checklist)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? Colors.white : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSelected ? badgeColor.withValues(alpha: 0.2) : const Color(0xFFE2E8F0),
                ),
              ),
              child: Column(
                children: highlights.map((h) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2.5),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.check_circle_rounded, size: 14, color: isSelected ? badgeColor : const Color(0xFF10B981)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            h,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: isSelected ? AppColors.textPrimary : const Color(0xFF334155),
                              height: 1.25,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 10),

            // Feature Pills
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: tags.map((t) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                  decoration: BoxDecoration(
                    color: isSelected ? badgeColor.withValues(alpha: 0.1) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isSelected ? badgeColor.withValues(alpha: 0.35) : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Text(
                    t,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 8.5,
                      fontWeight: FontWeight.w800,
                      color: isSelected ? badgeColor : AppColors.textSecondary,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  // STEP 1 FOR RENTER: Personal Details
  Widget _buildRenterDetailsStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Full Legal Name
        Text('FULL LEGAL NAME (As on Bank Account)', style: GoogleFonts.plusJakartaSans(fontSize: 8.5, fontWeight: FontWeight.w800, letterSpacing: 0.9, color: AppColors.textSecondary)),
        const SizedBox(height: 6),
        TextField(
          controller: _nameController,
          textCapitalization: TextCapitalization.words,
          style: GoogleFonts.plusJakartaSans(fontSize: 13, color: AppColors.textPrimary, fontWeight: FontWeight.w600),
          decoration: _buildInputDecoration('e.g. Femi Adesanya', Icons.person_outline_rounded),
        ),
        const SizedBox(height: 14),

        // Phone Number
        Text('PHONE NUMBER (NIGERIA)', style: GoogleFonts.plusJakartaSans(fontSize: 8.5, fontWeight: FontWeight.w800, letterSpacing: 0.9, color: AppColors.textSecondary)),
        const SizedBox(height: 6),
        TextField(
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          style: GoogleFonts.plusJakartaSans(fontSize: 13, color: AppColors.textPrimary, fontWeight: FontWeight.w600),
          decoration: _buildInputDecoration('0812 345 6789', Icons.phone_android_rounded),
        ),
        const SizedBox(height: 14),

        // State of Residence (Full Width)
        Text('STATE OF RESIDENCE', style: GoogleFonts.plusJakartaSans(fontSize: 8.5, fontWeight: FontWeight.w800, letterSpacing: 0.9, color: AppColors.textSecondary)),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          isExpanded: true,
          value: _selectedState,
          dropdownColor: Colors.white,
          style: GoogleFonts.plusJakartaSans(fontSize: 12.5, color: AppColors.textPrimary, fontWeight: FontWeight.w600),
          decoration: _buildInputDecoration('Select State', Icons.location_on_outlined),
          items: NigerianStatesLgas.states.map((s) => DropdownMenuItem(value: s, child: Text(s, overflow: TextOverflow.ellipsis, maxLines: 1))).toList(),
          onChanged: (val) {
            if (val != null) {
              setState(() {
                _selectedState = val;
                final lgas = NigerianStatesLgas.getLgasForState(val);
                _selectedLga = lgas.contains(_selectedLga) ? _selectedLga : lgas.first;
              });
            }
          },
        ),
        const SizedBox(height: 14),

        // Local Government Area (LGA) (Full Width)
        Text('LOCAL GOVERNMENT AREA (LGA)', style: GoogleFonts.plusJakartaSans(fontSize: 8.5, fontWeight: FontWeight.w800, letterSpacing: 0.9, color: AppColors.textSecondary)),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          isExpanded: true,
          value: NigerianStatesLgas.getLgasForState(_selectedState).contains(_selectedLga)
              ? _selectedLga
              : NigerianStatesLgas.getLgasForState(_selectedState).first,
          dropdownColor: Colors.white,
          style: GoogleFonts.plusJakartaSans(fontSize: 12.5, color: AppColors.textPrimary, fontWeight: FontWeight.w600),
          decoration: _buildInputDecoration('Select LGA', Icons.account_balance_rounded),
          items: NigerianStatesLgas.getLgasForState(_selectedState)
              .map((l) => DropdownMenuItem(value: l, child: Text(l, overflow: TextOverflow.ellipsis, maxLines: 1)))
              .toList(),
          onChanged: (val) {
            if (val != null) setState(() => _selectedLga = val);
          },
        ),
        const SizedBox(height: 14),

        // City / Town / Area / Estate (Typed)
        Text('CITY / TOWN / AREA / ESTATE', style: GoogleFonts.plusJakartaSans(fontSize: 8.5, fontWeight: FontWeight.w800, letterSpacing: 0.9, color: AppColors.textSecondary)),
        const SizedBox(height: 6),
        TextField(
          controller: _cityAreaController,
          textCapitalization: TextCapitalization.words,
          style: GoogleFonts.plusJakartaSans(fontSize: 13, color: AppColors.textPrimary, fontWeight: FontWeight.w600),
          decoration: _buildInputDecoration('e.g. Lekki Phase 1 or Bodija or Maitama', Icons.location_city_rounded),
        ),
      ],
    );
  }

  // STEP 1 FOR LANDLORD: Landlord Details
  Widget _buildLandlordDetailsStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Full Legal Name
        Text('FULL LEGAL NAME (As on Property Title / Bank)', style: GoogleFonts.plusJakartaSans(fontSize: 8.5, fontWeight: FontWeight.w800, letterSpacing: 0.9, color: AppColors.textSecondary)),
        const SizedBox(height: 6),
        TextField(
          controller: _nameController,
          textCapitalization: TextCapitalization.words,
          style: GoogleFonts.plusJakartaSans(fontSize: 13, color: AppColors.textPrimary, fontWeight: FontWeight.w600),
          decoration: _buildInputDecoration('e.g. Chief Patrick Achua', Icons.real_estate_agent_rounded),
        ),
        const SizedBox(height: 14),

        // Phone Number
        Text('DIRECT CONTACT PHONE NUMBER', style: GoogleFonts.plusJakartaSans(fontSize: 8.5, fontWeight: FontWeight.w800, letterSpacing: 0.9, color: AppColors.textSecondary)),
        const SizedBox(height: 6),
        TextField(
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          style: GoogleFonts.plusJakartaSans(fontSize: 13, color: AppColors.textPrimary, fontWeight: FontWeight.w600),
          decoration: _buildInputDecoration('0812 345 6789', Icons.phone_android_rounded),
        ),
        const SizedBox(height: 14),

        // Primary Property State (Full Width)
        Text('PRIMARY PROPERTY STATE', style: GoogleFonts.plusJakartaSans(fontSize: 8.5, fontWeight: FontWeight.w800, letterSpacing: 0.9, color: AppColors.textSecondary)),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          isExpanded: true,
          value: _selectedState,
          dropdownColor: Colors.white,
          style: GoogleFonts.plusJakartaSans(fontSize: 12.5, color: AppColors.textPrimary, fontWeight: FontWeight.w600),
          decoration: _buildInputDecoration('Select State', Icons.location_on_outlined),
          items: NigerianStatesLgas.states.map((s) => DropdownMenuItem(value: s, child: Text(s, overflow: TextOverflow.ellipsis, maxLines: 1))).toList(),
          onChanged: (val) {
            if (val != null) {
              setState(() {
                _selectedState = val;
                final lgas = NigerianStatesLgas.getLgasForState(val);
                _selectedLga = lgas.contains(_selectedLga) ? _selectedLga : lgas.first;
              });
            }
          },
        ),
        const SizedBox(height: 14),

        // Property LGA (Full Width)
        Text('PROPERTY LOCAL GOVERNMENT AREA (LGA)', style: GoogleFonts.plusJakartaSans(fontSize: 8.5, fontWeight: FontWeight.w800, letterSpacing: 0.9, color: AppColors.textSecondary)),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          isExpanded: true,
          value: NigerianStatesLgas.getLgasForState(_selectedState).contains(_selectedLga)
              ? _selectedLga
              : NigerianStatesLgas.getLgasForState(_selectedState).first,
          dropdownColor: Colors.white,
          style: GoogleFonts.plusJakartaSans(fontSize: 12.5, color: AppColors.textPrimary, fontWeight: FontWeight.w600),
          decoration: _buildInputDecoration('Select LGA', Icons.account_balance_rounded),
          items: NigerianStatesLgas.getLgasForState(_selectedState)
              .map((l) => DropdownMenuItem(value: l, child: Text(l, overflow: TextOverflow.ellipsis, maxLines: 1)))
              .toList(),
          onChanged: (val) {
            if (val != null) setState(() => _selectedLga = val);
          },
        ),
        const SizedBox(height: 14),

        // City / Town / Area / Estate (Typed)
        Text('CITY / TOWN / AREA / ESTATE', style: GoogleFonts.plusJakartaSans(fontSize: 8.5, fontWeight: FontWeight.w800, letterSpacing: 0.9, color: AppColors.textSecondary)),
        const SizedBox(height: 6),
        TextField(
          controller: _cityAreaController,
          textCapitalization: TextCapitalization.words,
          style: GoogleFonts.plusJakartaSans(fontSize: 13, color: AppColors.textPrimary, fontWeight: FontWeight.w600),
          decoration: _buildInputDecoration('e.g. Ring Road / Oluyole Estate or Lekki Phase 1', Icons.location_city_rounded),
        ),
        const SizedBox(height: 14),

        // Managing Partner / Accreditation ID (Optional)
        Text('MANAGING BROKER / ACCREDITATION ID (OPTIONAL)', style: GoogleFonts.plusJakartaSans(fontSize: 8.5, fontWeight: FontWeight.w800, letterSpacing: 0.9, color: AppColors.textSecondary)),
        const SizedBox(height: 6),
        TextField(
          controller: _managingPartnerIdController,
          textCapitalization: TextCapitalization.characters,
          style: GoogleFonts.plusJakartaSans(fontSize: 13, color: AppColors.textPrimary, fontWeight: FontWeight.w600),
          decoration: _buildInputDecoration('e.g. RNT-PTR-0042 (If invited by an accredited firm)', Icons.link_rounded),
        ),
      ],
    );
  }

  // STEP 1 FOR PARTNER: Corporate Entity Details
  Widget _buildPartnerCorporateStep() {
    final currentLgas = NigerianStatesLgas.getLgasForState(_selectedState);
    final effectiveLga = currentLgas.contains(_selectedLga) ? _selectedLga : currentLgas.first;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // CAC Business Name
        Text('REGISTERED BUSINESS NAME (CAC)', style: GoogleFonts.plusJakartaSans(fontSize: 8.5, fontWeight: FontWeight.w800, letterSpacing: 0.9, color: AppColors.textSecondary)),
        const SizedBox(height: 6),
        TextField(
          controller: _businessNameController,
          textCapitalization: TextCapitalization.words,
          style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w600),
          decoration: _buildInputDecoration('e.g. Eoms Global Inclusive Limited', Icons.business_rounded),
        ),
        const SizedBox(height: 14),

        // CAC Registration Number
        Text('CAC REGISTRATION NUMBER (RC / BN)', style: GoogleFonts.plusJakartaSans(fontSize: 8.5, fontWeight: FontWeight.w800, letterSpacing: 0.9, color: AppColors.textSecondary)),
        const SizedBox(height: 6),
        TextField(
          controller: _cacNumberController,
          style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w600),
          decoration: _buildInputDecoration('e.g. RC 1928374 or BN 483920', Icons.badge_outlined),
        ),
        const SizedBox(height: 14),

        // State of Operation (Full Width)
        Text('STATE OF OPERATION', style: GoogleFonts.plusJakartaSans(fontSize: 8.5, fontWeight: FontWeight.w800, letterSpacing: 0.9, color: AppColors.textSecondary)),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          isExpanded: true,
          value: _selectedState,
          dropdownColor: Colors.white,
          style: GoogleFonts.plusJakartaSans(fontSize: 12.5, color: AppColors.textPrimary, fontWeight: FontWeight.w600),
          decoration: _buildInputDecoration('Select State', Icons.location_on_outlined),
          items: NigerianStatesLgas.states.map((s) => DropdownMenuItem(value: s, child: Text(s, overflow: TextOverflow.ellipsis, maxLines: 1))).toList(),
          onChanged: (val) {
            if (val != null) {
              setState(() {
                _selectedState = val;
                final lgas = NigerianStatesLgas.getLgasForState(val);
                _selectedLga = lgas.contains(_selectedLga) ? _selectedLga : lgas.first;
              });
            }
          },
        ),
        const SizedBox(height: 14),

        // Local Government Area (LGA) (Full Width)
        Text('LOCAL GOVERNMENT AREA (LGA)', style: GoogleFonts.plusJakartaSans(fontSize: 8.5, fontWeight: FontWeight.w800, letterSpacing: 0.9, color: AppColors.textSecondary)),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          isExpanded: true,
          value: effectiveLga,
          dropdownColor: Colors.white,
          style: GoogleFonts.plusJakartaSans(fontSize: 12.5, color: AppColors.textPrimary, fontWeight: FontWeight.w600),
          decoration: _buildInputDecoration('Select LGA', Icons.account_balance_rounded),
          items: currentLgas
              .map((l) => DropdownMenuItem(value: l, child: Text(l, overflow: TextOverflow.ellipsis, maxLines: 1)))
              .toList(),
          onChanged: (val) {
            if (val != null) setState(() => _selectedLga = val);
          },
        ),
        const SizedBox(height: 14),

        // City / Commercial Area / District (Typed)
        Text('CITY / COMMERCIAL AREA / DISTRICT', style: GoogleFonts.plusJakartaSans(fontSize: 8.5, fontWeight: FontWeight.w800, letterSpacing: 0.9, color: AppColors.textSecondary)),
        const SizedBox(height: 6),
        TextField(
          controller: _cityAreaController,
          textCapitalization: TextCapitalization.words,
          style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w600),
          decoration: _buildInputDecoration('e.g. Lekki Phase 1 or Ring Road, Oluyole', Icons.location_city_rounded),
        ),
        const SizedBox(height: 14),

        // Building / Suite No. & Street Address
        Text('OFFICE BUILDING / SUITE & STREET ADDRESS', style: GoogleFonts.plusJakartaSans(fontSize: 8.5, fontWeight: FontWeight.w800, letterSpacing: 0.9, color: AppColors.textSecondary)),
        const SizedBox(height: 6),
        TextField(
          controller: _officeStreetController,
          style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w600),
          decoration: _buildInputDecoration('e.g. Suite 4B, Plot 12 Admiralty Way', Icons.storefront_rounded),
        ),
        const SizedBox(height: 14),

        // Nearest Landmark / Bus Stop
        Text('NEAREST LANDMARK / BUS STOP', style: GoogleFonts.plusJakartaSans(fontSize: 8.5, fontWeight: FontWeight.w800, letterSpacing: 0.9, color: AppColors.textSecondary)),
        const SizedBox(height: 6),
        TextField(
          controller: _officeLandmarkController,
          style: GoogleFonts.plusJakartaSans(fontSize: 12.5, fontWeight: FontWeight.w600),
          decoration: _buildInputDecoration('e.g. Near Ebeano Supermarket', Icons.near_me_rounded),
        ),
      ],
    );
  }

  // STEP 2 FOR PARTNER: Director & Regional Operations
  Widget _buildPartnerDirectorStep() {
    final street = _officeStreetController.text.trim();
    final landmark = _officeLandmarkController.text.trim();
    final area = _cityAreaController.text.trim();
    final synthesizedAddress = '$street${landmark.isNotEmpty ? ", Near $landmark" : ""}${area.isNotEmpty ? ", $area" : ""}, $_selectedLga LGA, $_selectedState State';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Verified Corporate Headquarters Preview Banner
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF0FDF4),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFBBF7D0)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.check_circle_rounded, size: 16, color: Color(0xFF16A34A)),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'REGISTERED OFFICE LOCATION',
                      style: GoogleFonts.plusJakartaSans(fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 0.7, color: const Color(0xFF16A34A)),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      synthesizedAddress.isNotEmpty ? synthesizedAddress : 'Office details registered',
                      style: GoogleFonts.plusJakartaSans(fontSize: 10.5, color: const Color(0xFF14532D), fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Director / Representative Legal Name
        Text('PRINCIPAL DIRECTOR / REPRESENTATIVE NAME', style: GoogleFonts.plusJakartaSans(fontSize: 8.5, fontWeight: FontWeight.w800, letterSpacing: 0.9, color: AppColors.textSecondary)),
        const SizedBox(height: 6),
        TextField(
          controller: _nameController,
          textCapitalization: TextCapitalization.words,
          style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w600),
          decoration: _buildInputDecoration('e.g. Patrick Achua (Managing Director)', Icons.person_outline_rounded),
        ),
      ],
    );
  }

  // FINAL STEP: Email, Phone Verification, Password, Rules & Terms
  Widget _buildCredentialsStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Security Verification Banner
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: const Color(0xFFF0FDF4),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF86EFAC)),
          ),
          child: Row(
            children: [
              const Icon(Icons.shield_rounded, size: 20, color: Color(0xFF16A34A)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Enter your Email and Phone, then tap the green "Verify" button to receive your 6-digit OTP codes.',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF14532D),
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
        ),

        // 1. Email Verification with Resend
        InlineOtpVerificationWidget(
          label: 'Official Email Address',
          hintText: _selectedRole == 'partner' ? 'e.g. contact@drivegates.co.uk' : 'e.g. user@example.com',
          prefixIcon: Icons.email_outlined,
          textController: _emailController,
          keyboardType: TextInputType.emailAddress,
          channel: 'email',
          isVerified: _isEmailVerified,
          onVerifiedChanged: (val) => setState(() => _isEmailVerified = val),
        ),
        const SizedBox(height: 14),

        // 2. Phone Verification via SMS
        InlineOtpVerificationWidget(
          label: 'Mobile Phone Number (SMS)',
          hintText: 'e.g. 0812 345 6789',
          prefixIcon: Icons.phone_android_rounded,
          textController: _phoneController,
          keyboardType: TextInputType.phone,
          channel: 'sms',
          isVerified: _isPhoneVerified,
          onVerifiedChanged: (val) => setState(() => _isPhoneVerified = val),
        ),
        const SizedBox(height: 14),

        // Password
        Text('PASSWORD (6+ characters)', style: GoogleFonts.plusJakartaSans(fontSize: 8.5, fontWeight: FontWeight.w800, letterSpacing: 0.9, color: AppColors.textSecondary)),
        const SizedBox(height: 6),
        TextField(
          controller: _passwordController,
          obscureText: _obscurePassword,
          style: GoogleFonts.plusJakartaSans(fontSize: 13, color: AppColors.textPrimary, fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            prefixIcon: const Icon(Icons.lock_outline_rounded, size: 18, color: AppColors.primary),
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                size: 18,
                color: AppColors.textMuted,
              ),
              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
            ),
            hintText: '••••••••••••',
            hintStyle: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.textMuted),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.borderDark)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.borderDark)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
          ),
        ),
        const SizedBox(height: 14),

        if (_selectedRole == 'partner') ...[
          // Partner Rules Box
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF86EFAC)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.gavel_rounded, size: 14, color: AppColors.primary),
                    const SizedBox(width: 6),
                    Text(
                      'RENTILLY PARTNER ESCROW COVENANT',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 8.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '• 2.5% rent and 2.0% sales escrow commissions guaranteed on verified move-ins.\n'
                  '• Zero agency fees charged to prospective tenants.\n'
                  '• Caution deposit 100% safeguarded in Rentilly Living Escrow.\n'
                  '• Digital Accreditation ID Card required for all field viewings.',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 9.5,
                    color: const Color(0xFF166534),
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],

        // Terms Checkbox
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Checkbox(
              value: _agreedToTerms,
              activeColor: AppColors.primary,
              onChanged: (val) => setState(() => _agreedToTerms = val ?? true),
            ),
            Expanded(
              child: Text(
                'I accept Rentilly Terms of Service & Privacy Policy',
                style: GoogleFonts.plusJakartaSans(fontSize: 10.5, color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
      ],
    );
  }

  InputDecoration _buildInputDecoration(String hint, IconData icon) {
    return InputDecoration(
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      prefixIcon: Icon(icon, size: 18, color: AppColors.primary),
      hintText: hint,
      hintStyle: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.textMuted),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.borderDark),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.borderDark),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
    );
  }
}
