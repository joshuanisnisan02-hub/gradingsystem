import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/design_system.dart';
import '../../core/supabase_client.dart';
import '../../core/workspace_shell.dart';
import 'grade_calculator.dart';

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
  int gradingBase=30;
  Map<String,double> weights=Map.of(_defaultWeights);
  Timer? debounce;

  static const Map<String,double> _defaultWeights={
    'participation':10,
    'quiz':20,
    'assignment':20,
    'attendance':10,
    'examination':40,
  };

  @override void initState(){super.initState();load();}
  Future<void> load() async {
    try {
      final roster=await supabase.from('class_enrollments').select('id, students(id, student_number, last_name, first_name)').eq('class_id',widget.classId).eq('status','active');
      final assessments=await supabase.from('assessment_items').select().eq('class_id',widget.classId).eq('category','quiz').eq('archived',false).order('position');
      final savedWeights=await supabase.from('grading_weights').select('category, weight').eq('class_id',widget.classId).eq('grading_period',gradingPeriod);
      final classSettings=await supabase.from('classes').select('grading_base').eq('id',widget.classId).single();
      final current=await supabase.from('scores').select('enrollment_id, assessment_item_id, raw_score').inFilter('assessment_item_id', List.from(assessments).map((e)=>e['id']).toList());
      for(final row in current){scores['${row['enrollment_id']}:${row['assessment_item_id']}']=row['raw_score'];}
      final loaded=Map<String,double>.of(_defaultWeights);
      for(final row in savedWeights){loaded['${row['category']}']=(row['weight'] as num).toDouble();}
      setState((){enrollments=List.from(roster);items=List.from(assessments);weights=loaded;gradingBase=(classSettings['grading_base'] as num?)?.toInt()??30;loading=false;});
    } catch(e){if(mounted){setState(()=>loading=false);ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('Gradebook could not be loaded: $e')));}}
  }
  void changeScore(String enrollmentId,String itemId,num? value,num maximum){
    if(value!=null&&(value<0||value>maximum)){ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('Score must be between 0 and $maximum.')));return;}
    setState((){scores['$enrollmentId:$itemId']=value;saving=true;});debounce?.cancel();debounce=Timer(const Duration(milliseconds:700),()=>save(enrollmentId,itemId,value));
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
  @override void dispose(){debounce?.cancel();super.dispose();}

  @override
  Widget build(BuildContext context) => WorkspaceShell(
    title: 'Quiz Gradebook',
    active: 'Gradebook',
    actions: [OutlinedButton.icon(onPressed:saving?null:editWeights,icon:const Icon(Icons.tune_rounded,size:17),label:const Text('Grading percentages')),const SizedBox(width:10),Container(padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7), decoration: BoxDecoration(color: saving ? SmartGradeColors.mustardSoft : const Color(0xFFEAF4EC), borderRadius: BorderRadius.circular(18)), child: Row(children: [Icon(saving ? Icons.sync : Icons.cloud_done_outlined, size: 15, color: saving ? SmartGradeColors.black : const Color(0xFF347147)), const SizedBox(width: 6), Text(saving ? 'Saving…' : 'All changes saved', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700))]))],
    child: loading ? const Center(child: CircularProgressIndicator()) : Padding(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(runSpacing: 12, spacing: 12, crossAxisAlignment: WrapCrossAlignment.center, children: [
          const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('GRADE ENTRY', style: TextStyle(fontSize: 9, letterSpacing: 1.4, color: SmartGradeColors.red, fontWeight: FontWeight.w800)), SizedBox(height: 5), Text('Prelim · Quizzes', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800))]),
          const SizedBox(width: 18),
          _Pill(icon: Icons.people_outline, text: '${enrollments.length} students'),
          _Pill(icon: Icons.assignment_outlined, text: '${items.length} activities'),
        ]),
        const SizedBox(height: 19),
        Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10), decoration: BoxDecoration(color: Colors.white, border: Border.all(color: SmartGradeColors.line), borderRadius: BorderRadius.circular(9)), child: const Row(children: [Icon(Icons.info_outline_rounded, color: SmartGradeColors.mustard, size: 19), SizedBox(width: 9), Expanded(child: Text('Enter a score, then press Enter. Changes save automatically.', style: TextStyle(fontSize: 11, color: SmartGradeColors.muted))), Icon(Icons.keyboard_alt_outlined, size: 18, color: SmartGradeColors.muted)])),
        const SizedBox(height: 14),
        Expanded(child: items.isEmpty ? const _NoItems() : Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Expanded(child: Container(decoration: BoxDecoration(color: Colors.white, border: Border.all(color: SmartGradeColors.line), borderRadius: BorderRadius.circular(9)), clipBehavior: Clip.antiAlias, child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: SingleChildScrollView(child: Theme(data: Theme.of(context).copyWith(dividerColor: SmartGradeColors.line), child: DataTable(
            headingRowColor: WidgetStateProperty.all(const Color(0xFFF0EEEB)),
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
                ...items.map((item) { final key = '${enrollment['id']}:${item['id']}'; return DataCell(SizedBox(width: 72, child: TextFormField(key: ValueKey('$key:${scores[key]}'), initialValue: scores[key]?.toString() ?? '', textAlign: TextAlign.center, keyboardType: TextInputType.number, onFieldSubmitted: (value) => changeScore(enrollment['id'], item['id'], num.tryParse(value), item['maximum_score']), decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 9))))); }),
                DataCell(Text(earned.toStringAsFixed(0), style: const TextStyle(fontWeight: FontWeight.w800))),
                DataCell(Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5), decoration: BoxDecoration(color: average < 75 ? const Color(0xFFFFE8E8) : const Color(0xFFEAF4EC), borderRadius: BorderRadius.circular(12)), child: Text('${average.toStringAsFixed(1)}%', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: average < 75 ? SmartGradeColors.red : const Color(0xFF347147))))),
              ]);
            }).toList(),
          )))))),
          if (MediaQuery.sizeOf(context).width >= 1180) ...[const SizedBox(width: 14), const SizedBox(width: 245, child: _Insights())],
        ])),
      ]),
    ),
  );
}

class _GradingSettingsResult {
  const _GradingSettingsResult({required this.weights,required this.base});
  final Map<String,double> weights;
  final int base;
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
        DropdownButtonFormField<int>(value:gradingBase,decoration:const InputDecoration(labelText:'Course grading basis'),items:const [DropdownMenuItem(value:0,child:Text('Board course — Base 0')),DropdownMenuItem(value:30,child:Text('Non-board course — Base 30'))],onChanged:(value)=>setState(()=>gradingBase=value??30)),
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
  const _Insights();
  @override Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(18), decoration: BoxDecoration(color: Colors.white, border: Border.all(color: SmartGradeColors.line), borderRadius: BorderRadius.circular(9)), child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('CLASS INSIGHTS', style: TextStyle(fontSize: 10, letterSpacing: 1.1, fontWeight: FontWeight.w800)), SizedBox(height: 18), _Insight(icon: Icons.warning_amber_rounded, color: SmartGradeColors.red, title: 'Missing scores', detail: 'Review blank cells before finalizing.'), Divider(height: 30), _Insight(icon: Icons.lightbulb_outline_rounded, color: SmartGradeColors.mustard, title: 'Quick tip', detail: 'Press Enter after each score to save.'), Spacer(), Text('ACTIONS', style: TextStyle(fontSize: 9, letterSpacing: 1.1, color: SmartGradeColors.muted, fontWeight: FontWeight.w800)), SizedBox(height: 12), ListTile(contentPadding: EdgeInsets.zero, dense: true, leading: Icon(Icons.download_outlined, size: 18), title: Text('Export gradebook', style: TextStyle(fontSize: 11))), ListTile(contentPadding: EdgeInsets.zero, dense: true, leading: Icon(Icons.print_outlined, size: 18), title: Text('Print class record', style: TextStyle(fontSize: 11)))]));
}

class _Insight extends StatelessWidget {
  const _Insight({required this.icon, required this.color, required this.title, required this.detail});
  final IconData icon; final Color color; final String title; final String detail;
  @override Widget build(BuildContext context) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(icon, color: color, size: 20), const SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)), const SizedBox(height: 4), Text(detail, style: const TextStyle(fontSize: 10, height: 1.4, color: SmartGradeColors.muted))]))]);
}

class _NoItems extends StatelessWidget {
  const _NoItems();
  @override Widget build(BuildContext context) => Container(width: double.infinity, decoration: BoxDecoration(color: Colors.white, border: Border.all(color: SmartGradeColors.line), borderRadius: BorderRadius.circular(9)), child: const Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.assignment_outlined, size: 43, color: SmartGradeColors.red), SizedBox(height: 12), Text('No quiz items yet', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)), SizedBox(height: 5), Text('Create assessment items in Supabase to begin entering scores.', style: TextStyle(color: SmartGradeColors.muted))]));
}
