import '../../editor/domain/circuit_models.dart';
import '../../truth_table/domain/truth_table.dart';
import '../domain/boolean_expression.dart';

/// Result of comparing a Boolean expression with a real circuit.
class ExpressionEquivalenceResult {
  const ExpressionEquivalenceResult({
    required this.comparable,
    required this.equivalent,
    required this.message,
    this.mismatches = const <String>[],
  });

  /// False when the expression and the circuit do not have the same inputs
  /// and therefore cannot be compared.
  final bool comparable;

  final bool equivalent;
  final String message;
  final List<String> mismatches;

  static const ExpressionEquivalenceResult
  notComparable = ExpressionEquivalenceResult(
    comparable: false,
    equivalent: false,
    message:
        'تعداد یا نام ورودی‌های عبارت و مدار یکسان نیست، بنابراین هم‌ارزی قابل بررسی نیست.',
  );
}

/// Compares a Boolean expression with a circuit by evaluating both over all
/// input combinations. The circuit side always uses the real simulator, so the
/// comparison reflects the actual behaviour of the stored circuit.
class ExpressionEquivalence {
  const ExpressionEquivalence._();

  static ExpressionEquivalenceResult compare(
    BoolExpr expression,
    CircuitGraph graph, {
    TruthTableLimits limits = const TruthTableLimits(maxInputs: 6, maxRows: 64),
  }) {
    final List<String> expressionVariables =
        expression.collectVariables().toList()..sort();
    final List<CircuitNode> circuitInputs =
        graph.inputs.toList()..sort(
          (CircuitNode a, CircuitNode b) =>
              a.position.x.compareTo(b.position.x),
        );

    if (expressionVariables.length != circuitInputs.length) {
      return ExpressionEquivalenceResult.notComparable;
    }
    for (int i = 0; i < expressionVariables.length; i++) {
      final String expressionName = expressionVariables[i].toUpperCase();
      final String circuitName = circuitInputs[i].label.toUpperCase();
      if (expressionName != circuitName) {
        return ExpressionEquivalenceResult(
          comparable: false,
          equivalent: false,
          message:
              'نام ورودی‌ها یکسان نیست: عبارت «$expressionName» و مدار «$circuitName».',
        );
      }
    }

    final TruthTableResult table;
    try {
      table = const TruthTableGenerator().generate(graph, limits: limits);
    } on TruthTableGenerationException catch (error) {
      return ExpressionEquivalenceResult(
        comparable: false,
        equivalent: false,
        message: error.message,
      );
    }
    if (!table.allRowsValid) {
      return ExpressionEquivalenceResult(
        comparable: false,
        equivalent: false,
        message: 'مدار معتبر نیست، بنابراین هم‌ارزی بررسی نشد.',
      );
    }

    final List<String> mismatches = <String>[];
    for (final TruthTableRow row in table.rows) {
      final Map<String, bool> values = <String, bool>{};
      for (int i = 0; i < circuitInputs.length; i++) {
        values[expressionVariables[i]] =
            row.inputs[circuitInputs[i].id] ?? false;
      }
      final bool expressionValue = expression.evaluate(values);
      final bool? circuitValue = table.rows[row.index].outputs.values.first;
      if (circuitValue == null || circuitValue != expressionValue) {
        final String rowLabel = circuitInputs
            .map(
              (CircuitNode node) =>
                  '${node.label}=${row.inputs[node.id] == true ? 1 : 0}',
            )
            .join('، ');
        mismatches.add(
          '$rowLabel → عبارت ${expressionValue ? '1' : '0'} و مدار '
          '${circuitValue == null ? '؟' : (circuitValue ? '1' : '0')}',
        );
      }
    }

    if (mismatches.isEmpty) {
      return ExpressionEquivalenceResult(
        comparable: true,
        equivalent: true,
        message:
            'عبارت و مدار برای همه ${table.rows.length} ترکیب ورودی رفتار یکسانی دارند.',
      );
    }
    return ExpressionEquivalenceResult(
      comparable: true,
      equivalent: false,
      message: 'عبارت و مدار در ${mismatches.length} ترکیب تفاوت دارند.',
      mismatches: mismatches,
    );
  }
}
