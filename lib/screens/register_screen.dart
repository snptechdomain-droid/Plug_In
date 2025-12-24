import 'package:flutter/material.dart';
import 'package:app/models/domain.dart';
import 'package:app/services/role_database_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  String _username = '';
  String _password = '';
  String _key = '';
  String _registerNumber = '';
  String _year = '';
  String _section = '';
  String _department = '';
  Domain? _selectedDomain;
  bool _isLoading = false;
  String? _error;

  final _auth = RoleBasedDatabaseService();

  Future<void> _register() async {
    if (_username.isEmpty || _password.isEmpty || _key.isEmpty) {
      setState(() { _error = 'Please fill all fields'; });
      return;
    }

    setState(() { _isLoading = true; _error = null; });
    
    final (success, message) = await _auth.register(
      username: _username,
      password: _password,
      key: _key,
      registerNumber: _registerNumber,
      year: _year,
      section: _section,
      department: _department,
      domain: _selectedDomain,
    );

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Member added successfully!')),
      );
      Navigator.of(context).pop(); // Go back to Settings
    } else {
      setState(() { _error = message; });
    }
    
    setState(() { _isLoading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add New Member')),
      body: Center(
        child: Card(
          margin: const EdgeInsets.all(24),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    decoration: const InputDecoration(
                      labelText: 'Security Key',
                      hintText: 'Enter Admin Key',
                      prefixIcon: Icon(Icons.vpn_key),
                    ),
                    obscureText: true,
                    onChanged: (v) => _key = v,
                    validator: (v) => v == null || v.isEmpty ? 'Enter key' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    decoration: const InputDecoration(
                      labelText: 'Username',
                      prefixIcon: Icon(Icons.person),
                    ),
                    onChanged: (v) => _username = v,
                    validator: (v) => v == null || v.isEmpty ? 'Enter username' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    decoration: const InputDecoration(
                      labelText: 'Password',
                      prefixIcon: Icon(Icons.lock),
                    ),
                    obscureText: true,
                    onChanged: (v) => _password = v,
                    validator: (v) => v == null || v.isEmpty ? 'Enter password' : null,
                  ),
                const SizedBox(height: 16),
                TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'Register Number',
                    prefixIcon: Icon(Icons.badge),
                  ),
                  onChanged: (v) => _registerNumber = v,
                  validator: (v) => v == null || v.isEmpty ? 'Enter register number' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'Year',
                    prefixIcon: Icon(Icons.school),
                  ),
                  onChanged: (v) => _year = v,
                  validator: (v) => v == null || v.isEmpty ? 'Enter year' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'Section',
                    prefixIcon: Icon(Icons.class_rounded),
                  ),
                  onChanged: (v) => _section = v,
                  validator: (v) => v == null || v.isEmpty ? 'Enter section' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'Department',
                    prefixIcon: Icon(Icons.apartment),
                  ),
                  onChanged: (v) => _department = v,
                  validator: (v) => v == null || v.isEmpty ? 'Enter department' : null,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<Domain>(
                  value: _selectedDomain,
                  decoration: const InputDecoration(
                    labelText: 'Domain',
                    prefixIcon: Icon(Icons.category),
                  ),
                  items: Domain.values
                      .map((d) => DropdownMenuItem(
                            value: d,
                            child: Text(d.label),
                          ))
                      .toList(),
                  onChanged: (val) => setState(() => _selectedDomain = val),
                  validator: (v) => v == null ? 'Select domain' : null,
                ),
                  const SizedBox(height: 24),
                  if (_error != null) ...[
                    Text(_error!, style: const TextStyle(color: Colors.red)),
                    const SizedBox(height: 16),
                  ],
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : () {
                        if (_formKey.currentState?.validate() ?? false) _register();
                      },
                      child: _isLoading 
                        ? const CircularProgressIndicator() 
                        : const Text('Add Member'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
