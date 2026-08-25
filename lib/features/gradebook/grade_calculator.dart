class GradeCalculator {
  static double percentage(num earned, num possible) => possible <= 0 ? 0 : earned / possible * 100;
  static double categoryTotal(List<num?> scores, List<num> maximums, {Set<int> excused = const {}}) {
    var earned = 0.0, possible = 0.0;
    for (var i = 0; i < maximums.length; i++) {
      if (excused.contains(i)) continue;
      earned += scores[i] ?? 0;
      possible += maximums[i];
    }
    return percentage(earned, possible);
  }
  static double finalGrade(Map<double, double> categoryPercentages) => categoryPercentages.entries.fold(0, (sum, e) => sum + e.key * e.value / 100);
}
