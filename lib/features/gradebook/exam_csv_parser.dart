import 'package:csv/csv.dart';

class ExamCsvRow {
  const ExamCsvRow({required this.studentName, this.score, required this.status});
  final String studentName;
  final double? score;
  final String status;
}

class ExamCsvData {
  const ExamCsvData({required this.title, required this.maximumScore, required this.rows});
  final String title;
  final double maximumScore;
  final List<ExamCsvRow> rows;
}

class ExamCsvParser {
  static ExamCsvData parse(String source) {
    final records = const CsvToListConverter(shouldParseNumbers: false).convert(source.replaceAll('\r\n', '\n'));
    if (records.length < 2) throw const FormatException('The CSV must contain a header and at least one student.');
    final headers = records.first.map((value) => '$value'.trim().toLowerCase()).toList();
    int column(String name) => headers.indexOf(name);
    final nameIndex = column('student name');
    final scoreIndex = column('score');
    final maximumIndex = column('overall score');
    final titleIndex = column('exam title');
    final statusIndex = column('status');
    if (nameIndex < 0 || scoreIndex < 0 || maximumIndex < 0) {
      throw const FormatException('Required columns: Student Name, Score, and Overall Score.');
    }

    final rows = <ExamCsvRow>[];
    String title = 'Examination';
    double? maximum;
    for (final record in records.skip(1)) {
      String cell(int index) => index >= 0 && index < record.length ? '${record[index]}'.trim() : '';
      final name = cell(nameIndex);
      if (name.isEmpty) continue;
      final rowMaximum = double.tryParse(cell(maximumIndex));
      if (rowMaximum != null && rowMaximum > 0) maximum ??= rowMaximum;
      final rowTitle = cell(titleIndex);
      if (rowTitle.isNotEmpty) title = rowTitle;
      rows.add(ExamCsvRow(studentName: name, score: double.tryParse(cell(scoreIndex)), status: cell(statusIndex)));
    }
    if (rows.isEmpty) throw const FormatException('No student rows were found.');
    if (maximum == null) throw const FormatException('Overall Score must contain a valid maximum score.');
    return ExamCsvData(title: title, maximumScore: maximum, rows: rows);
  }

  static bool nameMatches({required String rosterLastName, required String rosterFirstName, required String csvName}) {
    final parts = csvName.split(',');
    if (parts.length < 2) {
      return _normalize('$rosterLastName $rosterFirstName') == _normalize(csvName);
    }
    final csvLast = _normalize(parts.first);
    final csvFirst = _normalize(parts.sublist(1).join(' '));
    final rosterLast = _normalize(rosterLastName);
    final rosterFirst = _normalize(rosterFirstName);
    if (csvLast != rosterLast || csvFirst.isEmpty || rosterFirst.isEmpty) return false;
    // School exports may omit a middle name. Only accept a complete given-name
    // prefix in either direction; duplicate matches are rejected by the caller.
    return rosterFirst == csvFirst || rosterFirst.startsWith('$csvFirst ') || csvFirst.startsWith('$rosterFirst ');
  }

  static String _normalize(String value) {
    const accents = {'Ñ':'N','Á':'A','À':'A','Â':'A','Ä':'A','É':'E','È':'E','Ê':'E','Ë':'E','Í':'I','Ì':'I','Î':'I','Ï':'I','Ó':'O','Ò':'O','Ô':'O','Ö':'O','Ú':'U','Ù':'U','Û':'U','Ü':'U'};
    var normalized = value.toUpperCase();
    accents.forEach((from, to) => normalized = normalized.replaceAll(from, to));
    return normalized.replaceAll(RegExp(r'[^A-Z0-9]+'), ' ').trim().replaceAll(RegExp(r'\s+'), ' ');
  }
}
