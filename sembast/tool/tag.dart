// ignore_for_file: avoid_print

import 'dart:io';

import 'package:process_run/shell.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:yaml/yaml.dart';

Future main() async {
  var shell = Shell();

  var version = Version.parse(
      (loadYaml(await File('pubspec.yaml').readAsString()) as Map)['version']
          .toString());
  var tag = 'sembast-v$version';
  print('Tag $tag');
  print('Tap anything or CTRL-C: $version');

  await sharedStdIn.first;
  await shell.run('''
git tag $tag
git push origin --follow-tags
''');
  await sharedStdIn.terminate();
}
