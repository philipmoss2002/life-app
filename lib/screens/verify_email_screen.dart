import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/authentication_service.dart';
import 'new_document_list_screen.dart';

class VerifyEmailScreen extends StatefulWidget {
  final String email;
  final bool fromSignIn;

  const VerifyEmailScreen({
    super.key,
    required this.email,
    this.fromSignIn = false,
  });

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  final _verificationCodeController = TextEditingController();

  bool _isLoading = false;
  bool _isResending = false;
  String? _errorMessage;
  bool _isVerifyButtonEnabled = false;

  @override
  void initState() {
    super.initState();
    // Add listener to update button state on text changes
    _verificationCodeController.addListener(_updateButtonState);
  }

  @override
  void dispose() {
    _verificationCodeController.removeListener(_updateButtonState);
    _verificationCodeController.dispose();
    super.dispose();
  }

  void _updateButtonState() {
    final isValid = _isCodeValid();
    if (isValid != _isVerifyButtonEnabled) {
      setState(() {
        _isVerifyButtonEnabled = isValid;
      });
    }
  }

  bool _isCodeValid() {
    final code = _verificationCodeController.text;
    return code.length == 6 && RegExp(r'^\d{6}$').hasMatch(code);
  }

  /// Map AWS Cognito errors to user-friendly messages
  String _getErrorMessage(String error) {
    final errorLower = error.toLowerCase();

    // CodeMismatchException - Invalid verification code
    if (errorLower.contains('code mismatch') ||
        errorLower.contains('invalid code') ||
        errorLower.contains('invalid verification code')) {
      return 'Invalid verification code. Please check and try again.';
    }

    // ExpiredCodeException - Code has expired
    if (errorLower.contains('expired')) {
      return 'Verification code has expired. Please request a new code.';
    }

    // LimitExceededException - Too many attempts
    if (errorLower.contains('limit exceeded') ||
        errorLower.contains('too many attempts')) {
      return 'Too many attempts. Please wait a moment and try again.';
    }

    // UserNotFoundException - Account not found
    if (errorLower.contains('user') && errorLower.contains('not found')) {
      return 'Account not found. Please sign up again.';
    }

    // NotAuthorizedException - Already verified
    if (errorLower.contains('not authorized') ||
        errorLower.contains('already verified') ||
        errorLower.contains('already confirmed')) {
      return 'Account already verified. Please sign in.';
    }

    // NetworkException - Network error
    if (errorLower.contains('network')) {
      return 'Network error. Please check your connection.';
    }

    // Generic fallback error message
    return 'Verification failed. Please try again.';
  }

  /// Handle verification submission
  Future<void> _handleVerification() async {
    if (!_isCodeValid() || _isLoading) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authService = AuthenticationService();
      final result = await authService.confirmSignUp(
        widget.email,
        _verificationCodeController.text,
      );

      if (!mounted) return;

      if (result.success) {
        // Navigate to document list screen on successful verification
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => const NewDocumentListScreen(),
          ),
          (route) => false,
        );
      } else {
        setState(() {
          _errorMessage = _getErrorMessage(result.message);
          _isLoading = false;
        });
      }
    } on AuthenticationException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = _getErrorMessage(e.message);
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = _getErrorMessage(e.toString());
        _isLoading = false;
      });
    }
  }

  /// Handle resend code request
  Future<void> _handleResendCode() async {
    if (_isResending) {
      return;
    }

    setState(() {
      _isResending = true;
      _errorMessage = null;
    });

    try {
      final authService = AuthenticationService();
      await authService.resendSignUpCode(widget.email);

      if (!mounted) return;

      // Clear verification code input field on success
      _verificationCodeController.clear();

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
                'A new verification code has been sent to your email'),
            backgroundColor: Colors.green[700],
            duration: const Duration(seconds: 3),
          ),
        );
      }

      setState(() {
        _isResending = false;
      });
    } on AuthenticationException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = _getErrorMessage(e.message);
        _isResending = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = _getErrorMessage(e.toString());
        _isResending = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Verify Email'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              Icon(
                Icons.email_outlined,
                size: 80,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                'Verify Your Email',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'We sent a verification code to',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[600],
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                widget.email,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              if (_errorMessage != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red[300]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: Colors.red[700]),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(color: Colors.red[700]),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 16),
              // Verification code input field
              TextField(
                controller: _verificationCodeController,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(6),
                ],
                maxLength: 6,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      letterSpacing: 8,
                      //fontWeight: FontWeight.bold,
                    ),
                decoration: InputDecoration(
                  labelText: 'Verification Code',
                  hintText: '000000',
                  counterText: '',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey[400]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: Theme.of(context).colorScheme.primary,
                      width: 2,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // Verify button
              ElevatedButton(
                onPressed: _isVerifyButtonEnabled && !_isLoading
                    ? _handleVerification
                    : null,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text(
                        'Verify Account',
                        style: TextStyle(fontSize: 16),
                      ),
              ),
              const SizedBox(height: 24),
              // Resend code section
              Center(
                child: Column(
                  children: [
                    Text(
                      "Didn't receive the code?",
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey[600],
                          ),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _isResending ? null : _handleResendCode,
                      child: _isResending
                          ? const SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              'Resend Code',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Back to sign in link
              Center(
                child: TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text(
                    'Back to Sign In',
                    style: TextStyle(fontSize: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
