import 'package:process_run/shell.dart';

Future main() async {
  var shell = Shell();

  await shell.run('''
dart pub run test -p chrome -j 1
''');
}
