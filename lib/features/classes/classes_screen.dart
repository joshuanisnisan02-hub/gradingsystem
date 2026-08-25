import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/design_system.dart';
import '../../core/supabase_client.dart';
import '../../core/workspace_shell.dart';

class ClassesScreen extends StatefulWidget {
  const ClassesScreen({super.key});

  @override
  State<ClassesScreen> createState() => _ClassesScreenState();
}

class _ClassesScreenState extends State<ClassesScreen> {
  bool loading = true;
  String query = '';
  List<Map<String, dynamic>> classes = [];

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final data = await supabase.from('classes').select().order('created_at');
      if (mounted) setState(() { classes = List<Map<String, dynamic>>.from(data); loading = false; });
    } catch (error) {
      if (!mounted) return;
      setState(() => loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Classes could not be loaded: $error')));
    }
  }

  Future<void> createClass() async {
    final code = TextEditingController();
    final title = TextEditingController();
    final section = TextEditingController();
    final accepted = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
      title: const Text('Create a class'),
      content: SizedBox(width: 420, child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: code, autofocus: true, decoration: const InputDecoration(labelText: 'Subject code', hintText: 'IT 101')),
        const SizedBox(height: 14),
        TextField(controller: title, decoration: const InputDecoration(labelText: 'Subject title')),
        const SizedBox(height: 14),
        TextField(controller: section, decoration: const InputDecoration(labelText: 'Section')),
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Create class')),
      ],
    ));
    if (accepted != true || code.text.trim().isEmpty || title.text.trim().isEmpty || section.text.trim().isEmpty) return;
    try {
      await supabase.from('classes').insert({'subject_code': code.text.trim(), 'subject_title': title.text.trim(), 'section': section.text.trim(), 'teacher_id': supabase.auth.currentUser!.id});
      await load();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Class could not be created: $error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = classes.where((row) {
      final text = '${row['subject_code'] ?? ''} ${row['subject_title'] ?? ''} ${row['section'] ?? ''}'.toLowerCase();
      return text.contains(query.toLowerCase());
    }).toList();
    return WorkspaceShell(
      title: 'My Classes',
      active: 'Classes',
      actions: [IconButton(tooltip: 'Notifications', onPressed: () {}, icon: const Icon(Icons.notifications_none_rounded))],
      child: loading ? const Center(child: CircularProgressIndicator()) : SingleChildScrollView(
        padding: const EdgeInsets.all(26),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Wrap(alignment: WrapAlignment.spaceBetween, runSpacing: 18, spacing: 20, children: [
            const SizedBox(width: 560, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('YOUR TEACHING LOAD', style: TextStyle(fontSize: 10, letterSpacing: 1.5, color: SmartGradeColors.red, fontWeight: FontWeight.w800)),
              SizedBox(height: 7),
              Text('Classes at a glance', style: TextStyle(fontSize: 29, height: 1.1, fontWeight: FontWeight.w800, color: SmartGradeColors.ink)),
              SizedBox(height: 7),
              Text('Open a class to review scores, track missing work, and calculate final grades.', style: TextStyle(color: SmartGradeColors.muted)),
            ])),
            FilledButton.icon(onPressed: createClass, icon: const Icon(Icons.add_rounded), label: const Text('New class')),
          ]),
          const SizedBox(height: 24),
          Wrap(spacing: 12, runSpacing: 12, children: [
            _Metric(label: 'ACTIVE CLASSES', value: '${classes.length}', icon: Icons.school_outlined, color: SmartGradeColors.red),
            const _Metric(label: 'CURRENT TERM', value: 'Prelim', icon: Icons.calendar_month_outlined, color: SmartGradeColors.mustard),
            const _Metric(label: 'SYNC ATTENTION', value: '2', icon: Icons.sync_problem_outlined, color: SmartGradeColors.black),
          ]),
          const SizedBox(height: 22),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white, border: Border.all(color: SmartGradeColors.line), borderRadius: BorderRadius.circular(10)),
            child: Row(children: [
              Expanded(child: TextField(onChanged: (value) => setState(() => query = value), decoration: const InputDecoration(prefixIcon: Icon(Icons.search_rounded), hintText: 'Search classes or sections', filled: false, border: InputBorder.none))),
              const SizedBox(width: 12),
              OutlinedButton.icon(onPressed: () {}, icon: const Icon(Icons.filter_list_rounded), label: const Text('Filter')),
              const SizedBox(width: 8),
              OutlinedButton.icon(onPressed: () {}, icon: const Icon(Icons.file_upload_outlined), label: const Text('Import')),
            ]),
          ),
          const SizedBox(height: 18),
          if (filtered.isEmpty)
            _EmptyState(onCreate: createClass)
          else
            LayoutBuilder(builder: (context, box) {
              final count = box.maxWidth >= 1100 ? 3 : box.maxWidth >= 650 ? 2 : 1;
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filtered.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: count, mainAxisExtent: 220, crossAxisSpacing: 14, mainAxisSpacing: 14),
                itemBuilder: (_, index) => _ClassCard(data: filtered[index]),
              );
            }),
        ]),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value, required this.icon, required this.color});
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(width: 220, padding: const EdgeInsets.all(17), decoration: BoxDecoration(color: Colors.white, border: Border.all(color: SmartGradeColors.line), borderRadius: BorderRadius.circular(9)), child: Row(children: [
    Container(width: 42, height: 42, decoration: BoxDecoration(color: color.withValues(alpha: .12), borderRadius: BorderRadius.circular(8)), child: Icon(icon, color: color, size: 21)),
    const SizedBox(width: 13),
    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)), Text(label, style: const TextStyle(fontSize: 9, letterSpacing: .8, color: SmartGradeColors.muted, fontWeight: FontWeight.w700))]),
  ]));
}

class _ClassCard extends StatelessWidget {
  const _ClassCard({required this.data});
  final Map<String, dynamic> data;
  @override
  Widget build(BuildContext context) => InkWell(
    borderRadius: BorderRadius.circular(10),
    onTap: () => context.go('/classes/${data['id']}/gradebook'),
    child: Container(
      decoration: BoxDecoration(color: Colors.white, border: Border.all(color: SmartGradeColors.line), borderRadius: BorderRadius.circular(10), boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 14, offset: Offset(0, 5))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(height: 9, decoration: const BoxDecoration(color: SmartGradeColors.red, borderRadius: BorderRadius.vertical(top: Radius.circular(9)))),
        Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(width: 38, height: 38, decoration: BoxDecoration(color: SmartGradeColors.mustardSoft, borderRadius: BorderRadius.circular(7)), child: const Icon(Icons.menu_book_rounded, size: 20, color: SmartGradeColors.black)),
            const Spacer(),
            const Icon(Icons.more_horiz_rounded, color: SmartGradeColors.muted),
          ]),
          const SizedBox(height: 15),
          Text('${data['subject_code'] ?? 'CLASS'} · ${data['section'] ?? ''}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text('${data['subject_title'] ?? 'Untitled subject'}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: SmartGradeColors.muted)),
          const SizedBox(height: 18),
          const Divider(height: 1),
          const SizedBox(height: 12),
          const Row(children: [Icon(Icons.people_outline, size: 16, color: SmartGradeColors.muted), SizedBox(width: 6), Text('Open roster & gradebook', style: TextStyle(fontSize: 11, color: SmartGradeColors.muted)), Spacer(), Icon(Icons.arrow_forward_rounded, size: 17, color: SmartGradeColors.red)]),
        ])),
      ]),
    ),
  );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onCreate});
  final VoidCallback onCreate;
  @override
  Widget build(BuildContext context) => Container(width: double.infinity, padding: const EdgeInsets.all(44), decoration: BoxDecoration(color: Colors.white, border: Border.all(color: SmartGradeColors.line), borderRadius: BorderRadius.circular(10)), child: Column(children: [
    const Icon(Icons.school_outlined, size: 44, color: SmartGradeColors.red),
    const SizedBox(height: 13),
    const Text('No classes found', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
    const SizedBox(height: 5),
    const Text('Create your first class or adjust the search.', style: TextStyle(color: SmartGradeColors.muted)),
    const SizedBox(height: 18),
    FilledButton.icon(onPressed: onCreate, icon: const Icon(Icons.add), label: const Text('Create class')),
  ]));
}
