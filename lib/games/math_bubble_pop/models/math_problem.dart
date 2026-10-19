import 'dart:math';
import 'math_level.dart';

class MathProblem {
  final String equationString;
  final int correctAnswer;
  final List<int> options;

  const MathProblem({
    required this.equationString,
    required this.correctAnswer,
    required this.options,
  });

  static MathProblem generateForLevel(MathLevel level) {
    final rand = Random();
    String equation;
    int answer;

    switch (level.operationType) {
      case MathOperationType.easyAddition:
        // Sums within 10
        final a = rand.nextInt(5) + 1;
        final b = rand.nextInt(5) + 1;
        answer = a + b;
        equation = '$a + $b = ?';
        break;

      case MathOperationType.mediumAddition:
        // Sums within 20
        final a = rand.nextInt(10) + 2;
        final b = rand.nextInt(9) + 2;
        answer = a + b;
        equation = '$a + $b = ?';
        break;

      case MathOperationType.subtraction:
        // Subtraction within 18
        final b = rand.nextInt(8) + 2;
        answer = rand.nextInt(9) + 1;
        final a = answer + b;
        equation = '$a - $b = ?';
        break;

      case MathOperationType.mixedAddSub:
        final isSub = rand.nextBool();
        if (isSub) {
          final b = rand.nextInt(10) + 3;
          answer = rand.nextInt(12) + 2;
          final a = answer + b;
          equation = '$a - $b = ?';
        } else {
          final a = rand.nextInt(12) + 3;
          final b = rand.nextInt(12) + 3;
          answer = a + b;
          equation = '$a + $b = ?';
        }
        break;

      case MathOperationType.multiplication:
        final a = rand.nextInt(8) + 2; // 2..9
        final b = rand.nextInt(8) + 2; // 2..9
        answer = a * b;
        equation = '$a × $b = ?';
        break;

      case MathOperationType.threeNumbersAndMultiplication:
        // 50% 3-number addition (e.g. 3 + 4 + 5), 50% larger times tables
        if (rand.nextBool()) {
          final a = rand.nextInt(8) + 1;
          final b = rand.nextInt(8) + 1;
          final c = rand.nextInt(8) + 1;
          answer = a + b + c;
          equation = '$a + $b + $c = ?';
        } else {
          final a = rand.nextInt(8) + 4; // 4..11
          final b = rand.nextInt(8) + 3; // 3..10
          answer = a * b;
          equation = '$a × $b = ?';
        }
        break;
    }

    // Generate 3 unique distractors close to the answer
    final optionsSet = <int>{answer};
    while (optionsSet.length < 4) {
      final delta = (rand.nextBool() ? 1 : -1) * (rand.nextInt(4) + 1);
      final distractor = answer + delta;
      if (distractor > 0 && distractor != answer) {
        optionsSet.add(distractor);
      } else {
        optionsSet.add(rand.nextInt(answer + 8) + 1);
      }
    }

    final optionsList = optionsSet.toList()..shuffle(rand);

    return MathProblem(
      equationString: equation,
      correctAnswer: answer,
      options: optionsList,
    );
  }
}
