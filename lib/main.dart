import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'features/auth/login_screen.dart';
import 'features/classes/classes_screen.dart';
import 'features/gradebook/gradebook_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const url = String.fromEnvironment('SUPABASE_URL');
  const key = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
  if (url.isNotEmpty && key.isNotEmpty) {
    await Supabase.initialize(url: url, anonKey: key);
  }
  runApp(const ProviderScope(child: SmartGradeApp()));
}

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/login',
    redirect: (context, state) {
      final signedIn = Supabase.instance.client.auth.currentSession != null;
      if (!signedIn && state.matchedLocation != '/login') return '/login';
      if (signedIn && state.matchedLocation == '/login') return '/classes';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/classes', builder: (_, __) => const ClassesScreen()),
      GoRoute(
        path: '/classes/:classId/gradebook',
        builder: (_, state) => GradebookScreen(classId: state.pathParameters['classId']!),
      ),
    ],
  );
});

class SmartGradeApp extends ConsumerWidget {
  const SmartGradeApp({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'SmartGrade',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF14213D), primary: const Color(0xFF14213D), secondary: const Color(0xFFF97316)),
        scaffoldBackgroundColor: const Color(0xFFF5F7FA),
        useMaterial3: true,
        inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder()),
      ),
      routerConfig: ref.watch(routerProvider),
    );
  }
}
