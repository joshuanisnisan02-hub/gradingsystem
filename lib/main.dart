import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pdfrx/pdfrx.dart';

import 'features/auth/login_screen.dart';
import 'features/auth/change_password_screen.dart';
import 'features/admin/user_management_screen.dart';
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
  // The hosted teacher workspace requires a fresh login whenever the web app
  // is opened or refreshed. Local scope clears only this browser session and
  // does not revoke sessions on the teacher's other devices.
  if (kIsWeb) {
    await Supabase.instance.client.auth.signOut(scope: SignOutScope.local);
  }
  runApp(const ProviderScope(child: SmartGradeApp()));
}

class AuthRouterRefresh extends ChangeNotifier {
  AuthRouterRefresh() {
    _subscription = Supabase.instance.client.auth.onAuthStateChange.listen(
      (_) => notifyListeners(),
      onError: (_, __) => notifyListeners(),
    );
  }

  late final StreamSubscription<AuthState> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final authRefresh = AuthRouterRefresh();
  ref.onDispose(authRefresh.dispose);
  return GoRouter(
    initialLocation: '/login',
    refreshListenable: authRefresh,
    redirect: (context, state) async {
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;
      final location = state.matchedLocation;
      if (user == null && location != '/login') return '/login';
      if (user == null) return null;

      final profile = await client
          .from('profiles')
          .select('role, must_change_password, is_active')
          .eq('id', user.id)
          .maybeSingle();
      if (profile == null || profile['is_active'] == false) {
        await client.auth.signOut();
        return '/login';
      }
      final mustChange = profile['must_change_password'] == true;
      if (mustChange && location != '/change-password') {
        return '/change-password';
      }
      if (!mustChange && location == '/change-password') return '/classes';
      if (location == '/admin/users' && profile['role'] != 'administrator') {
        return '/classes';
      }
      if (location == '/login') return '/classes';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(
        path: '/change-password',
        builder: (_, __) => const ChangePasswordScreen(),
      ),
      GoRoute(
        path: '/admin/users',
        builder: (_, __) => const UserManagementScreen(),
      ),
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
