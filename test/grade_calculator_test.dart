import 'package:flutter_test/flutter_test.dart';
import 'package:smartgrade/features/gradebook/grade_calculator.dart';

void main(){
  test('calculates a total-points category',()=>expect(GradeCalculator.categoryTotal([18,20],[20,25]),closeTo(84.444,0.001)));
  test('excused items are removed from denominator',()=>expect(GradeCalculator.categoryTotal([18,null],[20,25],excused:{1}),90));
  test('weighted final grade is transparent',()=>expect(GradeCalculator.finalGrade({20:90,30:80,50:95}),89.5));
}
