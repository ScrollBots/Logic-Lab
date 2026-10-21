import 'package:flutter/foundation.dart';

import '../../editor/domain/circuit_models.dart';
import '../../editor/domain/circuit_validator.dart';
import '../../truth_table/domain/truth_table.dart';
import 'learning_content.dart';

@immutable
class ChallengeResult {
  const ChallengeResult({
    required this.passed,
    required this.title,
    required this.message,
    this.details = const <String>[],
  });

  final bool passed;
  final String title;
  final String message;
  final List<String> details;
}

class ChallengeValidator {
  const ChallengeValidator._();

  /// Validates a user circuit against a challenge by simulating it and
  /// comparing the real truth table with the expected behaviour.
  static ChallengeResult validate(
    CircuitGraph graph,
    LearningChallenge challenge,
  ) {
    final List<String> details = <String>[];

    if (graph.inputs.length != 2) {
      return ChallengeResult(
        passed: false,
        title: 'هنوز کامل نیست',
        message:
            'این چالش به دو ورودی A و B نیاز دارد. اکنون ${graph.inputs.length} ورودی دارید.',
        details: details,
      );
    }
    if (graph.outputs.length != challenge.requiredOutputCount) {
      return ChallengeResult(
        passed: false,
        title: 'خروجی درست تعریف نشده',
        message:
            'این چالش دقیقاً ${challenge.requiredOutputCount} خروجی می‌خواهد. ${graph.outputs.length} خروجی دارید.',
        details: details,
      );
    }

    if (challenge.allowedGates != null) {
      final Set<ComponentType> used =
          graph.nodes
              .where((CircuitNode node) => node.type.isGate)
              .map((CircuitNode node) => node.type)
              .toSet();
      final List<String> disallowed =
          used
              .where(
                (ComponentType type) => !challenge.allowedGates!.contains(type),
              )
              .map((ComponentType type) => type.technicalName)
              .toList();
      if (disallowed.isNotEmpty) {
        return ChallengeResult(
          passed: false,
          title: 'نوع گیت مجاز نیست',
          message:
              'در این چالش فقط ${challenge.allowedGates!.map((ComponentType t) => t.technicalName).join('، ')} مجاز است. '
              'شما از ${disallowed.join('، ')} استفاده کرده‌اید.',
          details: details,
        );
      }
    }

    final SimulationResult report = CircuitValidator.simulate(graph);
    if (!report.isValid) {
      final List<String> problems =
          report.errors
              .map((CircuitProblem problem) => problem.message)
              .toList();
      return ChallengeResult(
        passed: false,
        title: 'مدار هنوز معتبر نیست',
        message: 'پیش از بررسی پاسخ، اتصال‌های مدار را کامل کنید.',
        details: problems,
      );
    }

    final TruthTableResult table = const TruthTableGenerator().generate(
      graph,
      limits: const TruthTableLimits(maxInputs: 2, maxRows: 4),
    );
    for (int index = 0; index < challenge.expectedOutputs.length; index++) {
      final bool? actual = table.rows[index].outputs.values.first;
      final bool expected = challenge.expectedOutputs[index];
      final String rowLabel =
          'A=${index >= 2 ? 1 : 0}, B=${index.isOdd ? 1 : 0}';
      details.add(
        '$rowLabel → ${actual == null ? '؟' : (actual ? '1' : '0')}'
        ' (انتظار: ${expected ? '1' : '0'})',
      );
      if (actual != expected) {
        return ChallengeResult(
          passed: false,
          title: 'خروجی مطابق انتظار نیست',
          message: 'رفتار مدار در حالت $rowLabel با چالش تفاوت دارد.',
          details: details,
        );
      }
    }

    return const ChallengeResult(
      passed: true,
      title: 'درست! آفرین',
      message: 'مدار شما دقیقاً همان رفتاری را دارد که چالش خواسته بود.',
    );
  }
}
