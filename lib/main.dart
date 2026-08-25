import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pdfrx/pdfrx.dart';

import 'features/auth/login_screen.dart';
import 'features/classes/classes_screen.dart';
import 'features/gradebook/gradebook_screen.dart';
import 'features/workspace/workspace_pages.dart';
import 'core/design_system.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  pdfrxFlutterInitialize();
  const url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://buwqtthzzrgbmpieakay.supabase.co',
  );
  const key = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: 'sb_publishable_3rjcoooXdoEBpN_ingWzfA_R9j-Od2T',
  );

  await Supabase.initialize(url: url, anonKey: key);
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
      GoRoute(path: '/gradebooks', builder: (_, __) => const GradebooksScreen()),
      GoRoute(path: '/students', builder: (_, __) => const StudentsScreen()),
      GoRoute(path: '/imports', builder: (_, __) => const ImportsScreen()),
      GoRoute(path: '/reports', builder: (_, __) => const ReportsScreen()),
      GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
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
      theme: smartGradeTheme(),
      routerConfig: ref.watch(routerProvider),
    );
  }
}
