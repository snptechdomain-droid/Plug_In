import 'package:flutter/material.dart';
import 'package:app/services/role_database_service.dart';
import 'package:app/widgets/custom_text_field.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

enum _ForgotStep { request, verify, reset }

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  _ForgotStep _step = _ForgotStep.request;
  final _usernameController = TextEditingController();
  final _otpController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  bool _isLoading = false;
  final _auth = RoleBasedDatabaseService();

  @override
  void dispose() {
    _usernameController.dispose();
    _otpController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _requestOtp() async {
    if (_usernameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter username')));
      return;
    }
    setState(() => _isLoading = true);
    final success = await _auth.requestPasswordReset(_usernameController.text);
    setState(() => _isLoading = false);

    if (success) {
      setState(() => _step = _ForgotStep.verify);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User not found or failed to send OTP')));
    }
  }

  Future<void> _verifyOtp() async {
     if (_otpController.text.isEmpty) return;
     setState(() => _isLoading = true);
     // Simulate Verification for now or use backend if available
     final success = await _auth.verifyOtp(_usernameController.text, _otpController.text);
     setState(() => _isLoading = false);

     if (success) {
       setState(() => _step = _ForgotStep.reset);
     } else {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid OTP')));
     }
  }

  Future<void> _resetPassword() async {
    if (_newPasswordController.text != _confirmPasswordController.text) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Passwords do not match')));
       return;
    }
    setState(() => _isLoading = true);
    final success = await _auth.resetPasswordWithOtp(
      _usernameController.text, 
      _otpController.text, 
      _newPasswordController.text
    );
    setState(() => _isLoading = false);

    if (success) {
       if (mounted) Navigator.pop(context); // Go back to login
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password reset successfully! Login now.')));
    } else {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to reset password')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reset Password')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_step == _ForgotStep.request) ...[
              const Text('Enter your username to receive an OTP', textAlign: TextAlign.center),
              const SizedBox(height: 20),
              CustomTextField(
                controller: _usernameController,
                labelText: 'Username or Email',
                prefixIcon: const Icon(Icons.person),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _isLoading ? null : _requestOtp,
                child: _isLoading ? const CircularProgressIndicator() : const Text('Send OTP'),
              ),
            ] else if (_step == _ForgotStep.verify) ...[
              const Text('Enter the 6-digit OTP sent to your email', textAlign: TextAlign.center),
              const SizedBox(height: 20),
              CustomTextField(
                controller: _otpController,
                labelText: 'OTP',
                prefixIcon: const Icon(Icons.password),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _isLoading ? null : _verifyOtp,
                child: _isLoading ? const CircularProgressIndicator() : const Text('Verify'),
              ),
            ] else ...[
              const Text('Enter your new password', textAlign: TextAlign.center),
              const SizedBox(height: 20),
              CustomTextField(
                controller: _newPasswordController,
                labelText: 'New Password',
                obscureText: true,
                prefixIcon: const Icon(Icons.lock),
              ),
              const SizedBox(height: 10),
               CustomTextField(
                controller: _confirmPasswordController,
                labelText: 'Confirm Password',
                obscureText: true,
                prefixIcon: const Icon(Icons.lock),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _isLoading ? null : _resetPassword,
                child: _isLoading ? const CircularProgressIndicator() : const Text('Reset Password'),
              ),
            ]
          ],
        ),
      ),
    );
  }
}
