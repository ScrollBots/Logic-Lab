import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:logic_lab/features/boolean_tools/domain/boolean_expression.dart';
import 'package:logic_lab/features/boolean_tools/domain/expression_circuit_converter.dart';
import 'package:logic_lab/features/editor/domain/circuit_models.dart';
import 'package:logic_lab/features/editor/domain/circuit_simulator.dart';

/// A product term (cube) used by the independent reference minimiser.
class _Cube {
  const _Cube(this.coverage, this.literals);

  /// Bit mask of the minterms that the term covers.
  final int coverage;

  /// Number of literals of the term.
  final int literals;
}

/// Reference minimiser that does not use the Quine-McCluskey machinery of the
/// application: it enumerates every possible product term, removes the
/// dominated ones and then searches for the smallest cover by brute force.
class _ReferenceMinimiser {
  const _ReferenceMinimiser(this.minTerms, this.minLiterals);

  final int minTerms;
  final int minLiterals;

  static _ReferenceMinimiser of(Set<int> onSet, int variables) {
    final int mintermCount = 1 << variables;
    final List<_Cube> all = <_Cube>[];
    // Every product term is described by one of three states per variable:
    // absent, present as 0 or present as 1.
    final int states = _pow3(variables);
    for (int state = 0; state < states; state++) {
      int rest = state;
      // The covered minterms are the intersection of the conditions of all
      // literals of the term.
      int coverage = (1 << mintermCount) - 1;
      int literals = 0;
      for (int v = 0; v < variables; v++) {
        final int choice = rest % 3;
        rest ~/= 3;
        if (choice == 0) {
          continue;
        }
        literals++;
        final int bit = 1 << (variables - v - 1);
        int condition = 0;
        for (int m = 0; m < mintermCount; m++) {
          final bool matches = choice == 1 ? m & bit == 0 : m & bit != 0;
          if (matches) {
            condition |= 1 << m;
          }
        }
        coverage &= condition;
      }
      all.add(_Cube(coverage, literals));
    }

    // Only terms whose minterms are all inside the function may be used.
    int onMask = 0;
    for (final int minterm in onSet) {
      onMask |= 1 << minterm;
    }
    final List<_Cube> valid =
        all.where((_Cube cube) => cube.coverage & ~onMask == 0).toList();

    // A term that is covered by a term with fewer literals is never needed.
    final List<_Cube> maximal = <_Cube>[];
    for (final _Cube cube in valid) {
      bool dominated = false;
      for (final _Cube other in valid) {
        if (identical(other, cube)) {
          continue;
        }
        if (other.literals < cube.literals &&
            other.coverage & cube.coverage == cube.coverage) {
          dominated = true;
          break;
        }
      }
      if (!dominated) {
        maximal.add(cube);
      }
    }

    int bestTerms = -1;
    int bestLiterals = -1;
    final int size = maximal.length;
    for (int k = 1; k <= size; k++) {
      int localLiterals = -1;
      for (final List<int> subset in _combinations(size, k)) {
        int coverage = 0;
        int literals = 0;
        for (final int index in subset) {
          coverage |= maximal[index].coverage;
          literals += maximal[index].literals;
        }
        if (coverage & onMask != onMask) {
          continue;
        }
        if (localLiterals < 0 || literals < localLiterals) {
          localLiterals = literals;
        }
      }
      if (localLiterals >= 0) {
        bestTerms = k;
        bestLiterals = localLiterals;
        break;
      }
    }
    return _ReferenceMinimiser(bestTerms, bestLiterals);
  }

  static int _pow3(int exponent) {
    int result = 1;
    for (int i = 0; i < exponent; i++) {
      result *= 3;
    }
    return result;
  }

  static Iterable<List<int>> _combinations(int size, int k) sync* {
    if (k == 0) {
      yield const <int>[];
      return;
    }
    final List<int> current = List<int>.filled(k, 0);
    for (int i = 0; i < k; i++) {
      current[i] = i;
    }
    while (true) {
      yield List<int>.of(current);
      int position = k - 1;
      while (position >= 0 && current[position] == size - k + position) {
        position--;
      }
      if (position < 0) {
        return;
      }
      current[position]++;
      for (int i = position + 1; i < k; i++) {
        current[i] = current[i - 1] + 1;
      }
    }
  }
}

/// Builds a random boolean expression with a fixed seed.
BoolExpr _randomExpression(
  Random random,
  List<String> variables, {
  bool allowConstants = true,
}) {
  BoolExpr build(int depth) {
    if (depth <= 0 || random.nextInt(100) < 35) {
      if (random.nextBool() || !allowConstants) {
        return BoolVariable(variables[random.nextInt(variables.length)]);
      }
      return BoolConstant(random.nextBool());
    }
    final int choice = random.nextInt(10);
    if (choice < 2) {
      return BoolNot(build(depth - 1));
    }
    final BoolExpr left = build(depth - 1);
    final BoolExpr right = build(depth - 1);
    final BooleanOperator operator =
        BooleanOperator.values[random.nextInt(BooleanOperator.values.length)];
    return BoolBinary(operator, left, right);
  }

  return build(3);
}

void main() {
  group('Minimisation is exact for every three variable function', () {
    test('the term and literal counts match an independent brute force', () {
      const int variables = 3;
      const int mintermCount = 1 << variables;
      for (int onMask = 0; onMask < mintermCount; onMask++) {
        final Set<int> onSet = <int>{
          for (int m = 0; m < mintermCount; m++)
            if (onMask & (1 << m) != 0) m,
        };
        final List<String> names = <String>['A', 'B', 'C'];
        final List<String> terms = <String>[];
        for (final int minterm in onSet) {
          final List<String> literals = <String>[];
          for (int v = 0; v < variables; v++) {
            final bool value = minterm & (1 << (variables - v - 1)) != 0;
            literals.add(value ? names[v] : '!${names[v]}');
          }
          terms.add(literals.join(' & '));
        }
        if (terms.isEmpty) {
          terms.add('A & !A');
        }
        final String text = terms.join(' | ');

        final BoolExpr expression = BooleanExpressionParser.parse(text);
        final SimplificationResult result = BooleanSimplifier.simplify(
          expression,
        );
        expect(result.exact, isTrue, reason: 'function $onMask');
        expect(result.verified, isTrue, reason: 'function $onMask');

        if (onSet.isEmpty || onSet.length == mintermCount) {
          // Constant functions are reported separately by the simplifier.
          expect(result.literalCount, 0, reason: 'function $onMask');
          continue;
        }

        final _ReferenceMinimiser reference = _ReferenceMinimiser.of(
          onSet,
          variables,
        );
        expect(
          result.termCount,
          reference.minTerms,
          reason: 'term count for function $onMask ($text)',
        );
        expect(
          result.literalCount,
          reference.minLiterals,
          reason: 'literal count for function $onMask ($text)',
        );
      }
    });
  });

  group('Randomised expressions', () {
    test(
      'the simplified expression stays equivalent for up to four variables',
      () {
        final Random random = Random(20260922);
        final List<List<String>> variableSets = <List<String>>[
          <String>['A', 'B'],
          <String>['A', 'B', 'C'],
          <String>['A', 'B', 'C', 'D'],
        ];
        for (int iteration = 0; iteration < 120; iteration++) {
          final List<String> variables =
              variableSets[iteration % variableSets.length];
          final BoolExpr expression = _randomExpression(random, variables);
          final SimplificationResult result = BooleanSimplifier.simplify(
            expression,
          );
          expect(result.exact, isTrue, reason: 'iteration $iteration');
          expect(result.verified, isTrue, reason: 'iteration $iteration');
          final BoolExpr simplified = result.simplified!;

          final int count = 1 << variables.length;
          for (int assignment = 0; assignment < count; assignment++) {
            final Map<String, bool> values = <String, bool>{};
            for (int i = 0; i < variables.length; i++) {
              values[variables[i]] =
                  assignment & (1 << (variables.length - i - 1)) != 0;
            }
            expect(
              simplified.evaluate(values),
              expression.evaluate(values),
              reason: 'iteration $iteration assignment $assignment',
            );
          }
        }
      },
    );

    test('a converted circuit matches its expression for every assignment', () {
      final Random random = Random(4242);
      final List<String> variables = <String>['A', 'B', 'C'];
      for (int iteration = 0; iteration < 12; iteration++) {
        final BoolExpr expression = _randomExpression(
          random,
          variables,
          allowConstants: false,
        );
        final CircuitGraph graph = ExpressionCircuitConverter.toCircuit(
          expression,
        );
        for (int assignment = 0; assignment < 8; assignment++) {
          final Map<String, bool> values = <String, bool>{};
          for (int i = 0; i < variables.length; i++) {
            values[variables[i]] =
                assignment & (1 << (variables.length - i - 1)) != 0;
          }
          final CircuitGraph instance = graph.copyWith(
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
          final SimulationResult result = CircuitSimulator(instance).evaluate();
          expect(
            result.signalOf(graph.outputs.first.id),
            expression.evaluate(values) ? LogicSignal.high : LogicSignal.low,
            reason: 'iteration $iteration assignment $assignment',
          );
        }
      }
    });
  });

  group('Documented limits', () {
    test('a function with seven variables is never labelled as minimal', () {
      final BoolExpr expression = BooleanExpressionParser.parse(
        'A & B & C & D & E & F & G',
      );
      final SimplificationResult result = BooleanSimplifier.simplify(
        expression,
      );
      expect(result.exact, isFalse);
      expect(result.simplifiedText, isNull);
      expect(result.message, isNotEmpty);
    });

    test('the truth table of a six variable expression has 64 rows', () {
      final BoolExpr expression = BooleanExpressionParser.parse(
        'A | B | C | D | E | F',
      );
      final ExpressionTruthTable table = ExpressionTruthTable.generate(
        expression,
      );
      expect(table.rows.length, 64);
      expect(table.variables.length, 6);
    });
  });
}
