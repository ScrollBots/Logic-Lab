import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app/bootstrap.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  LicenseRegistry.addLicense(() async* {
    final String vazirmatn = await rootBundle.loadString(
      'assets/fonts/OFL.txt',
    );
    final String jetbrains = await rootBundle.loadString(
      'assets/fonts/JetBrainsMono-OFL.txt',
    );
    yield LicenseEntryWithLineBreaks(<String>['Vazirmatn'], vazirmatn);
    yield LicenseEntryWithLineBreaks(<String>['JetBrains Mono'], jetbrains);
  });

  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  runApp(const LogicLabBootstrap());
}
