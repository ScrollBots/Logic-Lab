import 'package:flutter_test/flutter_test.dart';
import 'package:logic_lab/features/boolean_tools/domain/boolean_expression.dart';
import 'package:logic_lab/features/boolean_tools/domain/expression_circuit_converter.dart';
import 'package:logic_lab/features/editor/domain/circuit_models.dart';
import 'package:logic_lab/features/editor/domain/circuit_validator.dart';

void main() {
  group('Parser', () {
    test('parses the supported operators', () {
      final BoolExpr expression = BooleanExpressionParser.parse(
        'A & B | !C ^ D',
      );
      expect(expression, isA<BoolExpr>());
      expect(expression.collectVariables().toSet(), <String>{
        'A',
        'B',
        'C',
        'D',
      });
    });

    test('accepts English keywords', () {
      final BoolExpr expression = BooleanExpressionParser.parse(
        'A AND (B OR NOT C)',
      );
      expect(expression.collectVariables().toSet(), <String>{'A', 'B', 'C'});
    });

    test('reports a meaningful error for a missing operand', () {
      expect(
        () => BooleanExpressionParser.parse('A & '),
        throwsA(isA<BooleanParseException>()),
      );
    });

    test('reports a meaningful error for unbalanced parentheses', () {
      expect(
        () => BooleanExpressionParser.parse('(A & B'),
        throwsA(
          isA<BooleanParseException>().having(
            (BooleanParseException error) => error.message,
            'message',
            contains('پرانتز'),
          ),
        ),
      );
    });

    test('rejects unsupported symbols', () {
      expect(
        () => BooleanExpressionParser.parse('A => B'),
        throwsA(isA<BooleanParseException>()),
      );
    });

    test('rejects an empty expression', () {
      expect(
        () => BooleanExpressionParser.parse('   '),
        throwsA(isA<BooleanParseException>()),
      );
    });
  });

  group('Evaluation', () {
    test('evaluates AND, OR, NOT and XOR with the expected results', () {
      final BoolExpr and = BooleanExpressionParser.parse('A & B');
      expect(and.evaluate(<String, bool>{'A': true, 'B': true}), isTrue);
      expect(and.evaluate(<String, bool>{'A': true, 'B': false}), isFalse);

      final BoolExpr or = BooleanExpressionParser.parse('A | B');
      expect(or.evaluate(<String, bool>{'A': false, 'B': true}), isTrue);
      expect(or.evaluate(<String, bool>{'A': false, 'B': false}), isFalse);

      final BoolExpr not = BooleanExpressionParser.parse('!A');
      expect(not.evaluate(<String, bool>{'A': true}), isFalse);

      final BoolExpr xor = BooleanExpressionParser.parse('A ^ B');
      expect(xor.evaluate(<String, bool>{'A': true, 'B': false}), isTrue);
      expect(xor.evaluate(<String, bool>{'A': true, 'B': true}), isFalse);
    });

    test('honours operator precedence (AND before OR)', () {
      final BoolExpr expression = BooleanExpressionParser.parse('A | B & C');
      expect(
        expression.evaluate(<String, bool>{'A': false, 'B': true, 'C': false}),
        isFalse,
      );
      expect(
        expression.evaluate(<String, bool>{'A': false, 'B': true, 'C': true}),
        isTrue,
      );
    });

    test('generates a truth table for every combination', () {
      final BoolExpr expression = BooleanExpressionParser.parse('A & B');
      final ExpressionTruthTable table = ExpressionTruthTable.generate(
        expression,
      );
      expect(table.variables, <String>['A', 'B']);
      expect(table.rows.length, 4);
      expect(
        table.rows.map((ExpressionTruthRow row) => row.output).toList(),
        <bool>[false, false, false, true],
      );
    });
  });

  group('Simplification', () {
    test('simplifies A & A to A and verifies the result', () {
      final BoolExpr expression = BooleanExpressionParser.parse('A & A');
      final SimplificationResult result = BooleanSimplifier.simplify(
        expression,
      );
      expect(result.exact, isTrue);
      expect(result.verified, isTrue);
      expect(result.simplifiedText, 'A');
    });

    test('simplifies a tautology to 1', () {
      final BoolExpr expression = BooleanExpressionParser.parse('A | !A');
      final SimplificationResult result = BooleanSimplifier.simplify(
        expression,
      );
      expect(result.exact, isTrue);
      expect(result.simplifiedText, '1');
    });

    test('simplifies a contradiction to 0', () {
      final BoolExpr expression = BooleanExpressionParser.parse('A & !A');
      final SimplificationResult result = BooleanSimplifier.simplify(
        expression,
      );
      expect(result.exact, isTrue);
      expect(result.simplifiedText, '0');
    });

    test('produces an equivalent and verified expression for XOR', () {
      final BoolExpr expression = BooleanExpressionParser.parse('A ^ B');
      final SimplificationResult result = BooleanSimplifier.simplify(
        expression,
      );
      expect(result.exact, isTrue);
      expect(result.verified, isTrue);
      final BoolExpr simplified = result.simplified!;
      for (final Map<String, bool> values in <Map<String, bool>>[
        <String, bool>{'A': false, 'B': false},
        <String, bool>{'A': false, 'B': true},
        <String, bool>{'A': true, 'B': false},
        <String, bool>{'A': true, 'B': true},
      ]) {
        expect(simplified.evaluate(values), expression.evaluate(values));
      }
    });

    test('refuses to claim a minimum for more than six variables', () {
      final BoolExpr expression = BooleanExpressionParser.parse(
        'A & B & C & D & E & F & G',
      );
      final SimplificationResult result = BooleanSimplifier.simplify(
        expression,
      );
      expect(result.exact, isFalse);
      expect(result.simplifiedText, isNull);
    });
  });

  group('Comparison', () {
    test('equivalent expressions are detected', () {
      final ExpressionComparisonResult result = BooleanExpressionTools.compare(
        BooleanExpressionParser.parse('A & B'),
        BooleanExpressionParser.parse('B & A'),
      );
      expect(result.equivalent, isTrue);
      expect(result.mismatchCount, 0);
    });

    test('different expressions are detected', () {
      final ExpressionComparisonResult result = BooleanExpressionTools.compare(
        BooleanExpressionParser.parse('A & B'),
        BooleanExpressionParser.parse('A | B'),
      );
      expect(result.equivalent, isFalse);
      expect(result.mismatchCount, greaterThan(0));
    });
  });

  group('Circuit conversion', () {
    test('converts an expression into a simulatable circuit', () {
      final BoolExpr expression = BooleanExpressionParser.parse('(A & B) | !C');
      final CircuitGraph graph = ExpressionCircuitConverter.toCircuit(
        expression,
      );
      final SimulationResult report = CircuitValidator.simulate(graph);
      expect(report.isValid, isTrue, reason: report.problems.toString());
      expect(graph.inputs.length, 3);
      expect(graph.outputs.length, 1);

      for (int combination = 0; combination < 8; combination++) {
        final Map<String, bool> values = <String, bool>{
          'A': (combination & 4) != 0,
          'B': (combination & 2) != 0,
          'C': (combination & 1) != 0,
        };
        final CircuitGraph subset = graph.copyWith(
          nodes:
              graph.nodes
                  .map(
                    (CircuitNode node) =>
                        node.type.isInput
                            ? node.copyWith(
                              inputValue: values[node.label] ?? false,
                            )
                            : node,
                  )
                  .toList(),
        );
        final SimulationResult subsetReport = CircuitValidator.simulate(subset);
        expect(
          subsetReport.signalOf(graph.outputs.first.id),
          expression.evaluate(values) ? LogicSignal.high : LogicSignal.low,
          reason: 'combination $combination',
        );
      }
    });

    test('rejects constant expressions', () {
      expect(
        () => ExpressionCircuitConverter.toCircuit(
          BooleanExpressionParser.parse('1'),
        ),
        throwsA(isA<ExpressionConversionException>()),
      );
    });
  });
}
