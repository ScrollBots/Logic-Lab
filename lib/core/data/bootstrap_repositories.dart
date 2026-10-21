import 'app_repositories.dart';
import 'bootstrap_repositories_stub.dart'
    if (dart.library.io) 'bootstrap_repositories_io.dart';

Future<AppRepositories> createAppRepositories() => bootstrapRepositories();
