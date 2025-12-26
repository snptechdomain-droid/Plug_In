import 'package:flutter/material.dart';
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
  bool _isLoading = false;
  String? _error;

  String _registerNumber = '';
  String _year = 'I';
  String _section = '';
  String _department = 'CSE';
  String _domain = 'management'; // Default

  final _auth = RoleBasedDatabaseService();

  Future<void> _register() async {
    if (_username.isEmpty || _password.isEmpty || _key.isEmpty) {
      setState(() { _error = 'Please fill all required fields'; });
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
      domain: _domain,
    );

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Member added successfully! Domain rules applied.')),
      );
      Navigator.of(context).pop(); 
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
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      decoration: const InputDecoration(labelText: 'Security Key', prefixIcon: Icon(Icons.vpn_key)),
                      obscureText: true,
                      onChanged: (v) => _key = v,
                      validator: (v) => v!.isEmpty ? 'Enter key' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      decoration: const InputDecoration(labelText: 'Username', prefixIcon: Icon(Icons.person)),
                      onChanged: (v) => _username = v,
                      validator: (v) => v!.isEmpty ? 'Enter username' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      decoration: const InputDecoration(labelText: 'Password', prefixIcon: Icon(Icons.lock)),
                      obscureText: true,
                      onChanged: (v) => _password = v,
                      validator: (v) => v!.isEmpty ? 'Enter password' : null,
                    ),
                    const Divider(height: 32),
                    
                    // Student Details
                    TextFormField(
                      decoration: const InputDecoration(labelText: 'Register Number', prefixIcon: Icon(Icons.numbers)),
                      onChanged: (v) => _registerNumber = v,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _department,
                            decoration: const InputDecoration(labelText: 'Dept', prefixIcon: Icon(Icons.school)),
                            items: ['CSE', 'IT', 'ECE', 'EEE', 'MECH', 'CIVIL', 'AIDS', 'AIML']
                                .map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                            onChanged: (v) => setState(() => _department = v!),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _year,
                            decoration: const InputDecoration(labelText: 'Year'),
                            items: ['I', 'II', 'III', 'IV']
                                .map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                            onChanged: (v) => setState(() => _year = v!),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      decoration: const InputDecoration(labelText: 'Section (e.g. A)', prefixIcon: Icon(Icons.class_)),
                      onChanged: (v) => _section = v,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _domain,
                      decoration: const InputDecoration(labelText: 'Domain', prefixIcon: Icon(Icons.work)),
                      items: ['management', 'tech', 'webdev', 'content', 'design', 'marketing']
                          .map((e) => DropdownMenuItem(value: e, child: Text(e.toUpperCase()))).toList(),
                      onChanged: (v) => setState(() => _domain = v!),
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
      ),
    );
  }
}
