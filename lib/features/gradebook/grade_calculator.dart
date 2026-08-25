class GradeCalculator {
  static double percentage(num earned, num possible) => possible <= 0 ? 0 : earned / possible * 100;
  static double categoryTotal(List<num?> scores, List<num> maximums, {Set<int> excused = const {}, num base = 0}) {
    var earned = 0.0, possible = 0.0;
    for (var i = 0; i < maximums.length; i++) {
      if (excused.contains(i)) continue;
      earned += scores[i] ?? 0;
      possible += maximums[i];
    }
    return transmutedPercentage(earned, possible, base: base);
  }

  static double transmutedPercentage(num earned, num possible, {num base = 0}) {
    if (possible <= 0) return 0;
    final raw = earned / possible * 100;
    return raw * (100 - base) / 100 + base;
  }
  static double finalGrade(Map<double, double> categoryPercentages) => categoryPercentages.entries.fold(0, (sum, e) => sum + e.key * e.value / 100);

  static double weightTotal(Iterable<num> weights) =>
      weights.fold<double>(0, (sum, weight) => sum + weight.toDouble());

  static bool hasValidWeightTotal(Iterable<num> weights) =>
      (weightTotal(weights) - 100).abs() < 0.001;
}
