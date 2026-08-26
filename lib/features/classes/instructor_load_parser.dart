import 'dart:convert';
import 'dart:typed_data';

import 'package:csv/csv.dart';

class InstructorLoadClass {
  const InstructorLoadClass({required this.subjectCode,required this.subjectTitle,required this.section});
  final String subjectCode;
  final String subjectTitle;
  final String section;

  String get key=>InstructorLoadParser.normalizedKey(subjectCode,section);
}

class InstructorLoadParser {
  static String normalizedKey(String subjectCode,String section){
    String normalize(String value)=>value.trim().toUpperCase().replaceAll(RegExp(r'\s+'),' ');
    final normalizedSection=normalize(section).replaceFirst(RegExp(r'\s+REGULAR$'),'').trim();
    return '${normalize(subjectCode)}|$normalizedSection';
  }

  static List<InstructorLoadClass> parseCsv(String source){
    final rows=const CsvToListConverter(eol:'\n',shouldParseNumbers:false).convert(source.replaceAll('\r\n','\n').replaceAll('\r','\n'));
    if(rows.length<2)throw const FormatException('The CSV must contain a header and at least one class.');
    String headerName(dynamic value)=>'$value'.replaceFirst('\ufeff','').trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'),'_').replaceAll(RegExp(r'^_+|_+$'),'');
    final headerRow=rows.indexWhere((row){
      final names=row.map(headerName).toSet();
      return names.intersection(const {'course_no','course_number','subject_code','course_code'}).isNotEmpty&&names.intersection(const {'section','class_section','class_code'}).isNotEmpty;
    });
    if(headerRow<0)throw const FormatException('Required columns: Course No./Subject Code, Descriptive Title/Subject Title, and Section.');
    final headers=rows[headerRow].map(headerName).toList();
    int column(List<String> names)=>headers.indexWhere(names.contains);
    final codeIndex=column(const ['course_no','course_number','subject_code','course_code','code']);
    final titleIndex=column(const ['descriptive_title','subject_title','course_title','title','subject']);
    final sectionIndex=column(const ['section','class_section','class_code']);
    if(codeIndex<0||titleIndex<0||sectionIndex<0)throw const FormatException('Required columns: Course No./Subject Code, Descriptive Title/Subject Title, and Section.');
    String cell(List<dynamic> row,int index)=>index<row.length?'${row[index]}'.trim():'';
    return _deduplicate(rows.skip(headerRow+1).map((row)=>InstructorLoadClass(subjectCode:cell(row,codeIndex),subjectTitle:cell(row,titleIndex),section:cell(row,sectionIndex))).where((item)=>item.subjectCode.isNotEmpty&&item.subjectTitle.isNotEmpty&&item.section.isNotEmpty));
  }

  static List<InstructorLoadClass> parsePdfText(String source){
    final lines=source.replaceAll('\r','\n').split('\n').map((line)=>line.trim()).where((line)=>line.isNotEmpty).toList();
    final classes=<InstructorLoadClass>[];
    final timeLine=RegExp(r'^\d{1,2}:\d{2}.*?\s+(\d+)\s+(.+)$',caseSensitive:false);
    final detailsLine=RegExp(r'^(.+?\s+\d+)\s+(\d+)\s+(.+?)\s+(Normal|Merged|Honorarium)\s*$',caseSensitive:false);
    var titleStart=0;
    final headerIndex=lines.indexWhere((line)=>line.contains('Time')&&line.contains('Course No.'));
    if(headerIndex>=0)titleStart=headerIndex+1;
    for(var i=titleStart;i<lines.length-1;i++){
      final timeMatch=timeLine.firstMatch(lines[i]);
      if(timeMatch==null)continue;
      final details=detailsLine.firstMatch(lines[i+1]);
      if(details==null)continue;
      final dayIndex=i-1;
      if(dayIndex<titleStart)continue;
      final titleParts=<String>[];
      for(var j=dayIndex-1;j>=titleStart;j--){
        final candidate=lines[j];
        if(RegExp(r'\d{1,2}:\d{2}').hasMatch(candidate)||candidate=='M W'||candidate=='T TH'||candidate=='SUN')break;
        if(candidate.contains('Status:')||candidate.startsWith('Designation:'))break;
        titleParts.insert(0,candidate);
        if(titleParts.length==2)break;
      }
      final title=titleParts.join(' ').trim();
      final code=details.group(1)!.trim();
      var section=timeMatch.group(2)!.trim();
      if(section.endsWith(' Regular'))section=section.substring(0,section.length-8).trim();
      if(title.isNotEmpty&&code.isNotEmpty&&section.isNotEmpty){classes.add(InstructorLoadClass(subjectCode:code,subjectTitle:title,section:section));}
      titleStart=i+2;
      i++;
    }
    final result=_deduplicate(classes);
    if(result.isEmpty)throw const FormatException('No teaching-load rows were detected in the PDF. Use a text-based PDF exported from Crystal Reports.');
    return result;
  }

  static List<InstructorLoadClass> parseRptBytes(Uint8List bytes){
    // Some Crystal files embed saved records as readable strings. Try both
    // common encodings; reports saved without records require a PDF export.
    final latin=latin1.decode(bytes,allowInvalid:true).replaceAll(RegExp(r'[^\x20-\x7E\r\n]+'),'\n');
    final utf16=StringBuffer();
    for(var i=0;i+1<bytes.length;i+=2){final code=bytes[i]|(bytes[i+1]<<8);utf16.write(code>=32&&code<127?String.fromCharCode(code):'\n');}
    for(final candidate in [latin,utf16.toString()]){
      try{final result=parsePdfText(candidate);if(result.isNotEmpty)return result;}catch(_){/* Try the next encoding. */}
    }
    throw const FormatException('This RPT has no readable saved teaching-load records. Open it in Crystal Reports and export it as PDF, then import that PDF.');
  }

  static List<InstructorLoadClass> _deduplicate(Iterable<InstructorLoadClass> rows){
    final unique=<String,InstructorLoadClass>{};
    for(final row in rows){unique.putIfAbsent(row.key,()=>row);}
    return unique.values.toList();
  }
}
