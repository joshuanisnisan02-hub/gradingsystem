import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/design_system.dart';
import '../../core/supabase_client.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final email = TextEditingController();
  final password = TextEditingController();
  bool loading = false;
  bool hidePassword = true;
  String? error;

  Future<void> login() async {
    setState(() { loading = true; error = null; });
    try {
      await supabase.auth.signInWithPassword(email: email.text.trim(), password: password.text);
      if (mounted) context.go('/classes');
    } on AuthException catch (e) {
      setState(() => error = e.message);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: SmartGradeColors.black,
    body: Row(children: [
      if (MediaQuery.sizeOf(context).width >= 850)
        Expanded(child: Container(
          padding: const EdgeInsets.all(58),
          decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [SmartGradeColors.redDark, SmartGradeColors.red, Color(0xFF5E1217)])),
          child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _Brand(light: true),
            Spacer(),
            SizedBox(width: 54, child: Divider(color: SmartGradeColors.mustard, thickness: 6)),
            SizedBox(height: 20),
            Text('A clearer gradebook.\nA calmer workday.', style: TextStyle(color: Colors.white, fontSize: 43, height: 1.08, fontWeight: FontWeight.w800)),
            SizedBox(height: 18),
            SizedBox(width: 520, child: Text('Manage classes, enter scores, and keep every calculation transparent in one focused teacher workspace.', style: TextStyle(color: Colors.white70, height: 1.6, fontSize: 15))),
            Spacer(),
            Row(children: [Icon(Icons.verified_user_outlined, color: SmartGradeColors.mustard, size: 18), SizedBox(width: 9), Text('Securely powered by Supabase', style: TextStyle(color: Colors.white70, fontSize: 12))]),
          ]),
        )),
      Expanded(child: Container(
        color: SmartGradeColors.canvas,
        alignment: Alignment.center,
        child: SingleChildScrollView(padding: const EdgeInsets.all(26), child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (MediaQuery.sizeOf(context).width < 850) ...[const _Brand(light: false), const SizedBox(height: 38)],
            const Text('WELCOME BACK', style: TextStyle(color: SmartGradeColors.red, fontSize: 10, letterSpacing: 1.7, fontWeight: FontWeight.w800)),
            const SizedBox(height: 9),
            const Text('Sign in to your workspace', style: TextStyle(fontSize: 28, height: 1.15, fontWeight: FontWeight.w800, color: SmartGradeColors.ink)),
            const SizedBox(height: 8),
            const Text('Use the teacher account created in Supabase Auth.', style: TextStyle(color: SmartGradeColors.muted)),
            const SizedBox(height: 30),
            const Text('EMAIL ADDRESS', style: _fieldLabel),
            const SizedBox(height: 7),
            TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(hintText: 'teacher@school.edu', prefixIcon: Icon(Icons.mail_outline_rounded))),
            const SizedBox(height: 17),
            const Text('PASSWORD', style: _fieldLabel),
            const SizedBox(height: 7),
            TextField(controller: password, obscureText: hidePassword, onSubmitted: (_) => login(), decoration: InputDecoration(hintText: 'Enter your password', prefixIcon: const Icon(Icons.lock_outline_rounded), suffixIcon: IconButton(onPressed: () => setState(() => hidePassword = !hidePassword), icon: Icon(hidePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined)))),
            if (error != null) Container(margin: const EdgeInsets.only(top: 14), padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFFFFE9E9), borderRadius: BorderRadius.circular(7)), child: Text(error!, style: const TextStyle(color: SmartGradeColors.red, fontSize: 12))),
            const SizedBox(height: 20),
            FilledButton(onPressed: loading ? null : login, child: Padding(padding: const EdgeInsets.symmetric(vertical: 14), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [if (loading) ...[const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)), const SizedBox(width: 10)], Text(loading ? 'Signing in…' : 'Sign in to SmartGrade')]))),
            const SizedBox(height: 18),
            const Text('Need an account? Ask your administrator to create a user in Supabase Authentication.', textAlign: TextAlign.center, style: TextStyle(color: SmartGradeColors.muted, fontSize: 11, height: 1.45)),
          ]),
        )),
      )),
    ]),
  );

  static const _fieldLabel = TextStyle(fontSize: 10, letterSpacing: 1.1, fontWeight: FontWeight.w800, color: SmartGradeColors.ink);
}

class _Brand extends StatelessWidget {
  const _Brand({required this.light});
  final bool light;
  @override
  Widget build(BuildContext context) => Row(children: [
    Container(width: 42, height: 42, decoration: BoxDecoration(color: SmartGradeColors.mustard, borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.school_rounded, color: SmartGradeColors.black)),
    const SizedBox(width: 12),
    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('SMARTGRADE', style: TextStyle(color: light ? Colors.white : SmartGradeColors.black, fontWeight: FontWeight.w800, letterSpacing: 1.2, fontSize: 17)),
      Text('CLASS RECORD SYSTEM', style: TextStyle(color: light ? Colors.white60 : SmartGradeColors.muted, letterSpacing: 1.4, fontSize: 8)),
    ]),
  ]);
}
