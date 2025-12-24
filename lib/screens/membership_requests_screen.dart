import 'package:flutter/material.dart';
import 'package:app/services/role_database_service.dart';
import 'package:intl/intl.dart';

class MembershipRequestsScreen extends StatefulWidget {
  const MembershipRequestsScreen({super.key});

  @override
  State<MembershipRequestsScreen> createState() => _MembershipRequestsScreenState();
}

class _MembershipRequestsScreenState extends State<MembershipRequestsScreen> {
  final RoleBasedDatabaseService _databaseService = RoleBasedDatabaseService();
  List<dynamic> _requests = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    setState(() => _isLoading = true);
    final data = await _databaseService.fetchMembershipRequests();
    if (mounted) {
      setState(() {
        _requests = data;
        _isLoading = false;
      });
    }
  }

  Future<void> _updateStatus(String id, String status) async {
    await _databaseService.updateMembershipRequestStatus(id, status);
    _loadRequests();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text('Membership Requests', 
          style: TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold)
        ),
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _requests.isEmpty
              ? Center(child: Text('No pending requests.', style: TextStyle(color: isDark ? Colors.white : Colors.black)))
              : ListView.builder(
                  padding: const EdgeInsets.all(16.0),
                  itemCount: _requests.length,
                  itemBuilder: (context, index) {
                    final req = _requests[index];
                    final status = req['status'] ?? 'PENDING';
                    
                    Color statusColor = Colors.orange;
                    if (status == 'APPROVED') statusColor = Colors.green;
                    if (status == 'REJECTED') statusColor = Colors.red;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                      elevation: 4,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header: Name and Status
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    req['name'] ?? 'Unknown',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? Colors.white : Colors.black,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: statusColor.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: statusColor.withOpacity(0.5)),
                                  ),
                                  child: Text(
                                    status,
                                    style: TextStyle(
                                      color: statusColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            
                            // Body: Information
                            _InfoRow(icon: Icons.email, text: req['email'] ?? '', isDark: isDark),
                            _InfoRow(
                              icon: Icons.school, 
                              text: '${req['registerNumber'] ?? 'N/A'} | ${req['department'] ?? ''} ${req['year'] ?? ''} ${req['section'] ?? ''}', 
                              isDark: isDark
                            ),
                            _InfoRow(icon: Icons.phone, text: req['mobileNumber']?.toString() ?? 'N/A', isDark: isDark),
                            const SizedBox(height: 8),
                            Text(
                              'Reason:',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white70 : Colors.black87,
                              ),
                            ),
                            Text(
                              req['reason'] ?? 'No reason provided.',
                              style: TextStyle(
                                fontStyle: FontStyle.italic,
                                color: isDark ? Colors.grey[400] : Colors.grey[700],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Requested: ${req['requestDate'] != null ? DateFormat.yMMMd().format(DateTime.parse(req['requestDate'])) : 'N/A'}',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? Colors.grey[600] : Colors.grey[500],
                              ),
                            ),
                            
                            // Footer: Actions
                            if (status == 'PENDING') ...[
                              const Divider(height: 24),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  OutlinedButton.icon(
                                    onPressed: () => _updateStatus(req['id'], 'REJECTED'),
                                    icon: const Icon(Icons.close, color: Colors.red),
                                    label: const Text('Reject', style: TextStyle(color: Colors.red)),
                                    style: OutlinedButton.styleFrom(
                                      side: const BorderSide(color: Colors.red),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  ElevatedButton.icon(
                                    onPressed: () => _updateStatus(req['id'], 'APPROVED'),
                                    icon: const Icon(Icons.check, color: Colors.white),
                                    label: const Text('Approve', style: TextStyle(color: Colors.white)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green,
                                      foregroundColor: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool isDark;

  const _InfoRow({required this.icon, required this.text, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: isDark ? Colors.grey[400] : Colors.grey[600]),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: isDark ? Colors.grey[300] : Colors.black87,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
