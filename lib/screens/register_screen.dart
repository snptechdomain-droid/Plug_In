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
  String _name = '';
  String _password = '';
  String _key = '';
  bool _isLoading = false;
  String? _error;

  String _registerNumber = '';
  String _year = 'I';
  String _section = '';
  String _department = 'CSE';

  List<String> _selectedDomains = []; // Multi-select list

  final _auth = RoleBasedDatabaseService();

  void _showDomainDialog() async {
    final domains = ['management', 'tech', 'webdev', 'content', 'design', 'marketing'];
    
    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Select Domains'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: domains.map((domain) {
                    final isSelected = _selectedDomains.contains(domain);
                    return CheckboxListTile(
                      title: Text(domain.toUpperCase()),
                      value: isSelected,
                      onChanged: (checked) {
                        setState(() {
                          if (checked == true) {
                            if (!_selectedDomains.contains(domain)) {
                              _selectedDomains.add(domain);
                            }
                          } else {
                            _selectedDomains.remove(domain);
                          }
                        });
                        // Update parent state as well to reflect in background immediately or after close
                        this.setState(() {}); 
                      },
                    );
                  }).toList(),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Done'),
                ),
              ],
            );
          }
        );
      },
    );
  }

  Future<void> _register() async {
    if (_username.isEmpty || _password.isEmpty || _key.isEmpty) {
      setState(() { _error = 'Please fill all required fields'; });
      return;
    }
    
    // User requested "allow selectinmg multiple domis... add option to only accept for selected domains"
    // The "accept for selected" is Admin side. Here we just let them request/add.

    setState(() { _isLoading = true; _error = null; });
    
    final (success, message) = await _auth.register(
      username: _username, // Email/User ID
      name: _name,         // Full Name
      password: _password,
      key: _key,
      registerNumber: _registerNumber,
      year: _year,
      section: _section,
      department: _department,
      domains: _selectedDomains, // Send list
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
                      decoration: const InputDecoration(labelText: 'Full Name', prefixIcon: Icon(Icons.badge)),
                      onChanged: (v) => _name = v,
                      validator: (v) => v!.isEmpty ? 'Enter name' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      decoration: const InputDecoration(labelText: 'Email / Username', prefixIcon: Icon(Icons.email)),
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
                    // Multi-Select Domain Field
                    InkWell(
                      onTap: _showDomainDialog,
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Domains', 
                          prefixIcon: Icon(Icons.work),
                          border: OutlineInputBorder(),
                        ),
                        child: Text(
                          _selectedDomains.isEmpty 
                              ? 'Select Domains' 
                              : _selectedDomains.map((e) => e.toUpperCase()).join(', '),
                          style: TextStyle(
                            color: _selectedDomains.isEmpty ? Colors.grey.shade600 : Theme.of(context).textTheme.bodyLarge?.color
                          ),
                        ),
                      ),
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
