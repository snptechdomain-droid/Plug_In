import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:particles_flutter/particles_flutter.dart';
import 'package:app/services/role_database_service.dart';
import 'package:app/widgets/glass_container.dart';
import 'package:app/widgets/custom_text_field.dart';

enum _ForgotStep { request, verify, reset }

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final RoleBasedDatabaseService _databaseService = RoleBasedDatabaseService();
  final _usernameController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final List<TextEditingController> _otpControllers =
      List.generate(6, (_) => TextEditingController());

  _ForgotStep _step = _ForgotStep.request;
  bool _isLoading = false;
  String? _usernameOrEmail;

  @override
  void dispose() {
    _usernameController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    for (final ctrl in _otpControllers) {
      ctrl.dispose();
    }
    super.dispose();
  }

  Future<void> _requestOtp() async {
    if (_usernameController.text.trim().isEmpty) {
      _showSnack('Please enter a username or email');
      return;
    }
    setState(() => _isLoading = true);
    final username = _usernameController.text.trim();
    final (success, message) = await _databaseService.requestPasswordReset(username);
    setState(() => _isLoading = false);

    if (success) {
      setState(() {
        _usernameOrEmail = username;
        _step = _ForgotStep.verify;
      });
      _showSnack('OTP sent (mocked as 123456)');
    } else {
      if (message == 'User does not exist') {
        _showInvalidOtpDialog(message: 'User does not exist');
      } else {
        _showSnack(message ?? 'Unable to start reset. Please try again.');
      }
    }
  }

  String _enteredOtp() => _otpControllers.map((c) => c.text.trim()).join();

  Future<void> _verifyOtp() async {
    final otp = _enteredOtp();
    if (otp.length != 6) {
      _showSnack('Enter the 6-digit OTP');
      return;
    }
    if (_usernameOrEmail == null) return;
    setState(() => _isLoading = true);
    final (valid, message) = await _databaseService.verifyPasswordOtp(
      _usernameOrEmail!,
      otp,
    );
    setState(() => _isLoading = false);

    if (valid) {
      setState(() => _step = _ForgotStep.reset);
    } else {
      _showInvalidOtpDialog(message: message ?? 'Invalid OTP, please try again.');
      _otpControllers.forEach((c) => c.clear());
    }
  }

  Future<void> _resetPassword() async {
    if (_usernameOrEmail == null) return;
    final newPass = _newPasswordController.text.trim();
    final confirmPass = _confirmPasswordController.text.trim();
    if (newPass.isEmpty || confirmPass.isEmpty) {
      _showSnack('Please fill both password fields');
      return;
    }
    if (newPass != confirmPass) {
      _showSnack('Passwords do not match');
      return;
    }

    setState(() => _isLoading = true);
    final (success, msg) = await _databaseService.resetPasswordWithOtp(
      _usernameOrEmail!,
      _enteredOtp(),
      newPass,
    );
    setState(() => _isLoading = false);

    if (success) {
      if (mounted) {
        _showSnack('Password updated. Please login.');
        Navigator.of(context).pushReplacementNamed('/login');
      }
    } else {
      _showInvalidOtpDialog(message: msg ?? 'Invalid OTP, please try again.');
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  void _showInvalidOtpDialog({String message = 'Invalid OTP, please try again.'}) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('OTP Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          )
        ],
      ),
    );
  }

  Widget _buildOtpInput(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List.generate(6, (index) {
        return SizedBox(
          width: 44,
          child: TextField(
            controller: _otpControllers[index],
            maxLength: 1,
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            style: theme.textTheme.headlineSmall?.copyWith(
              letterSpacing: 2,
              fontFamily: 'monospace',
            ),
            decoration: InputDecoration(
              counterText: '',
              filled: true,
              fillColor: theme.colorScheme.primary.withOpacity(0.06),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onChanged: (value) {
              if (value.length == 1 && index < 5) {
                FocusScope.of(context).nextFocus();
              } else if (value.isEmpty && index > 0) {
                FocusScope.of(context).previousFocus();
              }
            },
          ),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Forgot Password'),
      ),
      body: Stack(
        children: [
          if (!kIsWeb)
            CircularParticle(
              key: UniqueKey(),
              awayRadius: 80,
              numberOfParticles: 90,
              speedOfParticles: 1,
              height: size.height,
              width: size.width,
              onTapAnimation: true,
              particleColor: isDark
                  ? Colors.white.withOpacity(0.12)
                  : Colors.black.withOpacity(0.1),
              awayAnimationDuration: const Duration(milliseconds: 600),
              maxParticleSize: 8,
              isRandSize: true,
              isRandomColor: true,
              randColorList: [
                theme.colorScheme.primary,
                theme.colorScheme.secondary,
                Colors.white,
                Colors.grey,
              ],
              awayAnimationCurve: Curves.easeInOutBack,
              enableHover: true,
              hoverColor: Colors.white,
              hoverRadius: 90,
              connectDots: true,
            ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: GlassContainer(
                  padding: const EdgeInsets.all(24),
                  borderRadius: BorderRadius.circular(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _step == _ForgotStep.request
                            ? 'Request OTP'
                            : _step == _ForgotStep.verify
                                ? 'Verify OTP'
                                : 'Reset Password',
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Securely reset your password in three quick steps.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: isDark ? Colors.white70 : Colors.black54,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      if (_step == _ForgotStep.request) ...[
                        CustomTextField(
                          controller: _usernameController,
                          labelText: 'Username / Email',
                          hintText: 'Enter your username or email',
                          enabled: !_isLoading,
                          prefixIcon: Icon(Icons.person_outline,
                              color: theme.colorScheme.primary),
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _requestOtp,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: theme.colorScheme.primary,
                              foregroundColor: theme.colorScheme.onPrimary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text(
                                    'Get OTP',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.3),
                                  ),
                          ),
                        ),
                      ] else if (_step == _ForgotStep.verify) ...[
                        Text(
                          'Enter the 6-digit code sent to your account',
                          style: theme.textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 16),
                        _buildOtpInput(context),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _verifyOtp,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: theme.colorScheme.primary,
                              foregroundColor: theme.colorScheme.onPrimary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text(
                                    'Verify OTP',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                          ),
                        ),
                      ] else ...[
                        CustomTextField(
                          controller: _newPasswordController,
                          labelText: 'New Password',
                          hintText: 'Enter new password',
                          obscureText: true,
                          prefixIcon: Icon(Icons.lock_outline,
                              color: theme.colorScheme.primary),
                        ),
                        const SizedBox(height: 16),
                        CustomTextField(
                          controller: _confirmPasswordController,
                          labelText: 'Confirm Password',
                          hintText: 'Re-enter new password',
                          obscureText: true,
                          prefixIcon: Icon(Icons.lock_reset,
                              color: theme.colorScheme.secondary),
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _resetPassword,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: theme.colorScheme.primary,
                              foregroundColor: theme.colorScheme.onPrimary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text(
                                    'Change Password',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ],
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


