import 'package:flutter_test/flutter_test.dart';
import 'package:smartgrade/features/gradebook/grade_calculator.dart';

void main(){
  test('calculates a total-points category',()=>expect(GradeCalculator.categoryTotal([18,20],[20,25]),closeTo(84.444,0.001)));
  test('excused items are removed from denominator',()=>expect(GradeCalculator.categoryTotal([18,null],[20,25],excused:{1}),90));
  test('accepts category weights totaling 100',()=>expect(GradeCalculator.hasValidWeightTotal([10,20,20,10,40]),isTrue));
  test('rejects category weights not totaling 100',()=>expect(GradeCalculator.hasValidWeightTotal([10,20,20,10,30]),isFalse));
  test('board courses use base 0',()=>expect(GradeCalculator.transmutedPercentage(50,100,base:0),50));
  test('non-board courses use base 30',()=>expect(GradeCalculator.transmutedPercentage(50,100,base:30),65));
  test('weighted final grade is transparent',()=>expect(GradeCalculator.finalGrade({20:90,30:80,50:95}),89.5));
}
