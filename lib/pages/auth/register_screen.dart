import 'package:flutter/material.dart';
import 'package:orthoq_app/theme/orthoq_colors.dart';
import 'package:orthoq_app/theme/orthoq_theme.dart';
import 'package:orthoq_app/theme/orthoq_widgets.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'email_verification_page.dart';
import 'login_screen.dart';
import '../../services/auth_service.dart';
import '../../utils/auth_navigation.dart';
import '../../utils/validation_utils.dart';

class RegisterScreen extends StatefulWidget {
  final String userType;

  const RegisterScreen({super.key, required this.userType});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _phoneNumberController = TextEditingController();
  final _emailController = TextEditingController();
  final _icNumberController = TextEditingController();
  final _homeAddressController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  // Doctor-specific fields
  final _specializationController = TextEditingController();
  final _credentialsController = TextEditingController();
  File? _pickedImageFile;
  final ImagePicker _imagePicker = ImagePicker();
  
  // Staff-specific fields
  final _staffIdController = TextEditingController();
  
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;
  bool _hasCapital = false;
  bool _hasNumber = false;
  bool _hasSymbol = false;
  bool _isLengthValid = false;

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneNumberController.dispose();
    _emailController.dispose();
    _icNumberController.dispose();
    _homeAddressController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _specializationController.dispose();
    _credentialsController.dispose();
    _staffIdController.dispose();
    super.dispose();
  }

  Future<void> _pickProfileImage() async {
    if (_isLoading) return;

    try {
      final pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );
      if (pickedFile == null || !mounted) return;

      setState(() {
        _pickedImageFile = File(pickedFile.path);
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not open gallery: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _doctorProfilePreview() {
    if (_pickedImageFile != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.file(
          _pickedImageFile!,
          height: 140,
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _doctorProfilePlaceholder(),
        ),
      );
    }

    return _doctorProfilePlaceholder();
  }

  Widget _doctorProfilePlaceholder() {
    return Container(
      height: 140,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.add_a_photo_outlined, size: 48, color: Colors.grey.shade500),
          const SizedBox(height: 8),
          Text(
            'Tap to add profile photo',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Validate password match
    if (_passwordController.text != _confirmPasswordController.text) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Passwords do not match'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    // Check if Firebase is initialized
    if (Firebase.apps.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Firebase is not initialized. Please run: flutterfire configure',
            ),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 5),
          ),
        );
      }
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final authService = AuthService();
      
      // Determine role
      String role = widget.userType.toLowerCase();
      if (role == 'admin') {
        role = 'staff'; // Treat admin as staff
      }

      // Register user using AuthService
      // Normalize phone number before saving (strip hyphens)
      final normalizedPhone = ValidationUtils.normalizePhoneWithCountryCode(
        _phoneNumberController.text,
      );
      final registrationEmail = _emailController.text.trim();
      final String? normalizedIC = widget.userType == 'patient'
          ? ValidationUtils.normalizeICNumber(_icNumberController.text)
          : null;
      final String? homeAddressTrimmed = widget.userType == 'patient'
          ? _homeAddressController.text.trim()
          : null;

      await authService.registerWithEmailAndPassword(
        email: registrationEmail,
        password: _passwordController.text,
        fullName: _fullNameController.text.trim(),
        phoneNumber: normalizedPhone,
        icNumber: normalizedIC,
        homeAddress: homeAddressTrimmed,
        role: role,
        specialization: widget.userType == 'doctor' 
            ? _specializationController.text.trim().isNotEmpty 
                ? _specializationController.text.trim() 
                : null
            : null,
        credentials: widget.userType == 'doctor'
            ? _credentialsController.text.trim()
            : null,
        profileImageFile:
            widget.userType == 'doctor' ? _pickedImageFile : null,
        staffId: widget.userType == 'staff' || widget.userType == 'admin'
            ? _staffIdController.text.trim().isNotEmpty
                ? _staffIdController.text.trim()
                : null
            : null,
      );

      // For patients, also save to 'patients' collection for backward compatibility
      if (widget.userType == 'patient') {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          await FirebaseFirestore.instance
              .collection('patients')
              .doc(user.uid)
              .set({
            'fullName': _fullNameController.text.trim(),
            'phoneNumber': normalizedPhone,
            'email': registrationEmail,
            'icNumber': normalizedIC,
            'address': homeAddressTrimmed,
            'registrationDate': FieldValue.serverTimestamp(),
            'uid': user.uid,
          });
        }
      }

      if (mounted) {
        if (widget.userType == 'doctor') {
          await FirebaseAuth.instance.signOut();
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Account successfully created! Please log in to continue.'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => LoginScreen(userType: widget.userType),
            ),
          );
        } else if (requiresEmailVerificationPortal(widget.userType)) {
          final user = FirebaseAuth.instance.currentUser;
          if (user != null && !user.emailVerified) {
            await authService.sendEmailVerification();
          }

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => EmailVerificationPage(
                email: registrationEmail,
                loginPortal: widget.userType,
              ),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Registration successful! Please log in to continue.'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => LoginScreen(userType: widget.userType),
            ),
          );
        }
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage = 'Registration failed. Please try again.';
      if (e.code == 'weak-password') {
        errorMessage = 'The password provided is too weak.';
      } else if (e.code == 'email-already-in-use') {
        errorMessage = 'An account already exists for that email.';
      } else if (e.code == 'invalid-email') {
        errorMessage = 'The email address is invalid.';
      } else if (e.code == 'operation-not-allowed') {
        errorMessage = 'Email/password accounts are not enabled. Please contact support.';
      } else if (e.code == 'network-request-failed') {
        errorMessage = 'Network error. Please check your internet connection.';
      } else {
        errorMessage = 'Registration failed: ${e.message ?? e.code}';
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } on PlatformException catch (e) {
      String errorMessage = 'Registration failed. Please try again.';
      if (e.code == 'permission-denied' || e.code == 'PERMISSION_DENIED') {
        errorMessage = 'Permission denied. Please check Firestore security rules.';
      } else if (e.code == 'unavailable') {
        errorMessage = 'Service unavailable. Please try again later.';
      } else {
        errorMessage = 'Firestore error: ${e.message ?? e.code}';
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('An unexpected error occurred: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _updatePasswordCriteria(String value) {
    setState(() {
      _hasCapital = value.isNotEmpty && RegExp(r'^[A-Z]').hasMatch(value);
      _hasNumber = RegExp(r'[0-9]').hasMatch(value);
      _hasSymbol = RegExp(r'[!@#\$&*~_=-]').hasMatch(value);
      _isLengthValid = value.length >= 6;
    });
  }

  bool get _showsPasswordCriteria {
    final role = widget.userType.toLowerCase();
    return role == 'patient' ||
        role == 'doctor' ||
        role == 'staff' ||
        role == 'admin';
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter a password';
    }
    if (_showsPasswordCriteria) {
      if (!RegExp(r'^[A-Z]').hasMatch(value)) {
        return 'First letter must be a capital letter';
      }
      if (!RegExp(r'[0-9]').hasMatch(value)) {
        return 'Password must contain at least 1 number';
      }
      if (!RegExp(r'[!@#\$&*~_=-]').hasMatch(value)) {
        return 'Password must contain at least 1 special character';
      }
    }
    if (value.length < 6) {
      return 'Password must be at least 6 characters';
    }
    return null;
  }

  Widget _buildCriteriaRow(String text, bool isMet) {
    return Row(
      children: [
        Icon(
          isMet ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
          color: isMet ? Colors.green : Colors.grey.shade500,
          size: 16,
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: TextStyle(
            fontSize: 12,
            color: isMet ? Colors.green.shade700 : Colors.grey.shade600,
            fontWeight: isMet ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.userType.toUpperCase()} Registration'),
        backgroundColor: OrthoqColors.slateNavy,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: OrthoqSpacing.form,
          child: Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 20),
                Icon(
                  widget.userType == 'doctor' 
                      ? Icons.medical_services
                      : widget.userType == 'staff' || widget.userType == 'admin'
                          ? Icons.badge
                          : Icons.person_add,
                  size: 80,
                  color: OrthoqColors.slateNavy,
                ),
                const SizedBox(height: 24),
                Text(
                  'Create ${widget.userType.toUpperCase()} Account',
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: OrthoqSpacing.lg),
                
                // Full Name Field
                TextFormField(
                  controller: _fullNameController,
                  decoration: OrthoqTheme.field(
                    labelText: 'Full Name',
                    prefixIcon: const Icon(Icons.person),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your full name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: OrthoqSpacing.md),
                
                // Phone Number Field
                TextFormField(
                  controller: _phoneNumberController,
                  keyboardType: TextInputType.phone,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                  ],
                  decoration: OrthoqTheme.field(
                    labelText: 'Phone Number',
                    prefixText: '+60 ',
                    prefixIcon: const Icon(Icons.phone),
                  ),
                  validator: ValidationUtils.validateMalaysianPhoneAfterPrefix,
                ),
                const SizedBox(height: OrthoqSpacing.md),

                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: OrthoqTheme.field(
                    labelText: 'Email',
                    prefixIcon: const Icon(Icons.email),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your email';
                    }
                    if (!value.contains('@')) {
                      return 'Please enter a valid email';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: OrthoqSpacing.md),

                if (widget.userType == 'patient') ...[
                  TextFormField(
                    controller: _icNumberController,
                    keyboardType: TextInputType.number,
                    decoration: OrthoqTheme.field(
                      labelText: 'IC Number',
                      hintText: 'e.g., 990101-14-5678',
                      prefixIcon: const Icon(Icons.credit_card),
                    ),
                    validator: ValidationUtils.validateMalaysianIC,
                  ),
                  const SizedBox(height: OrthoqSpacing.md),
                  TextFormField(
                    controller: _homeAddressController,
                    keyboardType: TextInputType.multiline,
                    textCapitalization: TextCapitalization.sentences,
                    minLines: 3,
                    maxLines: 6,
                    decoration: OrthoqTheme.field(
                      labelText: 'Home Address',
                      alignLabelWithHint: true,
                      prefixIcon: const Icon(Icons.home_outlined),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter your home address';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: OrthoqSpacing.md),
                ],
                
                // Doctor Specialization Field (only for doctors)
                if (widget.userType == 'doctor') ...[
                  TextFormField(
                    controller: _specializationController,
                    decoration: OrthoqTheme.field(
                      labelText: 'Specialization',
                      hintText: 'e.g., Orthopedic Surgeon',
                      prefixIcon: const Icon(Icons.work),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your specialization';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: OrthoqSpacing.md),
                  TextFormField(
                    controller: _credentialsController,
                    maxLines: 2,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: OrthoqTheme.field(
                      labelText: 'Credentials',
                      hintText: 'e.g., MBBCh, MS Ortho',
                      alignLabelWithHint: true,
                      prefixIcon: const Icon(Icons.school_outlined),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter your credentials';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: OrthoqSpacing.md),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Profile photo',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade800,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _isLoading ? null : _pickProfileImage,
                      borderRadius: BorderRadius.circular(12),
                      child: _doctorProfilePreview(),
                    ),
                  ),
                  if (_pickedImageFile != null) ...[
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: _isLoading
                            ? null
                            : () => setState(() => _pickedImageFile = null),
                        icon: const Icon(Icons.delete_outline, size: 18),
                        label: const Text('Remove photo'),
                      ),
                    ),
                  ],
                  const SizedBox(height: OrthoqSpacing.md),
                ],
                
                // Staff ID Field (only for staff/admin)
                if (widget.userType == 'staff' || widget.userType == 'admin') ...[
                  TextFormField(
                    controller: _staffIdController,
                    decoration: OrthoqTheme.field(
                      labelText: 'Staff ID',
                      hintText: 'Optional',
                      prefixIcon: const Icon(Icons.badge),
                    ),
                  ),
                  const SizedBox(height: OrthoqSpacing.md),
                ],
                
                // Password Field
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  onChanged:
                      _showsPasswordCriteria ? _updatePasswordCriteria : null,
                  decoration: OrthoqTheme.field(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility : Icons.visibility_off,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                  ),
                  validator: _validatePassword,
                ),
                if (_showsPasswordCriteria) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12.0,
                      vertical: 8.0,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildCriteriaRow(
                          'First letter must be a Capital letter',
                          _hasCapital,
                        ),
                        const SizedBox(height: 4),
                        _buildCriteriaRow(
                          'Must contain at least 1 number',
                          _hasNumber,
                        ),
                        const SizedBox(height: 4),
                        _buildCriteriaRow(
                          'Must contain at least 1 special character/symbol',
                          _hasSymbol,
                        ),
                        const SizedBox(height: 4),
                        _buildCriteriaRow(
                          'Password must be at least 6 characters',
                          _isLengthValid,
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: OrthoqSpacing.md),
                
                // Confirm Password Field
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: _obscureConfirmPassword,
                  decoration: OrthoqTheme.field(
                    labelText: 'Confirm Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirmPassword ? Icons.visibility : Icons.visibility_off,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscureConfirmPassword = !_obscureConfirmPassword;
                        });
                      },
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please confirm your password';
                    }
                    if (value != _passwordController.text) {
                      return 'Passwords do not match';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: OrthoqSpacing.lg),
                
                // Register Button
                ElevatedButton(
                  onPressed: _isLoading ? null : _handleRegister,
                  style: OrthoqTheme.primaryButton,
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Register'),
                ),
                const SizedBox(height: OrthoqSpacing.md),
                
                // Login Link
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Already have an account? '),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      child: const Text('Login'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

