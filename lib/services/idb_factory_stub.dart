import 'package:idb_shim/idb.dart';

IdbFactory get browserDatabaseFactory =>
    throw UnsupportedError('IndexedDB requires a browser');
