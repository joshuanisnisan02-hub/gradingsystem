import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/design_system.dart';
import '../../core/supabase_client.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final password = TextEditingController();
  final confirmation = TextEditingController();
  bool loading = false;
  bool hidden = true;
  String? error;

  Future<void> save() async {
    final next = password.text;
    if (next.length < 8) {
      setState(() => error = 'Use at least 8 characters.');
      return;
    }
    if (next != confirmation.text) {
      setState(() => error = 'The passwords do not match.');
      return;
    }
    setState(() { loading = true; error = null; });
    try {
      final response = await supabase.functions.invoke(
        'user-management',
        body: {'action': 'changePassword', 'password': next},
      );
      final data = response.data;
      if (data is Map && data['error'] != null) throw Exception(data['error']);
      if (mounted) context.go('/classes');
    } catch (e) {
      if (mounted) setState(() => error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: SmartGradeColors.canvas,
    body: Center(child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Container(
        width: 460,
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: SmartGradeColors.line)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Icon(Icons.lock_reset_rounded, size: 44, color: SmartGradeColors.red),
          const SizedBox(height: 18),
          const Text('Create your new password', textAlign: TextAlign.center, style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800, color: SmartGradeColors.ink)),
          const SizedBox(height: 8),
          const Text('Your administrator issued a temporary password. Change it before entering SmartGrade.', textAlign: TextAlign.center, style: TextStyle(color: SmartGradeColors.muted, height: 1.5)),
          const SizedBox(height: 26),
          TextField(controller: password, obscureText: hidden, decoration: InputDecoration(labelText: 'New password', prefixIcon: const Icon(Icons.lock_outline), suffixIcon: IconButton(onPressed: () => setState(() => hidden = !hidden), icon: Icon(hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined)))),
          const SizedBox(height: 14),
          TextField(controller: confirmation, obscureText: hidden, onSubmitted: (_) => save(), decoration: const InputDecoration(labelText: 'Confirm new password', prefixIcon: Icon(Icons.verified_user_outlined))),
          if (error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(error!, style: const TextStyle(color: SmartGradeColors.red))),
          const SizedBox(height: 22),
          FilledButton(onPressed: loading ? null : save, child: Padding(padding: const EdgeInsets.symmetric(vertical: 14), child: Text(loading ? 'Updating…' : 'Change password and continue'))),
          const SizedBox(height: 10),
          TextButton(onPressed: loading ? null : () async { await supabase.auth.signOut(); if (context.mounted) context.go('/login'); }, child: const Text('Sign out')),
        ]),
      ),
    )),
  );
}
