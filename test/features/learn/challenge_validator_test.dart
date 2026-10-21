import 'package:flutter_test/flutter_test.dart';
import 'package:logic_lab/features/editor/domain/circuit_models.dart';
import 'package:logic_lab/features/editor/domain/circuit_templates.dart';
import 'package:logic_lab/features/editor/domain/circuit_validator.dart';
import 'package:logic_lab/features/learn/domain/challenge_validator.dart';
import 'package:logic_lab/features/learn/domain/learning_content.dart';

void main() {
  group('Challenge validation', () {
    test('an AND circuit solves the AND challenge', () {
      final LearningChallenge challenge = kChallenges.firstWhere(
        (LearningChallenge item) => item.id == 'challenge_and',
      );
      final CircuitGraph graph =
          CircuitTemplates.all
              .firstWhere(
                (CircuitTemplate template) => template.id == 'half_adder',
              )
              .builder();
      // A plain AND circuit for the challenge.
      final CircuitGraph andGraph = CircuitGraph(
        nodes: <CircuitNode>[
          CircuitNode(
            id: 'a',
            type: ComponentType.inputPin,
            position: const CanvasPoint(0, 0),
            label: 'A',
          ),
          CircuitNode(
            id: 'b',
            type: ComponentType.inputPin,
            position: const CanvasPoint(0, 120),
            label: 'B',
          ),
          CircuitNode(
            id: 'g',
            type: ComponentType.andGate,
            position: const CanvasPoint(200, 60),
            label: 'AND',
          ),
          CircuitNode(
            id: 'y',
            type: ComponentType.outputPin,
            position: const CanvasPoint(400, 60),
            label: 'Y',
          ),
        ],
        wires: <CircuitWire>[
          CircuitWire(
            id: 'w1',
            fromNodeId: 'a',
            toNodeId: 'g',
            toInputIndex: 0,
          ),
          CircuitWire(
            id: 'w2',
            fromNodeId: 'b',
            toNodeId: 'g',
            toInputIndex: 1,
          ),
          CircuitWire(
            id: 'w3',
            fromNodeId: 'g',
            toNodeId: 'y',
            toInputIndex: 0,
          ),
        ],
      );
      final ChallengeResult result = ChallengeValidator.validate(
        andGraph,
        challenge,
      );
      expect(result.passed, isTrue, reason: result.message);
      expect(graph.nodes, isNotEmpty);
    });

    test('an OR circuit does not solve the AND challenge', () {
      final LearningChallenge challenge = kChallenges.firstWhere(
        (LearningChallenge item) => item.id == 'challenge_and',
      );
      final CircuitGraph orGraph = CircuitGraph(
        nodes: <CircuitNode>[
          CircuitNode(
            id: 'a',
            type: ComponentType.inputPin,
            position: const CanvasPoint(0, 0),
            label: 'A',
          ),
          CircuitNode(
            id: 'b',
            type: ComponentType.inputPin,
            position: const CanvasPoint(0, 120),
            label: 'B',
          ),
          CircuitNode(
            id: 'g',
            type: ComponentType.orGate,
            position: const CanvasPoint(200, 60),
            label: 'OR',
          ),
          CircuitNode(
            id: 'y',
            type: ComponentType.outputPin,
            position: const CanvasPoint(400, 60),
            label: 'Y',
          ),
        ],
        wires: <CircuitWire>[
          CircuitWire(
            id: 'w1',
            fromNodeId: 'a',
            toNodeId: 'g',
            toInputIndex: 0,
          ),
          CircuitWire(
            id: 'w2',
            fromNodeId: 'b',
            toNodeId: 'g',
            toInputIndex: 1,
          ),
          CircuitWire(
            id: 'w3',
            fromNodeId: 'g',
            toNodeId: 'y',
            toInputIndex: 0,
          ),
        ],
      );
      final ChallengeResult result = ChallengeValidator.validate(
        orGraph,
        challenge,
      );
      expect(result.passed, isFalse);
      // The AND challenge only allows AND gates, so the OR circuit is
      // rejected on the gate type before the behaviour is evaluated.
      expect(result.title, contains('گیت'));
    });

    test('an incomplete circuit is rejected before behaviour is checked', () {
      final LearningChallenge challenge = kChallenges.firstWhere(
        (LearningChallenge item) => item.id == 'challenge_xor',
      );
      final CircuitGraph incomplete = CircuitGraph(
        nodes: <CircuitNode>[
          CircuitNode(
            id: 'a',
            type: ComponentType.inputPin,
            position: const CanvasPoint(0, 0),
            label: 'A',
          ),
          CircuitNode(
            id: 'y',
            type: ComponentType.outputPin,
            position: const CanvasPoint(200, 0),
            label: 'Y',
          ),
        ],
        wires: <CircuitWire>[
          CircuitWire(
            id: 'w1',
            fromNodeId: 'a',
            toNodeId: 'y',
            toInputIndex: 0,
          ),
        ],
      );
      final ChallengeResult result = ChallengeValidator.validate(
        incomplete,
        challenge,
      );
      expect(result.passed, isFalse);
      expect(result.message, contains('ورودی'));
    });

    test('the XOR template satisfies the XOR challenge', () {
      final LearningChallenge challenge = kChallenges.firstWhere(
        (LearningChallenge item) => item.id == 'challenge_xor',
      );
      final CircuitGraph graph = CircuitGraph(
        nodes: <CircuitNode>[
          CircuitNode(
            id: 'a',
            type: ComponentType.inputPin,
            position: const CanvasPoint(0, 0),
            label: 'A',
          ),
          CircuitNode(
            id: 'b',
            type: ComponentType.inputPin,
            position: const CanvasPoint(0, 120),
            label: 'B',
          ),
          CircuitNode(
            id: 'g',
            type: ComponentType.xorGate,
            position: const CanvasPoint(200, 60),
            label: 'XOR',
          ),
          CircuitNode(
            id: 'y',
            type: ComponentType.outputPin,
            position: const CanvasPoint(400, 60),
            label: 'Y',
          ),
        ],
        wires: <CircuitWire>[
          CircuitWire(
            id: 'w1',
            fromNodeId: 'a',
            toNodeId: 'g',
            toInputIndex: 0,
          ),
          CircuitWire(
            id: 'w2',
            fromNodeId: 'b',
            toNodeId: 'g',
            toInputIndex: 1,
          ),
          CircuitWire(
            id: 'w3',
            fromNodeId: 'g',
            toNodeId: 'y',
            toInputIndex: 0,
          ),
        ],
      );
      final ChallengeResult result = ChallengeValidator.validate(
        graph,
        challenge,
      );
      expect(result.passed, isTrue, reason: result.message);
    });
  });

  group('Templates', () {
    test('every template is a valid, simulatable circuit', () {
      for (final CircuitTemplate template in CircuitTemplates.all) {
        final CircuitGraph graph = template.builder();
        final SimulationResult report = CircuitValidator.simulate(graph);
        expect(
          report.isValid,
          isTrue,
          reason:
              '${template.id}: ${report.problems.map((dynamic p) => p.toString()).join(', ')}',
        );
      }
    });

    test('the half adder adds 1 + 1 correctly', () {
      final CircuitGraph graph =
          CircuitTemplates.all
              .firstWhere(
                (CircuitTemplate template) => template.id == 'half_adder',
              )
              .builder();
      final CircuitGraph withInputs = graph.copyWith(
        nodes:
            graph.nodes
                .map(
                  (CircuitNode node) =>
                      node.type.isInput
                          ? node.copyWith(inputValue: true)
                          : node,
                )
                .toList(),
      );
      final SimulationResult report = CircuitValidator.simulate(withInputs);
      final CircuitNode sum = withInputs.outputs.firstWhere(
        (CircuitNode node) => node.label == 'S',
      );
      final CircuitNode carry = withInputs.outputs.firstWhere(
        (CircuitNode node) => node.label == 'C',
      );
      expect(report.signalOf(sum.id), LogicSignal.low);
      expect(report.signalOf(carry.id), LogicSignal.high);
    });
  });
}
