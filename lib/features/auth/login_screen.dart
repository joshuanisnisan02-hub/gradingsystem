import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/supabase_client.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final email = TextEditingController();
  final password = TextEditingController();
  bool loading = false;
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
    body: Center(child: SingleChildScrollView(padding: const EdgeInsets.all(24), child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Card(child: Padding(padding: const EdgeInsets.all(28), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Icon(Icons.school_rounded, size: 52, color: Color(0xFFF97316)),
        const SizedBox(height: 12),
        Text('SmartGrade', textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
        const Text('Teacher grading and class record system', textAlign: TextAlign.center),
        const SizedBox(height: 28),
        TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email address', prefixIcon: Icon(Icons.email_outlined))),
        const SizedBox(height: 14),
        TextField(controller: password, obscureText: true, onSubmitted: (_) => login(), decoration: const InputDecoration(labelText: 'Password', prefixIcon: Icon(Icons.lock_outline))),
        if (error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(error!, style: const TextStyle(color: Colors.red))),
        const SizedBox(height: 18),
        FilledButton(onPressed: loading ? null : login, child: Padding(padding: const EdgeInsets.all(13), child: Text(loading ? 'Signing in…' : 'Sign in'))),
      ]))),
    ))),
  );
}
