import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/supabase_client.dart';
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
  Timer? debounce;

  @override void initState(){super.initState();load();}
  Future<void> load() async {
    try {
      final roster=await supabase.from('class_enrollments').select('id, students(id, student_number, last_name, first_name)').eq('class_id',widget.classId).eq('status','active');
      final assessments=await supabase.from('assessment_items').select().eq('class_id',widget.classId).eq('category','quiz').eq('archived',false).order('position');
      final current=await supabase.from('scores').select('enrollment_id, assessment_item_id, raw_score').inFilter('assessment_item_id', List.from(assessments).map((e)=>e['id']).toList());
      for(final row in current){scores['${row['enrollment_id']}:${row['assessment_item_id']}']=row['raw_score'];}
      setState((){enrollments=List.from(roster);items=List.from(assessments);loading=false;});
    } catch(e){if(mounted){setState(()=>loading=false);ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('Gradebook could not be loaded: $e')));}}
  }
  void changeScore(String enrollmentId,String itemId,num? value,num maximum){
    if(value!=null&&(value<0||value>maximum)){ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('Score must be between 0 and $maximum.')));return;}
    setState((){scores['$enrollmentId:$itemId']=value;saving=true;});debounce?.cancel();debounce=Timer(const Duration(milliseconds:700),()=>save(enrollmentId,itemId,value));
  }
  Future<void> save(String enrollmentId,String itemId,num? value) async {await supabase.from('scores').upsert({'enrollment_id':enrollmentId,'assessment_item_id':itemId,'raw_score':value,'status':value==null?'missing':'scored','updated_by':supabase.auth.currentUser!.id},onConflict:'enrollment_id,assessment_item_id');if(mounted)setState(()=>saving=false);}
  @override void dispose(){debounce?.cancel();super.dispose();}

  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('Quiz gradebook'),actions:[Padding(padding:const EdgeInsets.symmetric(horizontal:16),child:Center(child:Row(children:[Icon(saving?Icons.sync:Icons.cloud_done,size:17),const SizedBox(width:6),Text(saving?'Saving…':'All changes saved')])))]),body:loading?const Center(child:CircularProgressIndicator()):Column(children:[
    Container(color:Colors.white,padding:const EdgeInsets.all(14),child:const Row(children:[Text('Prelim',style:TextStyle(fontWeight:FontWeight.bold)),SizedBox(width:20),Text('Quizzes'),Spacer(),Icon(Icons.keyboard_alt_outlined),SizedBox(width:6),Text('Keyboard-friendly score entry')])),
    Expanded(child:items.isEmpty?const Center(child:Text('No quiz items yet. Create assessment items in Supabase or the next UI module.')):SingleChildScrollView(scrollDirection:Axis.horizontal,child:SingleChildScrollView(child:DataTable(columns:[const DataColumn(label:SizedBox(width:210,child:Text('Student'))),...items.map((i)=>DataColumn(label:Text('${i['title']}\nMax ${i['maximum_score']}'))),const DataColumn(label:Text('Total')),const DataColumn(label:Text('Average'))],rows:enrollments.map((e){final student=e['students'], earned=items.fold<double>(0,(sum,i)=>sum+(scores['${e['id']}:${i['id']}']??0).toDouble()),possible=items.fold<double>(0,(sum,i)=>sum+(i['maximum_score'] as num).toDouble());return DataRow(cells:[DataCell(SizedBox(width:210,child:Column(mainAxisAlignment:MainAxisAlignment.center,crossAxisAlignment:CrossAxisAlignment.start,children:[Text('${student['last_name']}, ${student['first_name']}',style:const TextStyle(fontWeight:FontWeight.w600)),Text(student['student_number'],style:Theme.of(context).textTheme.bodySmall)]))),...items.map((i){final key='${e['id']}:${i['id']}';return DataCell(SizedBox(width:70,child:TextFormField(key:ValueKey('$key:${scores[key]}'),initialValue:scores[key]?.toString()??'',textAlign:TextAlign.center,keyboardType:TextInputType.number,onFieldSubmitted:(v)=>changeScore(e['id'],i['id'],num.tryParse(v),i['maximum_score']))));}),DataCell(Text(earned.toStringAsFixed(0))),DataCell(Text('${GradeCalculator.percentage(earned,possible).toStringAsFixed(1)}%'))]);}).toList()))))
  ]));
}
