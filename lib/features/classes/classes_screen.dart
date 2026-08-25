import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/supabase_client.dart';

class ClassesScreen extends StatefulWidget {
  const ClassesScreen({super.key});
  @override
  State<ClassesScreen> createState() => _ClassesScreenState();
}

class _ClassesScreenState extends State<ClassesScreen> {
  late Future<List<Map<String, dynamic>>> classes;
  @override
  void initState() { super.initState(); classes = load(); }
  Future<List<Map<String, dynamic>>> load() async => List<Map<String, dynamic>>.from(await supabase.from('classes').select().eq('status', 'active').order('subject_code'));

  Future<void> createClass() async {
    final code = TextEditingController(), title = TextEditingController(), section = TextEditingController();
    final ok = await showDialog<bool>(context: context, builder: (context) => AlertDialog(title: const Text('Create class'), content: SizedBox(width: 420, child: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: code, decoration: const InputDecoration(labelText: 'Subject code')), const SizedBox(height: 10), TextField(controller: title, decoration: const InputDecoration(labelText: 'Subject title')), const SizedBox(height: 10), TextField(controller: section, decoration: const InputDecoration(labelText: 'Section'))])), actions: [TextButton(onPressed: ()=>Navigator.pop(context,false), child: const Text('Cancel')), FilledButton(onPressed: ()=>Navigator.pop(context,true), child: const Text('Create'))]));
    if (ok == true) {
      await supabase.from('classes').insert({'teacher_id': supabase.auth.currentUser!.id, 'subject_code': code.text.trim(), 'subject_title': title.text.trim(), 'section': section.text.trim()});
      setState(() => classes = load());
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('SmartGrade'), actions: [IconButton(tooltip: 'Sign out', onPressed: () async { await supabase.auth.signOut(); if(context.mounted) context.go('/login'); }, icon: const Icon(Icons.logout))]),
    floatingActionButton: FloatingActionButton.extended(onPressed: createClass, icon: const Icon(Icons.add), label: const Text('New class')),
    body: FutureBuilder<List<Map<String,dynamic>>>(future: classes, builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
      if (snapshot.hasError) return Center(child: Text('Classes could not be loaded. ${snapshot.error}'));
      final data = snapshot.data ?? [];
      if (data.isEmpty) return const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.class_outlined,size:56),SizedBox(height:12),Text('No classes yet'),Text('Create your first class to begin.') ]));
      return LayoutBuilder(builder: (context, box) { final count = box.maxWidth > 1100 ? 4 : box.maxWidth > 700 ? 2 : 1; return GridView.builder(padding: const EdgeInsets.all(24), gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: count, childAspectRatio: 1.7, crossAxisSpacing: 16, mainAxisSpacing: 16), itemCount: data.length, itemBuilder: (_, i) { final c=data[i]; return Card(clipBehavior: Clip.antiAlias, child: InkWell(onTap: ()=>context.go('/classes/${c['id']}/gradebook'), child: Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(c['subject_code']??'',style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),Text(c['subject_title']??''),const Spacer(),Text(c['section']??'No section'),const SizedBox(height:8),const Row(children:[Icon(Icons.arrow_forward,size:16),SizedBox(width:5),Text('Open gradebook')])])))); }); });
    }),
  );
}
