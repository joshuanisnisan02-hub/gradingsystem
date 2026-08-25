import 'package:flutter_test/flutter_test.dart';
import 'package:smartgrade/features/gradebook/exam_csv_parser.dart';

void main() {
  test('parses assessment record and leaves untaken scores blank', () {
    const csv = '#,"Exam Title","Student Id","Student Name",Status,Score,"Overall Score"\n'
        '1,"Prelim Exam",2601160,"DELA PEÑA, CLAREZ ANN","Official Score",49,50\n'
        '2,"Prelim Exam",2601024,"MANIO, ERICA","Untaken Exam",,\n';
    final result = ExamCsvParser.parse(csv);
    expect(result.title, 'Prelim Exam');
    expect(result.maximumScore, 50);
    expect(result.rows.first.score, 49);
    expect(result.rows.last.score, isNull);
  });

  test('matches by name while allowing an omitted middle name', () {
    expect(ExamCsvParser.nameMatches(rosterLastName: 'Dela Peña', rosterFirstName: 'Clarez Ann Dela Cruz', csvName: 'DELA PEÑA, CLAREZ ANN'), isTrue);
    expect(ExamCsvParser.nameMatches(rosterLastName: 'Dela Peña', rosterFirstName: 'Clarez Ann', csvName: 'MANIO, ERICA'), isFalse);
  });
}
