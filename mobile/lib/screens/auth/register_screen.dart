import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../constants/app_colors.dart';
import '../../constants/nigerian_states_cities.dart';
import '../../services/auth_service.dart';
import '../../services/push_notification_service.dart';
import '../../services/otp_service.dart';
import '../../widgets/login_2fa_modal.dart';
import '../main_navigation_screen.dart';
import '../../widgets/inline_otp_verification_widget.dart';
import '../../utils/phone_utils.dart';

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
  final TextEditingController _tinNumberController = TextEditingController();
  final TextEditingController _signatoryRoleController = TextEditingController();
  final TextEditingController _officeStreetController = TextEditingController();
  final TextEditingController _officeLandmarkController = TextEditingController();
  final TextEditingController _managingPartnerIdController = TextEditingController();
  final TextEditingController _referralCodeController = TextEditingController();

  late String _selectedRole; // 'renter', 'partner', 'owner'
  String _buyerType = 'personal'; // 'personal' or 'corporate'
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
    _tinNumberController.dispose();
    _signatoryRoleController.dispose();
    _officeStreetController.dispose();
    _officeLandmarkController.dispose();
    _managingPartnerIdController.dispose();
    _referralCodeController.dispose();
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
      if (_step == 1) {
        return _buyerType == 'corporate' ? 'Corporate Buyer Entity' : 'Personal Details';
      }
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
      if (_step == 1) {
        return _buyerType == 'corporate'
            ? 'Enter company CAC, tax ID & authorized signatory details'
            : 'Enter your legal name, phone number, and state';
      }
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
    } else if (_selectedRole == 'owner') {
      if (_step == 1) {
        if (_nameController.text.trim().isEmpty) {
          setState(() => _errorMessage = 'Please enter your Full Legal Name.');
          return;
        }
        if (_phoneController.text.trim().isEmpty) {
          setState(() => _errorMessage = 'Please enter your mobile phone number.');
          return;
        }
        final formattedP = PhoneUtils.tryFormatToE164(_phoneController.text);
        if (formattedP == null || !PhoneUtils.isValidE164(formattedP)) {
          setState(() => _errorMessage = 'Please enter a valid mobile number (e.g. 08012345678 or +2348012345678).');
          return;
        }
        if (_cityAreaController.text.trim().isEmpty) {
          setState(() => _errorMessage = 'Please enter your City, Town, or Area.');
          return;
        }
        setState(() => _step = 2);
        return;
      }
    } else {
      // Renter / Buyer Role
      if (_step == 1) {
        if (_buyerType == 'corporate') {
          if (_businessNameController.text.trim().isEmpty) {
            setState(() => _errorMessage = 'Please enter your Registered Company / Business Name (CAC).');
            return;
          }
          if (_cacNumberController.text.trim().isEmpty) {
            setState(() => _errorMessage = 'Please enter your CAC Registration Number (RC / BN).');
            return;
          }
          if (_nameController.text.trim().isEmpty) {
            setState(() => _errorMessage = 'Please enter Authorized Signatory / Director Name.');
            return;
          }
          if (_phoneController.text.trim().isEmpty) {
            setState(() => _errorMessage = 'Please enter official contact phone number.');
            return;
          }
          final formattedP = PhoneUtils.tryFormatToE164(_phoneController.text);
          if (formattedP == null || !PhoneUtils.isValidE164(formattedP)) {
            setState(() => _errorMessage = 'Please enter a valid mobile number (e.g. 08012345678 or +2348012345678).');
            return;
          }
          if (_officeStreetController.text.trim().isEmpty) {
            setState(() => _errorMessage = 'Please enter your corporate office address.');
            return;
          }
          if (_cityAreaController.text.trim().isEmpty) {
            setState(() => _errorMessage = 'Please enter your City, Town, or Commercial District.');
            return;
          }
          setState(() => _step = 2);
          return;
        } else {
          // Personal Buyer / Renter
          if (_nameController.text.trim().isEmpty) {
            setState(() => _errorMessage = 'Please enter your Full Legal Name.');
            return;
          }
          if (_phoneController.text.trim().isEmpty) {
            setState(() => _errorMessage = 'Please enter your mobile phone number.');
            return;
          }
          final formattedP = PhoneUtils.tryFormatToE164(_phoneController.text);
          if (formattedP == null || !PhoneUtils.isValidE164(formattedP)) {
            setState(() => _errorMessage = 'Please enter a valid mobile number (e.g. 08012345678 or +2348012345678).');
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
    final email = _emailController.text.trim();
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

    final phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      setState(() => _errorMessage = 'Please enter your mobile phone number.');
      return;
    }

    if (ApiService.featureFlags.requirePhoneVerification && !_isPhoneVerified) {
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
    if (effectiveRole == 'partner' || (effectiveRole == 'renter' && _buyerType == 'corporate')) {
      fullOfficeAddress = '$street${landmark.isNotEmpty ? ", Near $landmark" : ""}${area.isNotEmpty ? ", $area" : ""}, $_selectedLga LGA, $_selectedState State';
    }

    final locationState = '${area.isNotEmpty ? "$area, " : ""}$_selectedLga LGA, $_selectedState State';
    final cleanPhone = PhoneUtils.tryFormatToE164(phone) ?? (phone.startsWith('0') ? '+234${phone.substring(1)}' : phone);
    
    String cleanName = name;
    if (effectiveRole == 'renter' && _buyerType == 'corporate') {
      cleanName = _businessNameController.text.trim().isNotEmpty ? _businessNameController.text.trim() : (name.isNotEmpty ? name : 'Corporate User');
    } else if (cleanName.isEmpty) {
      cleanName = _businessNameController.text.trim().isNotEmpty ? _businessNameController.text.trim() : 'User';
    }

    // 1. Dispatch OTP code to user's email for registration verification
    final otpRes = await OtpService.sendOtp(
      email: email,
      phoneNumber: cleanPhone,
      userName: cleanName,
      channel: 'email',
      purpose: 'Account Registration Verification',
    );

    setState(() => _isLoading = false);

    if (otpRes['success'] != true) {
      setState(() => _errorMessage = otpRes['message'] ?? 'Could not dispatch verification code to your email. Please try again.');
      return;
    }

    if (!mounted) return;

    // 2. Present 6-digit OTP verification modal
    Login2faModal.show(
      context,
      email: email,
      userName: cleanName,
      onVerified: () async {
        setState(() => _isLoading = true);

        final result = await AuthService.register(
          fullName: cleanName,
          email: email,
          phoneNumber: cleanPhone,
          password: password,
          role: effectiveRole,
          buyerType: effectiveRole == 'renter' ? _buyerType : (effectiveRole == 'partner' ? 'corporate' : 'personal'),
          state: locationState,
          businessName: (effectiveRole == 'partner' || (effectiveRole == 'renter' && _buyerType == 'corporate')) ? _businessNameController.text.trim() : null,
          cacNumber: (effectiveRole == 'partner' || (effectiveRole == 'renter' && _buyerType == 'corporate')) ? _cacNumberController.text.trim() : null,
          tinNumber: (effectiveRole == 'renter' && _buyerType == 'corporate') ? _tinNumberController.text.trim() : null,
          officeAddress: fullOfficeAddress,
          signatoryName: (effectiveRole == 'renter' && _buyerType == 'corporate') ? name : null,
          signatoryRole: (effectiveRole == 'renter' && _buyerType == 'corporate') ? _signatoryRoleController.text.trim() : null,
          signatoryPhone: (effectiveRole == 'renter' && _buyerType == 'corporate') ? cleanPhone : null,
          referralCode: _referralCodeController.text.trim().isNotEmpty ? _referralCodeController.text.trim().toUpperCase() : null,
        );

        if (mounted) setState(() => _isLoading = false);

        if (result['success'] == true) {
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
          if (mounted) {
            setState(() {
              _errorMessage = result['message'] ?? 'Sign up failed. Please try again.';
            });
          }
        }
      },
    );
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
                                  : (_step == 0
                                      ? 'Get Started ➔'
                                      : 'Continue to Step ${_step + 2} ➔'),
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13.5,
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
              const SizedBox(height: 12),

              // Version & Mode Indicator
              Center(
                child: Text(
                  'Rentilly Mobile v1.1.0 (Build 10) • Concept 1 Active 🇳🇬',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMuted,
                  ),
                ),
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

  // STEP 0: Role Selection (Concept 1: Luxury Neomorphic 3D Cards)
  Widget _buildRoleSelectionStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Luxury Trust Header
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF042F2E), Color(0xFF064E3B), Color(0xFF0D5C46)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFF34D399).withValues(alpha: 0.35), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF064E3B).withValues(alpha: 0.3),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0D5C46), Color(0xFF042F2E)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF34D399).withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.asset(
                    'assets/images/logo.png',
                    width: 44,
                    height: 44,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Rentilly: Direct & Escrow Protected',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Zero 20% agent cuts. 100% legal escrow security across Nigeria.',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 9.5,
                        color: const Color(0xFFD1FAE5),
                        height: 1.25,
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
          subtitle: 'Direct access to verified property owners. Zero agency markups with 100% legal escrow security.',
          icon: Icons.cottage_rounded,
          badgeText: 'MOST POPULAR 🌟',
          badgeColor: const Color(0xFF059669),
          accentGradient: const [Color(0xFF059669), Color(0xFF10B981)],
          glowingPills: [
            {'label': 'Zero 20% Agent Cut', 'gradient': [Color(0xFF065F46), Color(0xFF047857)]},
            {'label': '100% Escrow Shield', 'gradient': [Color(0xFF0F766E), Color(0xFF0D9488)]},
          ],
          highlights: [
            '₦0 Middleman markups — rent direct from verified owners',
            '100% Escrow protection until key handover & check-in',
            'Save for rent & borrow up to 80% instant credit advance',
          ],
        ),
        const SizedBox(height: 14),

        // Role 2: Direct Landlord / Owner
        _buildRoleSelectionCard(
          id: 'owner',
          title: 'Property Owner / Landlord',
          tagline: 'Own or manage real estate assets in Nigeria',
          subtitle: 'List apartments, screen verified tenants with BVN/NIN, and receive direct automated rent settlements.',
          icon: Icons.vpn_key_rounded,
          badgeText: 'DIRECT ASSET OWNER 🏛️',
          badgeColor: const Color(0xFFD97706),
          accentGradient: const [Color(0xFFD97706), Color(0xFFF59E0B)],
          glowingPills: [
            {'label': 'Direct Rent Payouts', 'gradient': [Color(0xFF92400E), Color(0xFFB45309)]},
            {'label': 'Verified Tenants (BVN/NIN)', 'gradient': [Color(0xFF78350F), Color(0xFF92400E)]},
          ],
          highlights: [
            'Direct automated rent settlements to your bank account',
            'Comprehensive identity & background check on tenants',
            'Automated legal digital leases, deeds & tenancy notices',
          ],
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
          badgeColor: const Color(0xFF1E3A8A),
          accentGradient: const [Color(0xFF1E3A8A), Color(0xFF3B82F6)],
          glowingPills: [
            {'label': '2.5% Escrow Cut', 'gradient': [Color(0xFF1E293B), Color(0xFF1E3A8A)]},
            {'label': 'CAC Verified Desk', 'gradient': [Color(0xFF0F172A), Color(0xFF1E293B)]},
          ],
          highlights: [
            'Guaranteed 2.5% on rentals and 2.0% on property sales',
            'CAC-accredited partner desk with digital ID verification',
            'Dedicated commissions & escrow payout vault',
          ],
        ),
        const SizedBox(height: 16),

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
    required List<Map<String, dynamic>> glowingPills,
    required List<String> highlights,
  }) {
    final isSelected = _selectedRole == id;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _selectedRole = id);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeInOutCubic,
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? badgeColor.withValues(alpha: 0.035) : Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: isSelected ? badgeColor : const Color(0xFFE2E8F0),
            width: isSelected ? 2.2 : 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected ? badgeColor.withValues(alpha: 0.18) : Colors.black.withValues(alpha: 0.03),
              blurRadius: isSelected ? 18 : 8,
              offset: Offset(0, isSelected ? 6 : 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Bar: 3D Emblem Container + Badge + Radio Selector
            Row(
              children: [
                // 3D Tactile Hero Icon Emblem
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isSelected ? accentGradient : [const Color(0xFFF8FAFC), const Color(0xFFE2E8F0)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: (isSelected ? badgeColor : Colors.black).withValues(alpha: isSelected ? 0.35 : 0.06),
                        blurRadius: isSelected ? 12 : 6,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Icon(
                      icon,
                      size: 24,
                      color: isSelected ? Colors.white : const Color(0xFF334155),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Badge Tag
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                        decoration: BoxDecoration(
                          color: badgeColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: badgeColor.withValues(alpha: 0.25), width: 0.8),
                        ),
                        child: Text(
                          badgeText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 8.5,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                            color: badgeColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // Radio Selector Checkmark
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected ? badgeColor : Colors.white,
                    border: Border.all(
                      color: isSelected ? badgeColor : const Color(0xFFCBD5E1),
                      width: 2.0,
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
                fontSize: 16,
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

            // Glowing Dual-Gradient Pill Tags
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: glowingPills.map((pill) {
                final List<Color> colors = List<Color>.from(pill['gradient'] ?? [badgeColor, badgeColor]);
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isSelected ? colors : [const Color(0xFFF1F5F9), const Color(0xFFE2E8F0)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: colors.first.withValues(alpha: 0.3),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Text(
                    pill['label'] ?? '',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: isSelected ? Colors.white : const Color(0xFF475569),
                    ),
                  ),
                );
              }).toList(),
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
          ],
        ),
      ),
    );
  }

  // STEP 1 FOR RENTER / HOME BUYER: Personal or Corporate Details
  Widget _buildRenterDetailsStep() {
    final currentLgas = NigerianStatesLgas.getLgasForState(_selectedState);
    final effectiveLga = currentLgas.contains(_selectedLga) ? _selectedLga : currentLgas.first;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Buyer Persona Segmented Toggle
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() {
                      _buyerType = 'personal';
                      _errorMessage = null;
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: _buyerType == 'personal' ? Colors.white : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: _buyerType == 'personal'
                          ? [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.06),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.person_outline_rounded,
                          size: 16,
                          color: _buyerType == 'personal' ? AppColors.primary : AppColors.textSecondary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Personal Buyer',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: _buyerType == 'personal' ? AppColors.primary : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() {
                      _buyerType = 'corporate';
                      _errorMessage = null;
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: _buyerType == 'corporate' ? Colors.white : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: _buyerType == 'corporate'
                          ? [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.06),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.business_rounded,
                          size: 16,
                          color: _buyerType == 'corporate' ? AppColors.primary : AppColors.textSecondary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Corporate Buyer',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: _buyerType == 'corporate' ? AppColors.primary : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        if (_buyerType == 'personal') ...[
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

          // City / Town / Area / Estate (Typed)
          Text('CITY / TOWN / AREA / ESTATE', style: GoogleFonts.plusJakartaSans(fontSize: 8.5, fontWeight: FontWeight.w800, letterSpacing: 0.9, color: AppColors.textSecondary)),
          const SizedBox(height: 6),
          TextField(
            controller: _cityAreaController,
            textCapitalization: TextCapitalization.words,
            style: GoogleFonts.plusJakartaSans(fontSize: 13, color: AppColors.textPrimary, fontWeight: FontWeight.w600),
            decoration: _buildInputDecoration('e.g. Lekki Phase 1 or Bodija or Maitama', Icons.location_city_rounded),
          ),
        ] else ...[
          // Corporate Buyer Form Fields
          // Registered Company Name
          Text('REGISTERED COMPANY / BUSINESS NAME (CAC)', style: GoogleFonts.plusJakartaSans(fontSize: 8.5, fontWeight: FontWeight.w800, letterSpacing: 0.9, color: AppColors.textSecondary)),
          const SizedBox(height: 6),
          TextField(
            controller: _businessNameController,
            textCapitalization: TextCapitalization.words,
            style: GoogleFonts.plusJakartaSans(fontSize: 13, color: AppColors.textPrimary, fontWeight: FontWeight.w600),
            decoration: _buildInputDecoration('e.g. Davsop Global Logistics Limited', Icons.business_rounded),
          ),
          const SizedBox(height: 14),

          // CAC Registration Number
          Text('CAC REGISTRATION NUMBER (RC / BN)', style: GoogleFonts.plusJakartaSans(fontSize: 8.5, fontWeight: FontWeight.w800, letterSpacing: 0.9, color: AppColors.textSecondary)),
          const SizedBox(height: 6),
          TextField(
            controller: _cacNumberController,
            textCapitalization: TextCapitalization.characters,
            style: GoogleFonts.plusJakartaSans(fontSize: 13, color: AppColors.textPrimary, fontWeight: FontWeight.w600),
            decoration: _buildInputDecoration('e.g. RC-1849201 or BN-2938102', Icons.badge_outlined),
          ),
          const SizedBox(height: 14),

          // Tax Identification Number (TIN)
          Text('TAX IDENTIFICATION NUMBER (TIN - OPTIONAL)', style: GoogleFonts.plusJakartaSans(fontSize: 8.5, fontWeight: FontWeight.w800, letterSpacing: 0.9, color: AppColors.textSecondary)),
          const SizedBox(height: 6),
          TextField(
            controller: _tinNumberController,
            keyboardType: TextInputType.text,
            style: GoogleFonts.plusJakartaSans(fontSize: 13, color: AppColors.textPrimary, fontWeight: FontWeight.w600),
            decoration: _buildInputDecoration('e.g. 23940192-0001 (For WHT Invoicing)', Icons.receipt_long_rounded),
          ),
          const SizedBox(height: 14),

          // Authorized Signatory Full Name
          Text('AUTHORIZED SIGNATORY / DIRECTOR FULL LEGAL NAME', style: GoogleFonts.plusJakartaSans(fontSize: 8.5, fontWeight: FontWeight.w800, letterSpacing: 0.9, color: AppColors.textSecondary)),
          const SizedBox(height: 6),
          TextField(
            controller: _nameController,
            textCapitalization: TextCapitalization.words,
            style: GoogleFonts.plusJakartaSans(fontSize: 13, color: AppColors.textPrimary, fontWeight: FontWeight.w600),
            decoration: _buildInputDecoration('e.g. David S. Adeleke', Icons.person_outline_rounded),
          ),
          const SizedBox(height: 14),

          // Signatory Role / Title
          Text('SIGNATORY DESIGNATION / ROLE (OPTIONAL)', style: GoogleFonts.plusJakartaSans(fontSize: 8.5, fontWeight: FontWeight.w800, letterSpacing: 0.9, color: AppColors.textSecondary)),
          const SizedBox(height: 6),
          TextField(
            controller: _signatoryRoleController,
            textCapitalization: TextCapitalization.words,
            style: GoogleFonts.plusJakartaSans(fontSize: 13, color: AppColors.textPrimary, fontWeight: FontWeight.w600),
            decoration: _buildInputDecoration('e.g. Managing Director / Legal Counsel', Icons.work_outline_rounded),
          ),
          const SizedBox(height: 14),

          // Official Contact Phone Number
          Text('OFFICIAL CONTACT PHONE NUMBER', style: GoogleFonts.plusJakartaSans(fontSize: 8.5, fontWeight: FontWeight.w800, letterSpacing: 0.9, color: AppColors.textSecondary)),
          const SizedBox(height: 6),
          TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            style: GoogleFonts.plusJakartaSans(fontSize: 13, color: AppColors.textPrimary, fontWeight: FontWeight.w600),
            decoration: _buildInputDecoration('0705 029 9636 or 0802 384 2014', Icons.phone_android_rounded),
          ),
          const SizedBox(height: 14),

          // Corporate Office Street Address
          Text('REGISTERED OFFICE STREET ADDRESS', style: GoogleFonts.plusJakartaSans(fontSize: 8.5, fontWeight: FontWeight.w800, letterSpacing: 0.9, color: AppColors.textSecondary)),
          const SizedBox(height: 6),
          TextField(
            controller: _officeStreetController,
            textCapitalization: TextCapitalization.words,
            style: GoogleFonts.plusJakartaSans(fontSize: 13, color: AppColors.textPrimary, fontWeight: FontWeight.w600),
            decoration: _buildInputDecoration('e.g. 74, Lawal Bus stop, Governor\'s Road, Ikotun', Icons.storefront_rounded),
          ),
          const SizedBox(height: 14),

          // State of Operation (Full Width)
          Text('STATE OF OPERATION / HEADQUARTERS', style: GoogleFonts.plusJakartaSans(fontSize: 8.5, fontWeight: FontWeight.w800, letterSpacing: 0.9, color: AppColors.textSecondary)),
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

          // LGA (Full Width)
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

          // City / Commercial District (Typed)
          Text('CITY / COMMERCIAL DISTRICT', style: GoogleFonts.plusJakartaSans(fontSize: 8.5, fontWeight: FontWeight.w800, letterSpacing: 0.9, color: AppColors.textSecondary)),
          const SizedBox(height: 6),
          TextField(
            controller: _cityAreaController,
            textCapitalization: TextCapitalization.words,
            style: GoogleFonts.plusJakartaSans(fontSize: 13, color: AppColors.textPrimary, fontWeight: FontWeight.w600),
            decoration: _buildInputDecoration('e.g. Ikotun / Alimosho or Victoria Island', Icons.location_city_rounded),
          ),
        ],
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
    final bool requirePhoneOtp = ApiService.featureFlags.requirePhoneVerification;

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
                  requirePhoneOtp
                      ? 'Enter your Email and Phone, then tap the green "Verify" button to receive your 6-digit OTP codes.'
                      : 'Enter your Email and tap the green "Verify" button to receive your 6-digit security code.',
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

        // 2. Phone Input (with SMS OTP if enabled by feature flag, otherwise standard input)
        if (requirePhoneOtp)
          InlineOtpVerificationWidget(
            label: 'Mobile Phone Number (SMS)',
            hintText: 'e.g. 0812 345 6789',
            prefixIcon: Icons.phone_android_rounded,
            textController: _phoneController,
            keyboardType: TextInputType.phone,
            channel: 'sms',
            isVerified: _isPhoneVerified,
            onVerifiedChanged: (val) => setState(() => _isPhoneVerified = val),
          )
        else ...[
          Text('MOBILE PHONE NUMBER', style: GoogleFonts.plusJakartaSans(fontSize: 8.5, fontWeight: FontWeight.w800, letterSpacing: 0.9, color: AppColors.textSecondary)),
          const SizedBox(height: 6),
          TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            style: GoogleFonts.plusJakartaSans(fontSize: 13, color: AppColors.textPrimary, fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              prefixIcon: const Icon(Icons.phone_android_rounded, size: 18, color: AppColors.primary),
              hintText: 'e.g. 0812 345 6789',
              hintStyle: GoogleFonts.plusJakartaSans(fontSize: 13, color: AppColors.textMuted),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
            ),
          ),
        ],
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

        // Referral Code (Optional)
        Text('REFERRAL CODE (OPTIONAL)', style: GoogleFonts.plusJakartaSans(fontSize: 8.5, fontWeight: FontWeight.w800, letterSpacing: 0.9, color: AppColors.textSecondary)),
        const SizedBox(height: 6),
        TextField(
          controller: _referralCodeController,
          textCapitalization: TextCapitalization.characters,
          style: GoogleFonts.plusJakartaSans(fontSize: 13, color: AppColors.textPrimary, fontWeight: FontWeight.w700, letterSpacing: 1.2),
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            prefixIcon: const Icon(Icons.card_giftcard_rounded, size: 18, color: AppColors.primary),
            hintText: 'e.g. RENT8821',
            hintStyle: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.textMuted, letterSpacing: 0),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.borderDark)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.borderDark)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            const Icon(Icons.stars_rounded, size: 12, color: Color(0xFF10B981)),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                'Get ₦1,000 instant welcome reward & referrer receives ₦500 upon KYC completion.',
                style: GoogleFonts.plusJakartaSans(fontSize: 9.5, color: const Color(0xFF059669), fontWeight: FontWeight.w600),
              ),
            ),
          ],
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
                  '• Caution deposit 100% safeguarded in Rentilly Escrow.\n'
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
