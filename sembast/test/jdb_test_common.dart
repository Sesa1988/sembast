import 'package:sembast/src/api/protected/jdb.dart';
import 'package:sembast/src/api/v2/sembast_memory.dart';

import 'test_common.dart';

export 'test_common.dart';

class DatabaseTestContextJdb extends DatabaseTestContext {
  JdbFactory get jdbFactory => (factory as DatabaseFactoryJdb).jdbFactory;
}

DatabaseTestContextJdb get databaseTestContextJdbMemory =>
    DatabaseTestContextJdb()..factory = databaseFactoryMemoryJdb;
