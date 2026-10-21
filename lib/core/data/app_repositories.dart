import '../../features/learn/data/learning_progress_repository.dart';
import '../../features/projects/data/project_repository.dart';

class AppRepositories {
  const AppRepositories({
    required this.projects,
    required this.progress,
    this.close,
  });

  final ProjectRepository projects;
  final LearningProgressRepository progress;
  final Future<void> Function()? close;
}
