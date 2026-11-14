import 'package:flutter/material.dart';

import 'app/app.dart';
import 'app/bootstrap.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(zuumRoot(child: const ZuumApp()));
}
