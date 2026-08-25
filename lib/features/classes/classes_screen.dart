import 'dart:convert';

import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:uuid/uuid.dart';

import '../../core/design_system.dart';
import '../../core/supabase_client.dart';
import '../../core/workspace_shell.dart';
import 'instructor_load_parser.dart';

class ClassesScreen extends StatefulWidget {
  const ClassesScreen({super.key});

  @override
  State<ClassesScreen> createState() => _ClassesScreenState();
}

class _ClassesScreenState extends State<ClassesScreen> {
  bool loading = true;
  bool importingLoad = false;
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
    List<Map<String, dynamic>> importedStudents = [];
    String? selectedFile;
    String? importError;
    final accepted = await showDialog<bool>(context: context, builder: (context) => StatefulBuilder(builder: (context, setDialogState) => AlertDialog(
      title: const Text('Create a class'),
      content: SingleChildScrollView(child: SizedBox(width: 420, child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: code, autofocus: true, decoration: const InputDecoration(labelText: 'Subject code', hintText: 'IT 101')),
        const SizedBox(height: 14),
        TextField(controller: title, decoration: const InputDecoration(labelText: 'Subject title')),
        const SizedBox(height: 14),
        TextField(controller: section, decoration: const InputDecoration(labelText: 'Section')),
        const SizedBox(height: 18),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: const Color(0xFFF8F6F3), border: Border.all(color: SmartGradeColors.line), borderRadius: BorderRadius.circular(9)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('STUDENT MASTERLIST (OPTIONAL)', style: TextStyle(fontSize: 10, letterSpacing: 1, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            const Text('Accepts the school CSV format: Student ID, Name, Course, Year Level. Separate name columns are also supported.', style: TextStyle(fontSize: 11, height: 1.4, color: SmartGradeColors.muted)),
            const SizedBox(height: 11),
            OutlinedButton.icon(
              onPressed: () async {
                try {
                  final result = await _pickStudentMasterlist();
                  if (result == null) return;
                  final parts = result.name.replaceFirst(RegExp(r'\.csv$', caseSensitive: false), '').split(' - ');
                  if (section.text.trim().isEmpty && parts.isNotEmpty) section.text = parts.first.trim();
                  if (code.text.trim().isEmpty && parts.length > 1) code.text = parts.last.trim();
                  setDialogState(() { selectedFile = result.name; importedStudents = result.students; importError = null; });
                } catch (error) {
                  setDialogState(() { selectedFile = null; importedStudents = []; importError = '$error'; });
                }
              },
              icon: const Icon(Icons.upload_file_outlined),
              label: const Text('Upload student masterlist'),
            ),
            if (selectedFile != null) Padding(padding: const EdgeInsets.only(top: 9), child: Row(children: [const Icon(Icons.check_circle, size: 17, color: Color(0xFF347147)), const SizedBox(width: 7), Expanded(child: Text('$selectedFile · ${importedStudents.length} students', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)))])),
            if (importError != null) Padding(padding: const EdgeInsets.only(top: 9), child: Text(importError!, style: const TextStyle(fontSize: 11, color: SmartGradeColors.red))),
          ]),
        ),
      ]))),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(importedStudents.isEmpty ? 'Create class' : 'Create & import')),
      ],
    )));
    if (accepted != true || code.text.trim().isEmpty || title.text.trim().isEmpty || section.text.trim().isEmpty) return;
    try {
      final created = await supabase.from('classes').insert({'subject_code': code.text.trim(), 'subject_title': title.text.trim(), 'section': section.text.trim(), 'teacher_id': supabase.auth.currentUser!.id}).select('id').single();
      if (importedStudents.isNotEmpty) await _importStudents(created['id'] as String, importedStudents);
      await load();
      if (mounted && importedStudents.isNotEmpty) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${importedStudents.length} students imported successfully.')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Class could not be created: $error')));
    }
  }

  Future<void> importInstructorLoad() async {
    final picked=await FilePicker.platform.pickFiles(type:FileType.custom,allowedExtensions:const ['csv','pdf','rpt'],withData:true);
    if(picked==null)return;
    final file=picked.files.single;
    final bytes=file.bytes;
    if(bytes==null){if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('The selected file could not be read.')));return;}
    setState(()=>importingLoad=true);
    try{
      final extension=(file.extension??'').toLowerCase();
      List<InstructorLoadClass> detected;
      if(extension=='csv'){
        detected=InstructorLoadParser.parseCsv(utf8.decode(bytes,allowMalformed:true));
      }else if(extension=='pdf'){
        final document=await PdfDocument.openData(bytes,sourceName:file.name);
        try{
          final text=StringBuffer();
          for(final page in document.pages){final pageText=await page.loadText();if(pageText!=null)text.writeln(pageText.fullText);}
          detected=InstructorLoadParser.parsePdfText(text.toString());
        }finally{await document.dispose();}
      }else if(extension=='rpt'){
        detected=InstructorLoadParser.parseRptBytes(bytes);
      }else{
        throw const FormatException('Choose a CSV, PDF, or Crystal Reports (.rpt) file.');
      }
      if(!mounted)return;
      final confirmed=await showDialog<List<InstructorLoadClass>>(context:context,builder:(_)=>_InstructorLoadReview(fileName:file.name,detected:detected));
      if(confirmed==null||confirmed.isEmpty)return;
      final teacherId=supabase.auth.currentUser!.id;
      final existingData=await supabase.from('classes').select('subject_code, section').eq('teacher_id',teacherId);
      final existing={for(final row in existingData)'${row['subject_code']}'.trim().toUpperCase()+'|'+'${row['section']}'.trim().toUpperCase()};
      final toCreate=confirmed.where((item)=>!existing.contains(item.key)).map((item)=>{'subject_code':item.subjectCode.trim(),'subject_title':item.subjectTitle.trim(),'section':item.section.trim(),'teacher_id':teacherId}).toList();
      if(toCreate.isNotEmpty)await supabase.from('classes').insert(toCreate);
      await load();
      if(mounted){final skipped=confirmed.length-toCreate.length;ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('${toCreate.length} classrooms created${skipped>0?' · $skipped existing classes skipped':''}.')));}
    }catch(error){
      if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('Instructor load could not be imported: $error'),duration:const Duration(seconds:8)));
    }finally{if(mounted)setState(()=>importingLoad=false);}
  }

  Future<_MasterlistFile?> _pickStudentMasterlist() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: const ['csv'], withData: true);
    if (result == null) return null;
    final file = result.files.single;
    final bytes = file.bytes;
    if (bytes == null) throw const FormatException('The selected CSV could not be read.');
    final text = utf8.decode(bytes, allowMalformed: true).replaceAll('\r\n', '\n').replaceAll('\r', '\n').trim();
    if (text.isEmpty) throw const FormatException('The selected CSV is empty.');
    final rows = const CsvToListConverter(eol: '\n', shouldParseNumbers: false).convert(text);
    if (rows.length < 2) throw FormatException('Only ${rows.length} CSV row was detected. Please select the exported school masterlist CSV, not the Excel class record.');
    final headers = rows.first.map((cell) => '$cell'.replaceFirst('\ufeff', '').trim().toLowerCase().replaceAll(' ', '_')).toList();
    int column(List<String> names) => headers.indexWhere(names.contains);
    final numberColumn = column(const ['student_number', 'student_no', 'student_id', 'id_number']);
    final lastColumn = column(const ['last_name', 'lastname', 'surname']);
    final firstColumn = column(const ['first_name', 'firstname', 'given_name']);
    final nameColumn = column(const ['name', 'student_name', 'learner_name', 'learners_name']);
    final emailColumn = column(const ['email', 'email_address']);
    final courseColumn = column(const ['course', 'program']);
    final yearColumn = column(const ['year_level', 'year']);
    if (numberColumn < 0 || ((lastColumn < 0 || firstColumn < 0) && nameColumn < 0)) throw const FormatException('Use either Student ID + Name, or student_number + last_name + first_name.');
    String value(List<dynamic> row, int index) => index >= 0 && index < row.length ? '${row[index]}'.trim() : '';
    final students = <Map<String, dynamic>>[];
    final seen = <String>{};
    for (final row in rows.skip(1)) {
      final number = value(row, numberColumn);
      var lastName = value(row, lastColumn);
      var firstName = value(row, firstColumn);
      if ((lastName.isEmpty || firstName.isEmpty) && nameColumn >= 0) {
        final combinedName = value(row, nameColumn);
        final comma = combinedName.indexOf(',');
        if (comma > 0) {
          lastName = combinedName.substring(0, comma).trim();
          firstName = combinedName.substring(comma + 1).trim();
        } else {
          final nameParts = combinedName.split(RegExp(r'\s+'));
          if (nameParts.length > 1) {
            lastName = nameParts.removeLast();
            firstName = nameParts.join(' ');
          }
        }
      }
      if (number.isEmpty && lastName.isEmpty && firstName.isEmpty) continue;
      if (number.isEmpty || lastName.isEmpty || firstName.isEmpty) throw FormatException('Every student needs a student number, last name, and first name. Check row ${students.length + 2}.');
      if (!seen.add(number.toLowerCase())) continue;
      students.add({'student_number': number, 'last_name': lastName, 'first_name': firstName, if (value(row, emailColumn).isNotEmpty) 'email': value(row, emailColumn), if (value(row, courseColumn).isNotEmpty) 'course': value(row, courseColumn), if (value(row, yearColumn).isNotEmpty) 'year_level': value(row, yearColumn)});
    }
    if (students.isEmpty) throw const FormatException('No valid student rows were found.');
    return _MasterlistFile(file.name, students);
  }

  Future<void> _importStudents(String classId, List<Map<String, dynamic>> rows) async {
    final numbers = rows.map((student) => student['student_number'] as String).toList();
    final existingData = await supabase.from('students').select('id, student_number').inFilter('student_number', numbers);
    final existing = <String, String>{for (final student in existingData) '${student['student_number']}': '${student['id']}'};
    const uuid = Uuid();
    final newStudents = <Map<String, dynamic>>[];
    for (final row in rows) {
      final number = row['student_number'] as String;
      if (!existing.containsKey(number)) {
        final id = uuid.v4();
        existing[number] = id;
        newStudents.add({'id': id, ...row});
      }
    }
    if (newStudents.isNotEmpty) await supabase.from('students').insert(newStudents);
    final enrollments = rows.map((student) => {'class_id': classId, 'student_id': existing[student['student_number']]!, 'status': 'active'}).toList();
    await supabase.from('class_enrollments').upsert(enrollments, onConflict: 'class_id,student_id', ignoreDuplicates: true);
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
              OutlinedButton.icon(onPressed: importingLoad?null:importInstructorLoad, icon: importingLoad?const SizedBox(width:16,height:16,child:CircularProgressIndicator(strokeWidth:2)):const Icon(Icons.file_upload_outlined), label: Text(importingLoad?'Reading file…':'Import instructor load')),
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

class _MasterlistFile {
  const _MasterlistFile(this.name, this.students);
  final String name;
  final List<Map<String, dynamic>> students;
}

class _InstructorLoadReview extends StatefulWidget{
  const _InstructorLoadReview({required this.fileName,required this.detected});
  final String fileName;
  final List<InstructorLoadClass> detected;
  @override State<_InstructorLoadReview> createState()=>_InstructorLoadReviewState();
}

class _InstructorLoadReviewState extends State<_InstructorLoadReview>{
  late final List<_LoadDraft> drafts=widget.detected.map(_LoadDraft.fromClass).toList();
  @override void dispose(){for(final draft in drafts){draft.dispose();}super.dispose();}
  @override Widget build(BuildContext context)=>AlertDialog(
    title:const Text('Review instructor load'),
    content:SizedBox(width:760,height:520,child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Text('${widget.fileName} · ${drafts.length} classes detected',style:const TextStyle(color:SmartGradeColors.muted,fontSize:12)),
      const SizedBox(height:12),
      Container(padding:const EdgeInsets.all(10),decoration:BoxDecoration(color:SmartGradeColors.mustardSoft,borderRadius:BorderRadius.circular(8)),child:const Row(children:[Icon(Icons.info_outline,size:18),SizedBox(width:8),Expanded(child:Text('Check the subject code, title, and section before creating the classrooms.',style:TextStyle(fontSize:11)))])),
      const SizedBox(height:12),
      Expanded(child:ListView.separated(itemCount:drafts.length,separatorBuilder:(_,__)=>const SizedBox(height:9),itemBuilder:(context,index){final draft=drafts[index];return Container(padding:const EdgeInsets.all(10),decoration:BoxDecoration(color:const Color(0xFFF8F6F3),border:Border.all(color:SmartGradeColors.line),borderRadius:BorderRadius.circular(8)),child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[SizedBox(width:125,child:TextField(controller:draft.code,decoration:const InputDecoration(labelText:'Subject code',isDense:true))),const SizedBox(width:8),Expanded(child:TextField(controller:draft.title,decoration:const InputDecoration(labelText:'Subject title',isDense:true))),const SizedBox(width:8),SizedBox(width:135,child:TextField(controller:draft.section,decoration:const InputDecoration(labelText:'Section',isDense:true))),IconButton(tooltip:'Remove',onPressed:(){draft.dispose();setState(()=>drafts.removeAt(index));},icon:const Icon(Icons.close_rounded,color:SmartGradeColors.red))]));})),
    ])),
    actions:[TextButton(onPressed:()=>Navigator.pop(context),child:const Text('Cancel')),FilledButton.icon(onPressed:drafts.isEmpty?null:(){final rows=drafts.map((draft)=>draft.value).where((item)=>item.subjectCode.isNotEmpty&&item.subjectTitle.isNotEmpty&&item.section.isNotEmpty).toList();Navigator.pop(context,rows);},icon:const Icon(Icons.add_business_outlined),label:Text('Create ${drafts.length} classrooms'))],
  );
}

class _LoadDraft{
  _LoadDraft.fromClass(InstructorLoadClass item):code=TextEditingController(text:item.subjectCode),title=TextEditingController(text:item.subjectTitle),section=TextEditingController(text:item.section);
  final TextEditingController code,title,section;
  InstructorLoadClass get value=>InstructorLoadClass(subjectCode:code.text.trim(),subjectTitle:title.text.trim(),section:section.text.trim());
  void dispose(){code.dispose();title.dispose();section.dispose();}
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
