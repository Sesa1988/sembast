import 'package:sembast/src/api/record_ref.dart';
import 'package:sembast/src/api/store_ref.dart';

///
/// An immutable reference to multiple records
///
abstract class RecordsRef<K, V> {
  /// Store reference.
  StoreRef<K, V> get store;

  /// Record key, null for new record.
  List<K> get keys;

  /// Record ref at a given index.
  RecordRef<K, V> operator [](int index);

  /// Cast if needed.
  RecordsRef<RK, RV> cast<RK, RV>();
}
