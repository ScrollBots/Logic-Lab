import 'package:flutter/foundation.dart';

import '../../features/learn/data/learning_progress_repository.dart';
import '../../features/learn/data/learning_state_repository.dart';
import '../../features/projects/data/project_repository.dart';
import 'app_repositories.dart';

/// Web is supported only as a development preview. Android is the production
/// target and always uses SQLite; the web build keeps data in memory.
Future<AppRepositories> bootstrapRepositories() async {
  debugPrint('Logic Lab preview: using in-memory repositories.');
  return AppRepositories(
    projects: MemoryProjectRepository(),
    progress: MemoryLearningProgressRepository(),
    learningState: MemoryLearningStateRepository(),
  );
}
