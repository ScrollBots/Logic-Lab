import 'app_repositories.dart';
import 'sqlite_repositories.dart';

Future<AppRepositories> bootstrapRepositories() async {
  final LogicLabDatabase database = await LogicLabDatabase.open();
  return AppRepositories(
    projects: SqliteProjectRepository(database),
    progress: SqliteLearningProgressRepository(database),
    close: database.close,
  );
}
