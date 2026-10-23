import '../../features/learn/data/learning_progress_repository.dart';
import '../../features/learn/data/learning_state_repository.dart';
import '../../features/projects/data/project_repository.dart';

class AppRepositories {
  const AppRepositories({
    required this.projects,
    required this.progress,
    required this.learningState,
    this.close,
  });

  final ProjectRepository projects;
  final LearningProgressRepository progress;
  final LearningStateRepository learningState;
  final Future<void> Function()? close;
}
