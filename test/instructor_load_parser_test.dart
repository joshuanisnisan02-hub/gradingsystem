import 'package:flutter_test/flutter_test.dart';
import 'package:smartgrade/features/classes/instructor_load_parser.dart';

void main(){
  test('parses instructor load CSV',(){
    const csv='Course No.,Descriptive Title,Section\nCGE 103,Mathematics in the Modern World,CRIM-F1\n';
    final rows=InstructorLoadParser.parseCsv(csv);
    expect(rows.single.subjectCode,'CGE 103');
    expect(rows.single.section,'CRIM-F1');
  });

  test('parses raw text exported by Crystal Reports',(){
    const text='Time Day Course No. Descriptive Title UNITS Pop\'n Section Room\nMathematics in the Modern World\nT TH\n7:00:00 AM - 8:30:00 AM 3 CRIM-F1\nCGE 103 45 DSD 303 Normal\nEnterprise Resource Planning\nM W\n12:00:00 PM - 1:30:00 PM 3 IS-S1\nPROFEL 1 35 ADB 302 Normal\n';
    final rows=InstructorLoadParser.parsePdfText(text);
    expect(rows.length,2);
    expect(rows.first.subjectTitle,'Mathematics in the Modern World');
    expect(rows.last.subjectCode,'PROFEL 1');
  });
}
