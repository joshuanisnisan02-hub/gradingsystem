import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/design_system.dart';
import '../../core/supabase_client.dart';
import '../../core/workspace_shell.dart';

class GradebooksScreen extends StatelessWidget {
  const GradebooksScreen({super.key});
  @override
  Widget build(BuildContext context) => WorkspaceShell(
    title: 'Gradebooks',
    active: 'Gradebooks',
    child: FutureBuilder<List<Map<String, dynamic>>>(
      future: _loadClasses(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
        final classes = snapshot.data ?? [];
        return _PageBody(
          eyebrow: 'CLASS RECORDS',
          title: 'Choose a class gradebook',
          description: 'Each gradebook only shows the students and assessment records belonging to that class.',
          child: classes.isEmpty
              ? _EmptyPanel(icon: Icons.table_chart_outlined, title: 'No gradebooks available', message: 'Create a class first. Its gradebook will automatically appear here.', actionLabel: 'Create a class', onAction: () => context.go('/classes'))
              : Wrap(spacing: 14, runSpacing: 14, children: classes.map((item) => _ActionCard(
                  icon: Icons.menu_book_rounded,
                  title: '${item['subject_code']} · ${item['section']}',
                  subtitle: '${item['subject_title']}',
                  action: 'Open gradebook',
                  onTap: () => context.go('/classes/${item['id']}/gradebook'),
                )).toList()),
        );
      },
    ),
  );

  Future<List<Map<String, dynamic>>> _loadClasses() async {
    final data = await supabase.from('classes').select('id, subject_code, subject_title, section').order('subject_code');
    return List<Map<String, dynamic>>.from(data);
  }
}

class StudentsScreen extends StatelessWidget {
  const StudentsScreen({super.key});
  @override
  Widget build(BuildContext context) => WorkspaceShell(
    title: 'Students',
    active: 'Students',
    child: FutureBuilder<List<Map<String, dynamic>>>(
      future: _loadStudents(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
        final students = snapshot.data ?? [];
        return _PageBody(
          eyebrow: 'STUDENT DIRECTORY',
          title: 'Students in your classes',
          description: 'This directory follows your Supabase access policies and only displays students enrolled in your classes.',
          child: students.isEmpty
              ? _EmptyPanel(icon: Icons.people_outline, title: 'No students found', message: 'Import or enroll students into a class to see them here.', actionLabel: 'Go to imports', onAction: () => context.go('/imports'))
              : Container(decoration: _panelDecoration, child: ListView.separated(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: students.length, separatorBuilder: (_, __) => const Divider(height: 1), itemBuilder: (_, index) { final student = students[index]; return ListTile(leading: const CircleAvatar(backgroundColor: SmartGradeColors.mustardSoft, child: Icon(Icons.person_outline, color: SmartGradeColors.black)), title: Text('${student['last_name']}, ${student['first_name']}', style: const TextStyle(fontWeight: FontWeight.w700)), subtitle: Text('${student['student_number']}'), trailing: const Icon(Icons.chevron_right_rounded)); })),
        );
      },
    ),
  );

  Future<List<Map<String, dynamic>>> _loadStudents() async {
    final data = await supabase.from('students').select('id, student_number, last_name, first_name').order('last_name');
    return List<Map<String, dynamic>>.from(data);
  }
}

class ImportsScreen extends StatelessWidget {
  const ImportsScreen({super.key});
  @override
  Widget build(BuildContext context) => WorkspaceShell(title: 'Imports & Sync', active: 'Imports', child: _PageBody(
    eyebrow: 'FASTER DATA ENTRY',
    title: 'Import and synchronize records',
    description: 'Choose the source that matches the records you already maintain.',
    child: Wrap(spacing: 14, runSpacing: 14, children: [
      _ActionCard(icon: Icons.group_add_outlined, title: 'Student masterlist', subtitle: 'Prepare a CSV roster for a selected class.', action: 'Select a class', onTap: () => context.go('/classes')),
      _ActionCard(icon: Icons.quiz_outlined, title: 'Quiz scores', subtitle: 'Open a gradebook before importing assessment scores.', action: 'Open gradebooks', onTap: () => context.go('/gradebooks')),
      _ActionCard(icon: Icons.cloud_sync_outlined, title: 'Google Classroom', subtitle: 'Classroom synchronization will be configured here.', action: 'View status', onTap: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Google Classroom connection is the next integration module.')))),
    ]),
  ));
}

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});
  @override
  Widget build(BuildContext context) => WorkspaceShell(title: 'Reports', active: 'Reports', child: _PageBody(
    eyebrow: 'REPORTS & EXPORT',
    title: 'Prepare class records',
    description: 'Open a class before producing reports so every output remains class-specific.',
    child: Wrap(spacing: 14, runSpacing: 14, children: [
      _ActionCard(icon: Icons.summarize_outlined, title: 'Class grade sheet', subtitle: 'Review totals and computed grades per class.', action: 'Choose class', onTap: () => context.go('/gradebooks')),
      _ActionCard(icon: Icons.warning_amber_outlined, title: 'Missing scores', subtitle: 'Identify incomplete requirements before finalizing.', action: 'Review classes', onTap: () => context.go('/classes')),
      _ActionCard(icon: Icons.file_download_outlined, title: 'Export records', subtitle: 'Export controls appear inside the selected gradebook.', action: 'Open gradebooks', onTap: () => context.go('/gradebooks')),
    ]),
  ));
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});
  @override
  Widget build(BuildContext context) => WorkspaceShell(title: 'Settings', active: 'Settings', child: const _PageBody(
    eyebrow: 'WORKSPACE SETTINGS',
    title: 'SmartGrade preferences',
    description: 'Your account is connected to Supabase. More grading and integration preferences can be added here.',
    child: _EmptyPanel(icon: Icons.settings_outlined, title: 'Configuration ready', message: 'Use the navigation menu to continue managing your classes.', actionLabel: 'Back to classes'),
  ));
}

class _PageBody extends StatelessWidget {
  const _PageBody({required this.eyebrow, required this.title, required this.description, required this.child});
  final String eyebrow; final String title; final String description; final Widget child;
  @override Widget build(BuildContext context) => SingleChildScrollView(padding: const EdgeInsets.all(26), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(eyebrow, style: const TextStyle(fontSize: 10, color: SmartGradeColors.red, letterSpacing: 1.5, fontWeight: FontWeight.w800)), const SizedBox(height: 7), Text(title, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800)), const SizedBox(height: 7), Text(description, style: const TextStyle(color: SmartGradeColors.muted)), const SizedBox(height: 24), child]));
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({required this.icon, required this.title, required this.subtitle, required this.action, required this.onTap});
  final IconData icon; final String title; final String subtitle; final String action; final VoidCallback onTap;
  @override Widget build(BuildContext context) => SizedBox(width: 310, child: Material(color: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: const BorderSide(color: SmartGradeColors.line)), child: InkWell(borderRadius: BorderRadius.circular(10), onTap: onTap, child: Padding(padding: const EdgeInsets.all(19), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Container(width: 42, height: 42, decoration: BoxDecoration(color: SmartGradeColors.mustardSoft, borderRadius: BorderRadius.circular(8)), child: Icon(icon, color: SmartGradeColors.black)), const SizedBox(height: 16), Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)), const SizedBox(height: 5), Text(subtitle, style: const TextStyle(fontSize: 12, height: 1.45, color: SmartGradeColors.muted)), const SizedBox(height: 17), Row(children: [Text(action, style: const TextStyle(fontSize: 11, color: SmartGradeColors.red, fontWeight: FontWeight.w800)), const Spacer(), const Icon(Icons.arrow_forward_rounded, size: 17, color: SmartGradeColors.red)])])))));
}

class _EmptyPanel extends StatelessWidget {
  const _EmptyPanel({required this.icon, required this.title, required this.message, required this.actionLabel, this.onAction});
  final IconData icon; final String title; final String message; final String actionLabel; final VoidCallback? onAction;
  @override Widget build(BuildContext context) => Container(width: double.infinity, padding: const EdgeInsets.all(44), decoration: _panelDecoration, child: Column(children: [Icon(icon, size: 42, color: SmartGradeColors.red), const SizedBox(height: 13), Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)), const SizedBox(height: 6), Text(message, textAlign: TextAlign.center, style: const TextStyle(color: SmartGradeColors.muted)), const SizedBox(height: 18), FilledButton(onPressed: onAction ?? () => context.go('/classes'), child: Text(actionLabel))]));
}

final _panelDecoration = BoxDecoration(color: Colors.white, border: Border.all(color: SmartGradeColors.line), borderRadius: BorderRadius.circular(10));
