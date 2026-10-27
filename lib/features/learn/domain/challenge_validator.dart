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
  ///
  /// Challenges with several outputs are validated per output label, so a half
  /// adder is checked on both S and C regardless of the order the learner
  /// created the output pins in.
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
    final int expectedOutputCount =
        challenge.expectedOutputsByLabel?.length ??
        challenge.requiredOutputCount;
    if (graph.outputs.length != expectedOutputCount) {
      return ChallengeResult(
        passed: false,
        title: 'خروجی درست تعریف نشده',
        message:
            'این چالش دقیقاً $expectedOutputCount خروجی می‌خواهد. ${graph.outputs.length} خروجی دارید.',
        details: details,
      );
    }

    if (challenge.allowedGates != null) {
      final Set<ComponentType> used = graph.nodes
          .where((CircuitNode node) => node.type.isGate)
          .map((CircuitNode node) => node.type)
          .toSet();
      final List<String> disallowed = used
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
      final List<String> problems = report.errors
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

    final Map<String, List<bool>>? byLabel = challenge.expectedOutputsByLabel;
    final Map<String, int> outputIndexByLabel = <String, int>{};
    if (byLabel != null) {
      for (int index = 0; index < table.outputs.length; index++) {
        outputIndexByLabel[table.outputs[index].label.trim()] = index;
      }
      final List<String> missing = byLabel.keys
          .where((String label) => !outputIndexByLabel.containsKey(label))
          .toList();
      if (missing.isNotEmpty) {
        return ChallengeResult(
          passed: false,
          title: 'نام خروجی‌ها را بررسی کنید',
          message:
              'این چالش خروجی‌هایی با نام ${byLabel.keys.join('، ')} می‌خواهد. '
              'نام خروجی‌ها را در ویرایشگر به همین صورت تغییر دهید.',
          details: details,
        );
      }
    }

    final List<String> mismatchedRows = <String>[];
    for (int index = 0; index < challenge.expectedOutputs.length; index++) {
      final String rowLabel =
          'A=${index >= 2 ? 1 : 0}, B=${index.isOdd ? 1 : 0}';
      final StringBuffer row = StringBuffer('$rowLabel → ');
      bool rowMatches = true;
      if (byLabel != null) {
        final List<String> parts = <String>[];
        for (final MapEntry<String, List<bool>> entry in byLabel.entries) {
          final int outputIndex = outputIndexByLabel[entry.key]!;
          final bool? actual =
              table.rows[index].outputs[_outputKey(table.outputs[outputIndex])];
          final bool expected = index < entry.value.length
              ? entry.value[index]
              : false;
          if (actual != expected) {
            rowMatches = false;
          }
          parts.add(
            '${entry.key}=${actual == null ? '؟' : (actual ? '1' : '0')} '
            '(انتظار: ${expected ? '1' : '0'})',
          );
        }
        row.write(parts.join('، '));
      } else {
        final bool? actual = table.rows[index].outputs.values.first;
        final bool expected = challenge.expectedOutputs[index];
        if (actual != expected) {
          rowMatches = false;
        }
        row.write(
          '${actual == null ? '؟' : (actual ? '1' : '0')} '
          '(انتظار: ${expected ? '1' : '0'})',
        );
      }
      details.add(row.toString());
      if (!rowMatches) {
        mismatchedRows.add(rowLabel);
      }
    }

    if (mismatchedRows.isNotEmpty) {
      return ChallengeResult(
        passed: false,
        title: 'خروجی مطابق انتظار نیست',
        message:
            'رفتار مدار در ${mismatchedRows.length} حالت با چالش تفاوت دارد. '
            'ردیف‌های ${mismatchedRows.join('، ')} را دوباره بررسی کنید.',
        details: details,
      );
    }

    return ChallengeResult(
      passed: true,
      title: 'درست! آفرین',
      message: 'مدار شما دقیقاً همان رفتاری را دارد که چالش خواسته بود.',
      details: details,
    );
  }

  /// Mirrors the key used by [TruthTableResult.toCsv].
  static String _outputKey(TruthTableOutput output) =>
      output.port == 0 ? output.nodeId : '${output.nodeId}#${output.port}';
}
