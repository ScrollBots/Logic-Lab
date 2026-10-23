import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../editor/domain/circuit_models.dart';
import '../../editor/presentation/circuit_editor_screen.dart';
import '../../projects/application/projects_controller.dart';
import '../../projects/domain/circuit_project.dart';
import '../domain/learning_content.dart';

/// Builds the starter canvas for a challenge from its declared pins, so a
/// half adder opens with `S` and `C` outputs instead of a single `Y`.
CircuitGraph challengeStarterGraph(LearningChallenge challenge) {
  final List<CircuitNode> nodes = <CircuitNode>[
    for (int index = 0; index < challenge.inputLabels.length; index++)
      CircuitNode(
        id: 'challenge-in-${challenge.inputLabels[index].toLowerCase()}',
        type: ComponentType.inputPin,
        position: CanvasPoint(150, 170 + index * 150),
        label: challenge.inputLabels[index],
      ),
    for (int index = 0; index < challenge.outputLabels.length; index++)
      CircuitNode(
        id: 'challenge-out-${challenge.outputLabels[index].toLowerCase()}',
        type: ComponentType.outputPin,
        position: CanvasPoint(
          780,
          220 + (index - (challenge.outputLabels.length - 1) / 2) * 150,
        ),
        label: challenge.outputLabels[index],
      ),
  ];
  return CircuitGraph(nodes: nodes);
}

/// Creates a project with the challenge starter circuit and opens the editor
/// in challenge mode. The editor itself validates the circuit with the real
/// simulator and records the result in the learning controller.
///
/// Returns the project id so a retry opens the learner's own work instead of
/// creating a second project.
Future<String?> launchChallenge(
  BuildContext context,
  LearningChallenge challenge,
) async {
  final ProjectsController projects = context.read<ProjectsController>();
  try {
    final CircuitProject project = await projects.createNew(
      graph: challengeStarterGraph(challenge),
      name: 'چالش: ${challenge.title}',
    );
    if (!context.mounted) {
      return project.id;
    }
    await EditorLauncher.open(context, project, challenge: challenge);
    return project.id;
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text('ساخت پروژه چالش انجام نشد: $error')),
        );
    }
    return null;
  }
}

/// Reopens the learner's challenge project with the latest saved graph.
Future<void> reopenChallenge(
  BuildContext context,
  String projectId,
  LearningChallenge challenge,
) async {
  final CircuitProject? project = context.read<ProjectsController>().byId(
    projectId,
  );
  if (project == null) {
    await launchChallenge(context, challenge);
    return;
  }
  await EditorLauncher.open(context, project, challenge: challenge);
}
