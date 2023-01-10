import 'package:sembast/src/common_import.dart';
import 'package:sembast/src/transaction_impl.dart';

import 'import_common.dart';

/// Transaction record change implementation
class SembastTransactionRecordChange<K extends Key, V extends Value>
    implements RecordChange<K, V> {
  @override
  final RecordSnapshot<K, V>? oldSnapshot;

  @override
  final RecordSnapshot<K, V>? newSnapshot;

  /// Transaction record change implementation.
  SembastTransactionRecordChange(this.oldSnapshot, this.newSnapshot);

  @override
  RecordChange<RK, RV> cast<RK extends Key, RV extends Value>() {
    if (this is RecordChange<RK, RV>) {
      return this as RecordChange<RK, RV>;
    } else {
      return SembastTransactionRecordChange(
          oldSnapshot?.cast<RK, RV>(), newSnapshot?.cast<RK, RV>());
    }
  }
}

/// Store change listener.
class StoreChangesListener<K extends Key, V extends Value> {
  /// The listener
  final TransactionRecordChangeListener<K, V> onChangeListener;

  /// Store change listener.
  StoreChangesListener(this.onChangeListener);

  /// Call on change
  FutureOr<void> onChange(Transaction transaction, List<RecordChange> changes) {
    return onChangeListener(
        transaction,
        changes
            .map<RecordChange<K, V>>((change) => change.cast<K, V>())
            .toList());
  }

  @override
  int get hashCode => onChangeListener.hashCode;

  @override
  bool operator ==(Object other) {
    return (other is StoreChangesListener) &&
        other.onChangeListener == onChangeListener;
  }
}

// ignore: public_member_api_docs
class StoreChangesListeners {
  // ignore: public_member_api_docs
  final onChanges = <StoreChangesListener?>[];

  // ignore: public_member_api_docs
  StoreChangesListeners();

  final _txnOldSnapshot = <RecordSnapshot?>[];
  final _txnNewSnapshot = <RecordSnapshot?>[];

  /// Get the record ref.
  RecordRef getRecordRef(int index) =>
      (_txnNewSnapshot[index]?.ref ?? _txnOldSnapshot[index]?.ref)!;

  /// True if there is a pending change
  bool get hasChanges => _txnNewSnapshot.isNotEmpty;

  /// Get all changes and clear its content
  List<RecordChange> getAndClearChanges() {
    var list = [
      for (var i = 0; i < _txnNewSnapshot.length; i++)
        SembastTransactionRecordChange(_txnOldSnapshot[i], _txnNewSnapshot[i])
    ];
    txnClearChanges();
    return list;
  }

  /// Clear current transaction changes.
  void txnClearChanges() {
    _txnOldSnapshot.clear();
    _txnNewSnapshot.clear();
  }

  /// handle changes
  Future<void> handleChanges(SembastTransaction transaction) async {
    var changes = getAndClearChanges();
    for (var listener in onChanges) {
      var result = listener!.onChange(transaction, changes);
      if (result is Future) {
        await result;
      }
    }
  }
}

/// Database listener.
class DatabaseChangesListener {
  final _stores = <StoreRef, StoreChangesListeners>{};

  /// true if not empty.
  bool get isNotEmpty => _stores.isNotEmpty;

  /// true if empty.
  bool get isEmpty => _stores.isEmpty;

  /// Any pending changes?
  bool get hasChanges {
    for (var listener in _stores.values) {
      if (listener.hasChanges) {
        return true;
      }
    }
    return false;
  }

  /// Get all store changes listener
  Iterable<StoreChangesListeners> get storeChangesListeners => _stores.values;

  /// Add a given change
  void addChange(RecordSnapshot? oldSnapshot, RecordSnapshot? newSnapshot) {
    var store = oldSnapshot?.ref.store ?? newSnapshot?.ref.store;
    var storeChangesListener = _stores[store];
    if (storeChangesListener != null) {
      storeChangesListener._txnOldSnapshot.add(oldSnapshot);
      storeChangesListener._txnNewSnapshot.add(newSnapshot);
    }
  }

  /// true if it has a change listener for this store
  bool hasStoreChangeListener(StoreRef ref) =>
      isNotEmpty && _stores.containsKey(ref);

  /// Clear current transaction changes.
  void txnClearChanges() {
    for (var storeChangesListener in storeChangesListeners) {
      storeChangesListener.txnClearChanges();
    }
  }

  /// Add a store change listener
  void addStoreChangesListener<K extends Key, V extends Value>(
      StoreRef<K, V> store, TransactionRecordChangeListener<K, V> onChanges) {
    var storeChangesListeners = _stores[store];
    if (storeChangesListeners == null) {
      _stores[store] = storeChangesListeners = StoreChangesListeners();
    }
    storeChangesListeners.onChanges.add(StoreChangesListener<K, V>(onChanges));
  }

  /// Add a store change listener
  void removeStoreChangesListener<K extends Key, V extends Value>(
      StoreRef<K, V> store, TransactionRecordChangeListener<K, V> onChanges) {
    var storeChangesListeners = _stores[store];
    if (storeChangesListeners != null) {
      storeChangesListeners.onChanges
          .remove(StoreChangesListener<K, V>(onChanges));
      if (storeChangesListeners.onChanges.isEmpty) {
        _stores.remove(store);
      }
    }
  }

  /// Clear all change listener
  void close() {
    _stores.clear();
  }
}
