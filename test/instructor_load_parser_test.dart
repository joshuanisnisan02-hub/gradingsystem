import 'package:flutter_test/flutter_test.dart';
import 'package:smartgrade/features/classes/instructor_load_parser.dart';

void main(){
  test('parses instructor load CSV',(){
    const csv='Course No.,Descriptive Title,Section\nCGE 103,Mathematics in the Modern World,CRIM-F1\n';
    final rows=InstructorLoadParser.parseCsv(csv);
    expect(rows.single.subjectCode,'CGE 103');
    expect(rows.single.section,'CRIM-F1');
  });

  test('parses school CSV with instructor metadata before the header',(){
    const csv='"Instructor Subject Load","2026-2027 - 1st Semester"\n"Instructor","JOSHUA E. NISNISAN"\n\n"Time","Day","Course No.","Descriptive Title","Units","Pop\'n","Section","Room"\n"10:15 AM - 11:45 AM","M W","CGE 103","Mathematics in the Modern World","3","39","BSTM-F1","ADB 304"\n"Total Units","3"\n';
    final rows=InstructorLoadParser.parseCsv(csv);
    expect(rows.single.subjectCode,'CGE 103');
    expect(rows.single.subjectTitle,'Mathematics in the Modern World');
    expect(rows.single.section,'BSTM-F1');
  });

  test('duplicate keys ignore case, repeated spaces, and Regular suffix',(){
    expect(InstructorLoadParser.normalizedKey(' cge 103 ','REM-F2 Regular'),InstructorLoadParser.normalizedKey('CGE  103','rem-f2'));
  });

  test('parses raw text exported by Crystal Reports',(){
    const text='Time Day Course No. Descriptive Title UNITS Pop\'n Section Room\nMathematics in the Modern World\nT TH\n7:00:00 AM - 8:30:00 AM 3 CRIM-F1\nCGE 103 45 DSD 303 Normal\nEnterprise Resource Planning\nM W\n12:00:00 PM - 1:30:00 PM 3 IS-S1\nPROFEL 1 35 ADB 302 Normal\n';
    final rows=InstructorLoadParser.parsePdfText(text);
    expect(rows.length,2);
    expect(rows.first.subjectTitle,'Mathematics in the Modern World');
    expect(rows.last.subjectCode,'PROFEL 1');
  });
}
