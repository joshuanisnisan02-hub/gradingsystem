import 'package:flutter/material.dart';
import '../../core/design_system.dart';
import '../../core/supabase_client.dart';
import '../../core/workspace_shell.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  bool loading = true;
  String? error;
  List<Map<String, dynamic>> users = [];

  Future<Map<String, dynamic>> call(Map<String, dynamic> body) async {
    final response = await supabase.functions.invoke('user-management', body: body);
    final data = Map<String, dynamic>.from(response.data as Map);
    if (data['error'] != null) throw Exception(data['error']);
    return data;
  }

  Future<void> load() async {
    setState(() { loading = true; error = null; });
    try {
      final data = await call({'action': 'list'});
      users = List<Map<String, dynamic>>.from((data['users'] as List).map((value) => Map<String, dynamic>.from(value as Map)));
    } catch (e) {
      error = e.toString().replaceFirst('Exception: ', '');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  void initState() { super.initState(); load(); }

  Future<void> createUser() async {
    final result = await showDialog<Map<String, String>>(context: context, builder: (_) => const _CreateUserDialog());
    if (result == null) return;
    try {
      await call({'action': 'create', ...result});
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User created. Give the temporary password to the user securely.')));
      await load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
    }
  }

  @override
  Widget build(BuildContext context) => WorkspaceShell(
    title: 'User Management', active: 'Users',
    actions: [FilledButton.icon(onPressed: createUser, icon: const Icon(Icons.person_add_alt_1_rounded, size: 18), label: const Text('Create user'))],
    child: Container(color: SmartGradeColors.canvas, padding: const EdgeInsets.all(24), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('ADMINISTRATION', style: TextStyle(color: SmartGradeColors.red, fontSize: 10, letterSpacing: 1.5, fontWeight: FontWeight.w800)),
      const SizedBox(height: 8),
      const Text('Users and roles', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: SmartGradeColors.ink)),
      const SizedBox(height: 7),
      const Text('Create accounts with temporary passwords. New users must set their own password before opening the workspace.', style: TextStyle(color: SmartGradeColors.muted)),
      const SizedBox(height: 22),
      Expanded(child: Card(child: loading ? const Center(child: CircularProgressIndicator()) : error != null ? Center(child: Text(error!, style: const TextStyle(color: SmartGradeColors.red))) : SingleChildScrollView(child: DataTable(
        columns: const [DataColumn(label: Text('NAME')), DataColumn(label: Text('EMAIL')), DataColumn(label: Text('ROLE')), DataColumn(label: Text('PASSWORD STATUS'))],
        rows: users.map((user) => DataRow(cells: [
          DataCell(Text(user['full_name']?.toString() ?? '')),
          DataCell(Text(user['email']?.toString() ?? '')),
          DataCell(Text(_roleLabel(user['role']?.toString()))),
          DataCell(Chip(label: Text(user['must_change_password'] == true ? 'Change required' : 'Password set'), backgroundColor: user['must_change_password'] == true ? const Color(0xFFFFE7BE) : const Color(0xFFE4F2E8))),
        ])).toList(),
      )))),
    ])),
  );
}

String _roleLabel(String? role) => switch (role) { 'administrator' => 'Administrator', 'encoder' => 'Encoder', _ => 'Teacher' };

class _CreateUserDialog extends StatefulWidget {
  const _CreateUserDialog();
  @override
  State<_CreateUserDialog> createState() => _CreateUserDialogState();
}

class _CreateUserDialogState extends State<_CreateUserDialog> {
  final name = TextEditingController();
  final email = TextEditingController();
  final password = TextEditingController();
  String role = 'teacher';
  String? error;

  void submit() {
    if (name.text.trim().isEmpty || !email.text.contains('@') || password.text.length < 8) {
      setState(() => error = 'Enter a name, valid email, and temporary password of at least 8 characters.');
      return;
    }
    Navigator.pop(context, {'fullName': name.text.trim(), 'email': email.text.trim(), 'password': password.text, 'role': role});
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Create user'),
    content: SizedBox(width: 430, child: Column(mainAxisSize: MainAxisSize.min, children: [
      TextField(controller: name, decoration: const InputDecoration(labelText: 'Full name')),
      const SizedBox(height: 12),
      TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email address')),
      const SizedBox(height: 12),
      TextField(controller: password, obscureText: true, decoration: const InputDecoration(labelText: 'Temporary password')),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(initialValue: role, decoration: const InputDecoration(labelText: 'Role'), items: const [
        DropdownMenuItem(value: 'administrator', child: Text('Administrator — manage users and all workspace tools')),
        DropdownMenuItem(value: 'teacher', child: Text('Teacher — manage own classes and gradebooks')),
        DropdownMenuItem(value: 'encoder', child: Text('Encoder — encode class records')),
      ], onChanged: (value) => setState(() => role = value ?? 'teacher')),
      if (error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(error!, style: const TextStyle(color: SmartGradeColors.red))),
    ])),
    actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')), FilledButton(onPressed: submit, child: const Text('Create user'))],
  );
}
