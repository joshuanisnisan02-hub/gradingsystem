import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../core/design_system.dart';
import '../../core/supabase_client.dart';
import '../../core/workspace_shell.dart';
import 'grade_calculator.dart';
import 'exam_csv_parser.dart';

class GradebookScreen extends StatefulWidget {
  const GradebookScreen({super.key, required this.classId});
  final String classId;
  @override
  State<GradebookScreen> createState() => _GradebookScreenState();
}

class _GradebookScreenState extends State<GradebookScreen> {
  bool loading=true, saving=false;
  List<Map<String,dynamic>> enrollments=[], items=[];
  final Map<String,num?> scores={};
  String gradingPeriod='prelim';
  String category='quiz';
  int gradingBase=30;
  Map<String,dynamic>? classInfo;
  Map<String,double> weights=Map.of(_defaultWeights);
  final Map<String,Timer> scoreDebounces={};

  static const Map<String,double> _defaultWeights={
    'participation':10,
    'quiz':20,
    'assignment':20,
    'attendance':10,
    'examination':40,
  };
  static const Map<String,String> _periodLabels={'prelim':'Prelim','midterm':'Midterm','semifinal':'Semifinal','final':'Final'};
  static const Map<String,String> _categoryLabels={'participation':'Participation','quiz':'Quizzes','assignment':'Assignments','attendance':'Attendance','examination':'Examination','overall':'Overall Record'};
  static const List<String> _scoreCategories=['participation','quiz','assignment','attendance','examination'];

  @override void initState(){super.initState();load();}
  Future<void> load() async {
    if(mounted)setState(()=>loading=true);
    try {
      final roster=await supabase.from('class_enrollments').select('id, students(id, student_number, last_name, first_name, course, year_level)').eq('class_id',widget.classId).eq('status','active');
      var assessmentQuery=supabase.from('assessment_items').select().eq('class_id',widget.classId).eq('grading_period',gradingPeriod).eq('archived',false);
      if(category!='overall')assessmentQuery=assessmentQuery.eq('category',category);
      final assessments=List<Map<String,dynamic>>.from(await assessmentQuery.order('category').order('position').order('created_at'));
      assessments.sort(_compareAssessmentItems);
      final savedWeights=await supabase.from('grading_weights').select('category, weight').eq('class_id',widget.classId).eq('grading_period',gradingPeriod);
      final classSettings=await supabase.from('classes').select('grading_base, subject_code, subject_title, section').eq('id',widget.classId).single();
      final current=assessments.isEmpty ? <dynamic>[] : await supabase.from('scores').select('enrollment_id, assessment_item_id, raw_score').inFilter('assessment_item_id', assessments.map((e)=>e['id']).toList());
      scores.clear();
      for(final row in current){scores['${row['enrollment_id']}:${row['assessment_item_id']}']=row['raw_score'];}
      final loaded=Map<String,double>.of(_defaultWeights);
      for(final row in savedWeights){loaded['${row['category']}']=(row['weight'] as num).toDouble();}
      setState((){enrollments=List.from(roster);items=assessments;weights=loaded;classInfo=Map<String,dynamic>.from(classSettings);gradingBase=(classSettings['grading_base'] as num?)?.toInt()??30;loading=false;});
    } catch(e){if(mounted){setState(()=>loading=false);ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('Gradebook could not be loaded: $e')));}}
  }
  void changeScore(String enrollmentId,String itemId,num? value,num maximum){
    if(value!=null&&(value<0||value>maximum)){ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('Score must be between 0 and $maximum.')));return;}
    final key='$enrollmentId:$itemId';
    setState((){scores[key]=value;saving=true;});
    scoreDebounces[key]?.cancel();
    scoreDebounces[key]=Timer(const Duration(milliseconds:700),()=>save(enrollmentId,itemId,value));
  }
  Future<void> save(String enrollmentId,String itemId,num? value) async {await supabase.from('scores').upsert({'enrollment_id':enrollmentId,'assessment_item_id':itemId,'raw_score':value,'status':value==null?'missing':'scored','updated_by':supabase.auth.currentUser!.id},onConflict:'enrollment_id,assessment_item_id');if(mounted)setState(()=>saving=false);}
  Future<void> editWeights() async {
    final updated=await showDialog<_GradingSettingsResult>(context: context,builder: (_)=>_WeightDialog(initial: weights,initialBase:gradingBase));
    if(updated==null)return;
    setState(()=>saving=true);
    try {
      await supabase.from('grading_weights').upsert(
        updated.weights.entries.map((entry)=>{
          'class_id':widget.classId,
          'grading_period':gradingPeriod,
          'category':entry.key,
          'weight':entry.value,
          'updated_at':DateTime.now().toUtc().toIso8601String(),
        }).toList(),
        onConflict:'class_id,grading_period,category',
      );
      await supabase.from('classes').update({'grading_base':updated.base,'updated_at':DateTime.now().toUtc().toIso8601String()}).eq('id',widget.classId);
      if(mounted){setState((){weights=updated.weights;gradingBase=updated.base;});ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('Grading settings saved: ${updated.base==0?'Board course · Base 0':'Non-board course · Base 30'}.')));}
    } catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('Percentages could not be saved: $e')));}
    finally{if(mounted)setState(()=>saving=false);}
  }
  Future<void> addItem() async {
    final categoryItems=items.where((item)=>item['category']==category).toList();
    final result=await showDialog<_AssessmentItemResult>(context:context,builder:(_)=>_AddItemDialog(categoryLabel:_categoryLabels[category]!,suggestedNumber:categoryItems.length+1));
    if(result==null)return;
    setState(()=>saving=true);
    try{
      final nextPosition=categoryItems.fold<int>(-1,(current,item){final position=(item['position'] as num?)?.toInt()??-1;return position>current?position:current;})+1;
      await supabase.from('assessment_items').insert({'class_id':widget.classId,'grading_period':gradingPeriod,'category':category,'title':result.title,'maximum_score':result.maximumScore,'position':nextPosition,'source':'manual'});
      await load();
      if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('${result.title} added to ${_categoryLabels[category]}.')));
    }catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('Item could not be added: $e')));}
    finally{if(mounted)setState(()=>saving=false);}
  }
  int _compareAssessmentItems(Map<String,dynamic> a,Map<String,dynamic> b){
    final categoryOrder=_scoreCategories.indexOf('${a['category']}').compareTo(_scoreCategories.indexOf('${b['category']}'));
    if(categoryOrder!=0)return categoryOrder;
    int sequence(Map<String,dynamic> item)=>int.tryParse(RegExp(r'\d+').firstMatch('${item['title']}')?.group(0)??'')??2147483647;
    final numbered=sequence(a).compareTo(sequence(b));
    if(numbered!=0)return numbered;
    final positioned=((a['position'] as num?)?.toInt()??0).compareTo((b['position'] as num?)?.toInt()??0);
    return positioned!=0?positioned:'${a['title']}'.compareTo('${b['title']}');
  }

  Future<void> importExamCsv() async {
    try{
      final selection=await FilePicker.platform.pickFiles(type:FileType.custom,allowedExtensions:const ['csv'],withData:true);
      if(selection==null)return;
      final bytes=selection.files.single.bytes;
      if(bytes==null)throw const FormatException('The selected CSV could not be read.');
      final csv=ExamCsvParser.parse(utf8.decode(bytes,allowMalformed:true));
      final matches=<_ExamMatch>[];
      final unmatched=<String>[];
      var blankScores=0;
      var invalidScores=0;
      for(final row in csv.rows){
        final candidates=enrollments.where((enrollment){final student=enrollment['students'] as Map<String,dynamic>;return ExamCsvParser.nameMatches(rosterLastName:'${student['last_name']}',rosterFirstName:'${student['first_name']}',csvName:row.studentName);}).toList();
        if(candidates.length!=1){unmatched.add(row.studentName);continue;}
        if(row.score==null){blankScores++;continue;}
        if(row.score!<0||row.score!>csv.maximumScore){invalidScores++;continue;}
        matches.add(_ExamMatch(enrollmentId:'${candidates.single['id']}',studentName:row.studentName,score:row.score!));
      }
      if(!mounted)return;
      final approved=await showDialog<bool>(context:context,builder:(_)=>_ExamImportPreview(data:csv,matches:matches,unmatched:unmatched,blankScores:blankScores,invalidScores:invalidScores));
      if(approved!=true||matches.isEmpty)return;
      setState(()=>saving=true);
      Map<String,dynamic>? examItem;
      for(final item in items){if('${item['title']}'.trim().toLowerCase()==csv.title.trim().toLowerCase()&&(item['maximum_score'] as num).toDouble()==csv.maximumScore){examItem=item;break;}}
      if(examItem==null){
        final nextPosition=items.fold<int>(-1,(current,item){final position=(item['position'] as num?)?.toInt()??-1;return position>current?position:current;})+1;
        examItem=Map<String,dynamic>.from(await supabase.from('assessment_items').insert({'class_id':widget.classId,'grading_period':gradingPeriod,'category':'examination','title':csv.title,'maximum_score':csv.maximumScore,'position':nextPosition,'source':'csv'}).select().single());
      }
      final userId=supabase.auth.currentUser!.id;
      await supabase.from('scores').upsert(matches.map((match)=>{'enrollment_id':match.enrollmentId,'assessment_item_id':examItem!['id'],'raw_score':match.score,'status':'scored','source':'csv','updated_by':userId}).toList(),onConflict:'enrollment_id,assessment_item_id');
      await load();
      if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('${matches.length} exam scores imported by student name.')));
    }catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('Exam CSV could not be imported: $e')));}
    finally{if(mounted)setState(()=>saving=false);}
  }

  Uint8List _csvBytes(List<List<dynamic>> rows){
    final csv=const ListToCsvConverter().convert(rows);
    return Uint8List.fromList([0xEF,0xBB,0xBF,...utf8.encode(csv)]);
  }
  String _safeFilePart(Object? value)=>'${value??''}'.trim().replaceAll(RegExp(r'[^A-Za-z0-9 _-]+'),'').replaceAll(RegExp(r'\s+'),' ').trim();
  Future<void> _saveCsv(String fileName,List<List<dynamic>> rows) async {
    await FilePicker.platform.saveFile(dialogTitle:'Save CSV export',fileName:fileName,type:FileType.custom,allowedExtensions:const ['csv'],bytes:_csvBytes(rows));
    if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('$fileName exported.')));
  }
  Future<void> exportCurrentCategoryCsv() async {
    try{
      setState(()=>saving=true);
      final period=_periodLabels[gradingPeriod]!;
      final label=_categoryLabels[category]!;
      final rows=<List<dynamic>>[];
      if(category=='overall'){
        rows.add(['Student ID','Name',..._scoreCategories.map((key)=>_categoryLabels[key]),'Period Grade','Remarks']);
        for(final enrollment in enrollments){
          final student=enrollment['students'] as Map<String,dynamic>;
          final categoryGrades=<String,double>{};
          for(final key in _scoreCategories){final categoryItems=items.where((item)=>item['category']==key).toList();categoryGrades[key]=GradeCalculator.categoryTotal(categoryItems.map((item)=>scores['${enrollment['id']}:${item['id']}']).toList(),categoryItems.map((item)=>(item['maximum_score'] as num)).toList(),base:gradingBase);}
          final grade=_scoreCategories.fold<double>(0,(sum,key)=>sum+(categoryGrades[key]??0)*(weights[key]??0)/100);
          rows.add([student['student_number'],'${student['last_name']}, ${student['first_name']}',..._scoreCategories.map((key)=>categoryGrades[key]!.toStringAsFixed(2)),grade.toStringAsFixed(2),grade>=75?'PASSED':'FAILED']);
        }
      }else{
        rows.add(['Student ID','Name',...items.map((item)=>'${item['title']} (Max ${item['maximum_score']})'),'Total','Average']);
        for(final enrollment in enrollments){
          final student=enrollment['students'] as Map<String,dynamic>;
          final earned=items.fold<double>(0,(sum,item)=>sum+(scores['${enrollment['id']}:${item['id']}']??0).toDouble());
          final possible=items.fold<double>(0,(sum,item)=>sum+(item['maximum_score'] as num).toDouble());
          rows.add([student['student_number'],'${student['last_name']}, ${student['first_name']}',...items.map((item)=>scores['${enrollment['id']}:${item['id']}']?.toString()??''),earned.toStringAsFixed(2),GradeCalculator.transmutedPercentage(earned,possible,base:gradingBase).toStringAsFixed(2)]);
        }
      }
      final fileName='${_safeFilePart(classInfo?['subject_code'])}_${_safeFilePart(classInfo?['section'])}_${_safeFilePart(period)}_${_safeFilePart(label)}.csv';
      await _saveCsv(fileName,rows);
    }catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('Gradebook CSV could not be exported: $e')));}
    finally{if(mounted)setState(()=>saving=false);}
  }
  Future<void> exportSchoolGradesCsv() async {
    try{
      setState(()=>saving=true);
      final allItems=List<Map<String,dynamic>>.from(await supabase.from('assessment_items').select().eq('class_id',widget.classId).eq('grading_period',gradingPeriod).eq('archived',false).order('category').order('position'));
      final allScores=<String,num?>{};
      if(allItems.isNotEmpty){
        final scoreRows=await supabase.from('scores').select('enrollment_id, assessment_item_id, raw_score').inFilter('assessment_item_id',allItems.map((item)=>item['id']).toList());
        for(final row in scoreRows){allScores['${row['enrollment_id']}:${row['assessment_item_id']}']=row['raw_score'];}
      }
      final periodColumn={'prelim':4,'midterm':5,'semifinal':6,'final':7}[gradingPeriod]!;
      final rows=<List<dynamic>>[['Student ID','Name','Course','Year Level','PRELIM','MIDTERM','SEMI','FINAL','AVERAGE']];
      for(final enrollment in enrollments){
        final student=enrollment['students'] as Map<String,dynamic>;
        final categoryGrades=<String,double>{};
        for(final key in _scoreCategories){final categoryItems=allItems.where((item)=>item['category']==key).toList();categoryGrades[key]=GradeCalculator.categoryTotal(categoryItems.map((item)=>allScores['${enrollment['id']}:${item['id']}']).toList(),categoryItems.map((item)=>(item['maximum_score'] as num)).toList(),base:gradingBase);}
        final periodGrade=_scoreCategories.fold<double>(0,(sum,key)=>sum+(categoryGrades[key]??0)*(weights[key]??0)/100);
        final row=<dynamic>[student['student_number'],'${student['last_name']}, ${student['first_name']}',student['course']??'',student['year_level']??'','','','',''];
        row[periodColumn]=periodGrade.round();
        rows.add(row);
      }
      final fileName='${_safeFilePart(classInfo?['section'])} - ${_safeFilePart(_periodLabels[gradingPeriod])} Grades - ${_safeFilePart(classInfo?['subject_code'])}.csv';
      await _saveCsv(fileName,rows);
    }catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('School grades CSV could not be exported: $e')));}
    finally{if(mounted)setState(()=>saving=false);}
  }
  @override void dispose(){for(final timer in scoreDebounces.values){timer.cancel();}super.dispose();}

  @override
  Widget build(BuildContext context) => WorkspaceShell(
    title: classInfo==null?'Class Gradebook':'${classInfo!['subject_code']} · ${classInfo!['section']}',
    active: 'Gradebook',
    actions: [OutlinedButton.icon(onPressed:saving?null:editWeights,icon:const Icon(Icons.tune_rounded,size:17),label:const Text('Grading settings')),const SizedBox(width:10),Container(padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7), decoration: BoxDecoration(color: saving ? SmartGradeColors.mustardSoft : const Color(0xFFEAF4EC), borderRadius: BorderRadius.circular(18)), child: Row(children: [Icon(saving ? Icons.sync : Icons.cloud_done_outlined, size: 15, color: saving ? SmartGradeColors.black : const Color(0xFF347147)), const SizedBox(width: 6), Text(saving ? 'Saving…' : 'All changes saved', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700))]))],
    child: loading ? const Center(child: CircularProgressIndicator()) : Padding(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(runSpacing: 12, spacing: 12, crossAxisAlignment: WrapCrossAlignment.center, children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('${classInfo?['subject_title']??'GRADE ENTRY'}'.toUpperCase(), style: const TextStyle(fontSize: 9, letterSpacing: 1.4, color: SmartGradeColors.red, fontWeight: FontWeight.w800)),const SizedBox(height: 5),Text('${_periodLabels[gradingPeriod]} · ${_categoryLabels[category]}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800))]),
          const SizedBox(width: 18),
          _Pill(icon: Icons.people_outline, text: '${enrollments.length} students'),
          _Pill(icon: Icons.assignment_outlined, text: '${items.length} activities'),
        ]),
        const SizedBox(height:14),
        Wrap(spacing:8,runSpacing:8,crossAxisAlignment:WrapCrossAlignment.center,children:[
          SizedBox(width:150,child:DropdownButtonFormField<String>(initialValue:gradingPeriod,decoration:const InputDecoration(labelText:'Grading period',isDense:true),items:_periodLabels.entries.map((entry)=>DropdownMenuItem(value:entry.key,child:Text(entry.value))).toList(),onChanged:(value){if(value!=null&&value!=gradingPeriod){gradingPeriod=value;load();}})),
          ..._categoryLabels.entries.map((entry)=>ChoiceChip(label:Text(entry.value),selected:category==entry.key,onSelected:(_){if(category!=entry.key){category=entry.key;load();}})),
          if(category=='examination')OutlinedButton.icon(onPressed:saving?null:importExamCsv,icon:const Icon(Icons.upload_file_outlined,size:17),label:const Text('Import exam CSV')),
          if(category!='overall')OutlinedButton.icon(onPressed:saving?null:addItem,icon:const Icon(Icons.add,size:17),label:const Text('Add item')),
          PopupMenuButton<String>(
            tooltip:'Export gradebook',
            enabled:!saving,
            onSelected:(value){if(value=='category')exportCurrentCategoryCsv();if(value=='school')exportSchoolGradesCsv();},
            itemBuilder:(_)=>[PopupMenuItem(value:'category',child:ListTile(dense:true,leading:const Icon(Icons.table_view_outlined),title:Text('Export ${_categoryLabels[category]} CSV'),subtitle:Text('${_periodLabels[gradingPeriod]} gradebook'))),const PopupMenuItem(value:'school',child:ListTile(dense:true,leading:Icon(Icons.school_outlined),title:Text('Export school grades CSV'),subtitle:Text('Student ID, Name, Course, Year Level and period grade')))],
            child:Container(padding:const EdgeInsets.symmetric(horizontal:14,vertical:9),decoration:BoxDecoration(border:Border.all(color:SmartGradeColors.line),borderRadius:BorderRadius.circular(22)),child:const Row(mainAxisSize:MainAxisSize.min,children:[Icon(Icons.download_outlined,size:18,color:SmartGradeColors.red),SizedBox(width:7),Text('Export CSV',style:TextStyle(color:SmartGradeColors.red))])),
          ),
        ]),
        const SizedBox(height: 19),
        Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10), decoration: BoxDecoration(color: Colors.white, border: Border.all(color: SmartGradeColors.line), borderRadius: BorderRadius.circular(9)), child: const Row(children: [Icon(Icons.info_outline_rounded, color: SmartGradeColors.mustard, size: 19), SizedBox(width: 9), Expanded(child: Text('Enter a score, then press Enter. Changes save automatically.', style: TextStyle(fontSize: 11, color: SmartGradeColors.muted))), Icon(Icons.keyboard_alt_outlined, size: 18, color: SmartGradeColors.muted)])),
        const SizedBox(height: 14),
        Expanded(child: category=='overall' ? _buildOverallRecord() : items.isEmpty ? _NoItems(categoryLabel:_categoryLabels[category]!,onAdd:addItem) : Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Expanded(child: Container(decoration: BoxDecoration(color: Colors.white, border: Border.all(color: SmartGradeColors.line), borderRadius: BorderRadius.circular(9)), clipBehavior: Clip.antiAlias, child: LayoutBuilder(builder:(context,constraints)=>SingleChildScrollView(scrollDirection: Axis.horizontal, child: ConstrainedBox(constraints:BoxConstraints(minWidth:constraints.maxWidth),child:SingleChildScrollView(child: Theme(data: Theme.of(context).copyWith(dividerColor: SmartGradeColors.line), child: DataTable(
            headingRowColor: WidgetStateProperty.all(const Color(0xFFF0EEEB)),
            horizontalMargin:16,
            columnSpacing:items.length>=6?18:32,
            dataRowMinHeight: 60,
            dataRowMaxHeight: 60,
            columns: [const DataColumn(label: SizedBox(width: 210, child: Text('STUDENT', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: .7)))), ...items.map((item) => DataColumn(label: Text('${item['title']}\nMAX ${item['maximum_score']}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700)))), const DataColumn(label: Text('TOTAL')), const DataColumn(label: Text('AVERAGE'))],
            rows: enrollments.map((enrollment) {
              final student = enrollment['students'];
              final earned = items.fold<double>(0, (sum, item) => sum + (scores['${enrollment['id']}:${item['id']}'] ?? 0).toDouble());
              final possible = items.fold<double>(0, (sum, item) => sum + (item['maximum_score'] as num).toDouble());
              final average = GradeCalculator.transmutedPercentage(earned, possible,base:gradingBase);
              return DataRow(cells: [
                DataCell(SizedBox(width: 210, child: Row(children: [CircleAvatar(radius: 15, backgroundColor: SmartGradeColors.mustardSoft, foregroundColor: SmartGradeColors.black, child: Text('${student['first_name']}'.isEmpty ? '?' : '${student['first_name']}'.substring(0, 1), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11))), const SizedBox(width: 10), Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [Text('${student['last_name']}, ${student['first_name']}', overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)), Text('${student['student_number']}', style: const TextStyle(color: SmartGradeColors.muted, fontSize: 10))]))]))),
                ...items.map((item) { final key = '${enrollment['id']}:${item['id']}'; return DataCell(SizedBox(width: 72, child: TextFormField(key: ValueKey(key), initialValue: scores[key]?.toString() ?? '', textAlign: TextAlign.center, keyboardType: const TextInputType.numberWithOptions(decimal:true), onChanged: (value) => changeScore(enrollment['id'], item['id'], value.trim().isEmpty?null:num.tryParse(value), item['maximum_score']), decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 9))))); }),
                DataCell(Text(earned.toStringAsFixed(0), style: const TextStyle(fontWeight: FontWeight.w800))),
                DataCell(Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5), decoration: BoxDecoration(color: average < 75 ? const Color(0xFFFFE8E8) : const Color(0xFFEAF4EC), borderRadius: BorderRadius.circular(12)), child: Text('${average.toStringAsFixed(1)}%', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: average < 75 ? SmartGradeColors.red : const Color(0xFF347147))))),
              ]);
            }).toList(),
          )))))))),
          if (MediaQuery.sizeOf(context).width >= 1180) ...[const SizedBox(width: 14), SizedBox(width:245,child:_Insights(onExport:exportCurrentCategoryCsv,onSchoolExport:exportSchoolGradesCsv))],
        ])),
      ]),
    ),
  );

  Widget _buildOverallRecord(){
    if(items.isEmpty)return const _OverallEmpty();
    return Container(decoration:BoxDecoration(color:Colors.white,border:Border.all(color:SmartGradeColors.line),borderRadius:BorderRadius.circular(9)),clipBehavior:Clip.antiAlias,child:LayoutBuilder(builder:(context,constraints)=>SingleChildScrollView(scrollDirection:Axis.horizontal,child:ConstrainedBox(constraints:BoxConstraints(minWidth:constraints.maxWidth),child:SingleChildScrollView(child:DataTable(
      headingRowColor:WidgetStateProperty.all(const Color(0xFFF0EEEB)),horizontalMargin:16,columnSpacing:24,dataRowMinHeight:60,dataRowMaxHeight:60,
      columns:[const DataColumn(label:SizedBox(width:210,child:Text('STUDENT',style:TextStyle(fontSize:10,fontWeight:FontWeight.w800)))),..._scoreCategories.map((key)=>DataColumn(label:Text('${_categoryLabels[key]!.toUpperCase()}\n${weights[key]?.toStringAsFixed(0)??'0'}%',style:const TextStyle(fontSize:10,fontWeight:FontWeight.w700)))),const DataColumn(label:Text('PERIOD GRADE')),const DataColumn(label:Text('REMARKS'))],
      rows:enrollments.map((enrollment){
        final categoryGrades=<String,double>{};
        for(final key in _scoreCategories){final categoryItems=items.where((item)=>item['category']==key).toList();categoryGrades[key]=GradeCalculator.categoryTotal(categoryItems.map((item)=>scores['${enrollment['id']}:${item['id']}']).toList(),categoryItems.map((item)=>(item['maximum_score'] as num)).toList(),base:gradingBase);}
        final periodGrade=_scoreCategories.fold<double>(0,(sum,key)=>sum+(categoryGrades[key]??0)*(weights[key]??0)/100);
        final student=enrollment['students'];
        return DataRow(cells:[DataCell(SizedBox(width:210,child:Column(mainAxisAlignment:MainAxisAlignment.center,crossAxisAlignment:CrossAxisAlignment.start,children:[Text('${student['last_name']}, ${student['first_name']}',overflow:TextOverflow.ellipsis,style:const TextStyle(fontWeight:FontWeight.w700,fontSize:12)),Text('${student['student_number']}',style:const TextStyle(color:SmartGradeColors.muted,fontSize:10))]))),..._scoreCategories.map((key)=>DataCell(Text(categoryGrades[key]!.toStringAsFixed(1),style:const TextStyle(fontWeight:FontWeight.w700)))),DataCell(Text(periodGrade.toStringAsFixed(2),style:const TextStyle(fontWeight:FontWeight.w900))),DataCell(Text(periodGrade>=75?'PASSED':'FAILED',style:TextStyle(fontWeight:FontWeight.w800,color:periodGrade>=75?const Color(0xFF347147):SmartGradeColors.red)))]);
      }).toList(),
    ))))));
  }
}

class _GradingSettingsResult {
  const _GradingSettingsResult({required this.weights,required this.base});
  final Map<String,double> weights;
  final int base;
}

class _AssessmentItemResult {
  const _AssessmentItemResult({required this.title,required this.maximumScore});
  final String title;
  final double maximumScore;
}

class _ExamMatch {
  const _ExamMatch({required this.enrollmentId,required this.studentName,required this.score});
  final String enrollmentId;
  final String studentName;
  final double score;
}

class _ExamImportPreview extends StatelessWidget {
  const _ExamImportPreview({required this.data,required this.matches,required this.unmatched,required this.blankScores,required this.invalidScores});
  final ExamCsvData data;
  final List<_ExamMatch> matches;
  final List<String> unmatched;
  final int blankScores;
  final int invalidScores;
  @override Widget build(BuildContext context)=>AlertDialog(
    title:const Text('Review exam CSV'),
    content:SizedBox(width:500,child:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[
      Text(data.title,style:const TextStyle(fontWeight:FontWeight.w800,fontSize:16)),
      const SizedBox(height:4),Text('Highest possible score: ${data.maximumScore.toStringAsFixed(data.maximumScore%1==0?0:2)}',style:const TextStyle(color:SmartGradeColors.muted)),
      const SizedBox(height:16),_ImportSummary(icon:Icons.check_circle_outline,color:const Color(0xFF347147),text:'${matches.length} names matched with scores'),
      _ImportSummary(icon:Icons.remove_circle_outline,color:SmartGradeColors.mustard,text:'$blankScores matched students have no score'),
      if(invalidScores>0)_ImportSummary(icon:Icons.error_outline,color:SmartGradeColors.red,text:'$invalidScores scores are outside the allowed range'),
      if(unmatched.isNotEmpty)...[const SizedBox(height:12),Text('${unmatched.length} names were not uniquely matched:',style:const TextStyle(fontWeight:FontWeight.w800)),const SizedBox(height:6),Text(unmatched.take(8).join('\n'),style:const TextStyle(fontSize:12,color:SmartGradeColors.muted)),if(unmatched.length>8)Text('…and ${unmatched.length-8} more',style:const TextStyle(fontSize:12,color:SmartGradeColors.muted))],
      const SizedBox(height:14),const Text('Only matched names with valid scores will be imported. Student ID is not used.',style:TextStyle(fontSize:11,color:SmartGradeColors.muted)),
    ]))),
    actions:[TextButton(onPressed:()=>Navigator.pop(context,false),child:const Text('Cancel')),FilledButton(onPressed:matches.isEmpty?null:()=>Navigator.pop(context,true),child:Text('Import ${matches.length} scores'))],
  );
}

class _ImportSummary extends StatelessWidget {
  const _ImportSummary({required this.icon,required this.color,required this.text});
  final IconData icon;final Color color;final String text;
  @override Widget build(BuildContext context)=>Padding(padding:const EdgeInsets.only(bottom:8),child:Row(children:[Icon(icon,size:19,color:color),const SizedBox(width:8),Text(text,style:const TextStyle(fontWeight:FontWeight.w700))]));
}

class _AddItemDialog extends StatefulWidget {
  const _AddItemDialog({required this.categoryLabel,required this.suggestedNumber});
  final String categoryLabel;
  final int suggestedNumber;
  @override State<_AddItemDialog> createState()=>_AddItemDialogState();
}

class _AddItemDialogState extends State<_AddItemDialog>{
  late final title=TextEditingController(text:'${widget.categoryLabel.replaceAll('Quizzes','Quiz').replaceAll('Assignments','Assignment')} ${widget.suggestedNumber}');
  final maximum=TextEditingController(text:'100');
  @override void dispose(){title.dispose();maximum.dispose();super.dispose();}
  @override Widget build(BuildContext context)=>AlertDialog(title:Text('Add ${widget.categoryLabel} item'),content:SizedBox(width:400,child:Column(mainAxisSize:MainAxisSize.min,children:[TextField(controller:title,autofocus:true,decoration:const InputDecoration(labelText:'Item name')),const SizedBox(height:12),TextField(controller:maximum,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'Highest possible score'))])),actions:[TextButton(onPressed:()=>Navigator.pop(context),child:const Text('Cancel')),FilledButton(onPressed:(){final name=title.text.trim();final max=double.tryParse(maximum.text.trim());if(name.isEmpty||max==null||max<=0){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Enter an item name and a valid highest score.')));return;}Navigator.pop(context,_AssessmentItemResult(title:name,maximumScore:max));},child:const Text('Add item'))]);
}

class _WeightDialog extends StatefulWidget {
  const _WeightDialog({required this.initial,required this.initialBase});
  final Map<String,double> initial;
  final int initialBase;
  @override State<_WeightDialog> createState()=>_WeightDialogState();
}

class _WeightDialogState extends State<_WeightDialog> {
  late int gradingBase=widget.initialBase;
  late final Map<String,TextEditingController> controllers={
    for(final entry in widget.initial.entries) entry.key:TextEditingController(text:entry.value.toStringAsFixed(entry.value%1==0?0:2)),
  };
  static const labels={
    'participation':'Participation','quiz':'Quizzes','assignment':'Assignments','attendance':'Attendance','examination':'Examination',
  };
  Map<String,double> get values=>{for(final entry in controllers.entries) entry.key:double.tryParse(entry.value.text.trim())??0};
  double get total=>GradeCalculator.weightTotal(values.values);
  @override void dispose(){for(final controller in controllers.values){controller.dispose();}super.dispose();}
  @override Widget build(BuildContext context){
    final valid=GradeCalculator.hasValidWeightTotal(values.values);
    return AlertDialog(
      title:const Text('Grading percentages'),
      content:SizedBox(width:430,child:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[
        const Text('Set the course basis and percentage for each category. These settings apply to the selected class.',style:TextStyle(color:SmartGradeColors.muted,fontSize:12)),
        const SizedBox(height:16),
        DropdownButtonFormField<int>(initialValue:gradingBase,decoration:const InputDecoration(labelText:'Course grading basis'),items:const [DropdownMenuItem(value:0,child:Text('Board course — Base 0')),DropdownMenuItem(value:30,child:Text('Non-board course — Base 30'))],onChanged:(value)=>setState(()=>gradingBase=value??30)),
        const SizedBox(height:16),
        ...controllers.entries.map((entry)=>Padding(padding:const EdgeInsets.only(bottom:10),child:TextField(controller:entry.value,keyboardType:const TextInputType.numberWithOptions(decimal:true),onChanged:(_)=>setState((){}),decoration:InputDecoration(labelText:labels[entry.key],suffixText:'%',helperText:entry.key=='examination'?'Workbook default: 40%':null)))),
        Container(padding:const EdgeInsets.all(12),decoration:BoxDecoration(color:valid?const Color(0xFFEAF4EC):const Color(0xFFFFE8E8),borderRadius:BorderRadius.circular(8)),child:Row(children:[Icon(valid?Icons.check_circle_outline:Icons.error_outline,color:valid?const Color(0xFF347147):SmartGradeColors.red),const SizedBox(width:9),Expanded(child:Text('Total: ${total.toStringAsFixed(total%1==0?0:2)}%${valid?' — Ready to save':' — Must equal 100%'}',style:TextStyle(fontWeight:FontWeight.w800,color:valid?const Color(0xFF347147):SmartGradeColors.red)))])),
      ]))),
      actions:[TextButton(onPressed:()=>Navigator.pop(context),child:const Text('Cancel')),FilledButton(onPressed:valid?()=>Navigator.pop(context,_GradingSettingsResult(weights:values,base:gradingBase)):null,child:const Text('Save settings'))],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.text});
  final IconData icon; final String text;
  @override Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8), decoration: BoxDecoration(color: Colors.white, border: Border.all(color: SmartGradeColors.line), borderRadius: BorderRadius.circular(18)), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 15, color: SmartGradeColors.red), const SizedBox(width: 6), Text(text, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700))]));
}

class _Insights extends StatelessWidget {
  const _Insights({required this.onExport,required this.onSchoolExport});
  final VoidCallback onExport,onSchoolExport;
  @override Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(18), decoration: BoxDecoration(color: Colors.white, border: Border.all(color: SmartGradeColors.line), borderRadius: BorderRadius.circular(9)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('CLASS INSIGHTS', style: TextStyle(fontSize: 10, letterSpacing: 1.1, fontWeight: FontWeight.w800)), const SizedBox(height: 18), const _Insight(icon: Icons.warning_amber_rounded, color: SmartGradeColors.red, title: 'Missing scores', detail: 'Review blank cells before finalizing.'), const Divider(height: 30), const _Insight(icon: Icons.lightbulb_outline_rounded, color: SmartGradeColors.mustard, title: 'Quick tip', detail: 'Press Enter after each score to save.'), const Spacer(), const Text('ACTIONS', style: TextStyle(fontSize: 9, letterSpacing: 1.1, color: SmartGradeColors.muted, fontWeight: FontWeight.w800)), const SizedBox(height: 12), ListTile(onTap:onExport,contentPadding:EdgeInsets.zero,dense:true,leading:const Icon(Icons.download_outlined,size:18),title:const Text('Export selected gradebook',style:TextStyle(fontSize:11))),ListTile(onTap:onSchoolExport,contentPadding:EdgeInsets.zero,dense:true,leading:const Icon(Icons.school_outlined,size:18),title:const Text('Export school grades CSV',style:TextStyle(fontSize:11))),const ListTile(contentPadding:EdgeInsets.zero,dense:true,leading:Icon(Icons.print_outlined,size:18),title:Text('Print class record',style:TextStyle(fontSize:11)))]));
}

class _Insight extends StatelessWidget {
  const _Insight({required this.icon, required this.color, required this.title, required this.detail});
  final IconData icon; final Color color; final String title; final String detail;
  @override Widget build(BuildContext context) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(icon, color: color, size: 20), const SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)), const SizedBox(height: 4), Text(detail, style: const TextStyle(fontSize: 10, height: 1.4, color: SmartGradeColors.muted))]))]);
}

class _NoItems extends StatelessWidget {
  const _NoItems({required this.categoryLabel,required this.onAdd});
  final String categoryLabel;
  final VoidCallback onAdd;
  @override Widget build(BuildContext context) => Container(width: double.infinity, decoration: BoxDecoration(color: Colors.white, border: Border.all(color: SmartGradeColors.line), borderRadius: BorderRadius.circular(9)), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.assignment_outlined, size: 43, color: SmartGradeColors.red),const SizedBox(height: 12),Text('No $categoryLabel items yet', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),const SizedBox(height: 5),const Text('Add the first item, then enter each student’s score.', style: TextStyle(color: SmartGradeColors.muted)),const SizedBox(height:16),FilledButton.icon(onPressed:onAdd,icon:const Icon(Icons.add),label:const Text('Add first item'))]));
}

class _OverallEmpty extends StatelessWidget{
  const _OverallEmpty();
  @override Widget build(BuildContext context)=>Container(width:double.infinity,decoration:BoxDecoration(color:Colors.white,border:Border.all(color:SmartGradeColors.line),borderRadius:BorderRadius.circular(9)),child:const Column(mainAxisAlignment:MainAxisAlignment.center,children:[Icon(Icons.calculate_outlined,size:43,color:SmartGradeColors.red),SizedBox(height:12),Text('No scores to summarize yet',style:TextStyle(fontWeight:FontWeight.w800,fontSize:17)),SizedBox(height:5),Text('Add items under the five grading categories first.',style:TextStyle(color:SmartGradeColors.muted))]));
}
