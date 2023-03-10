library sembast.doc_test;

import 'dart:async';
import 'dart:convert';

import 'package:collection/collection.dart';
// ignore: implementation_imports
import 'package:sembast/src/memory/database_factory_memory.dart';
import 'package:sembast/utils/database_utils.dart';
import 'package:sembast/utils/sembast_import_export.dart';
import 'package:sembast/utils/value_utils.dart';

import 'test_common.dart';

void main() {
  defineTests(memoryDatabaseContext);
}

void defineTests(DatabaseTestContext ctx) {
  var factory = ctx.factory;

  group('doc', () {
    Database? db;

    setUp(() async {});

    tearDown(() async {
      if (db != null) {
        await db!.close();
        db = null;
      }
    });

    test('store', () async {
      db = await setupForTest(ctx, 'doc/store.db');

      // Simple writes
      {
        var store = StoreRef<String, Object>.main();

        await store.record('title').put(db!, 'Simple application');
        await store.record('version').put(db!, 10);
        await store.record('settings').put(db!, {'offline': true});
        var title = await store.record('title').get(db!) as String?;
        var version = await store.record('version').get(db!) as int?;
        var settings = await store.record('settings').get(db!) as Map?;

        await store.record('version').delete(db!);

        unused([title, version, settings]);
      }

      // records
      {
        var store = intMapStoreFactory.store();
        var key = await store.add(db!, {
          'path': {'sub': 'my_value'},
          'with.dots': 'my_other_value'
        });

        var record = (await store.record(key).getSnapshot(db!))!;
        var value = record['path.sub'];
        // value = 'my_value'
        var value2 = record[FieldKey.escape('with.dots')];
        // value2 = 'my_other_value'

        expect(value, 'my_value');
        expect(value2, 'my_other_value');
      }

      {
        await db!.close();
        db = await setupForTest(ctx, 'doc/store.db');

        var store = StoreRef<int, String>.main();
        // Auto incrementation is built-in
        var key1 = await store.add(db!, 'value1');
        var key2 = await store.add(db!, 'value2');
        // key1 = 1, key2 = 2...
        expect([key1, key2], [1, 2]);

        await db!.transaction((txn) async {
          await store.add(txn, 'value1');
          await store.add(txn, 'value2');
        });
      }
      {
        var path = db!.path;
        await db!.close();

        // Migration

        // Open the database with version 1
        db = await factory.openDatabase(path, version: 1);

        // ...

        await db!.close();

        db = await factory.openDatabase(path, version: 2,
            onVersionChanged: (db, oldVersion, newVersion) {
          if (oldVersion == 1) {
            // Perform changes before the database is opened
          }
        });
      }
      {
        // Autogenerated id

        // Use the main store for storing map data with an auto-generated
        // int key
        var store = intMapStoreFactory.store();

        // Add the data and get the key
        var key = await store.add(db!, {'value': 'test'});

        // Retrieve the record
        var record = store.record(key);
        var readMap = (await record.get(db!))!;

        expect(readMap, {'value': 'test'});

        // Update the record
        await record.put(db!, {'other_value': 'test2'}, merge: true);

        readMap = (await record.get(db!))!;

        expect(readMap, {'value': 'test', 'other_value': 'test2'});

        // Track record changes
        var subscription = record.onSnapshot(db!).listen((snapshot) {
          // if snapshot is null, the record is not present or has been
          // deleted

          // ...
        });
        // cancel subscription. Important! not doing this might lead to
        // memory leaks
        unawaited(subscription.cancel());
      }

      {
        // Use the main store for storing key values as String
        var store = StoreRef<String, String>.main();

        // Writing the data
        await store.record('username').put(db!, 'my_username');
        await store.record('url').put(db!, 'my_url');

        // Reading the data
        var url = await store.record('url').get(db!);
        var username = await store.record('username').get(db!);

        await db!.transaction((txn) async {
          url = await store.record('url').get(txn);
          username = await store.record('username').get(txn);
        });

        unused([url, username]);
      }

      {
        // Use the main store, key being an int, value a Map<String, Object?>
        // Lint warnings will warn you if you try to use different types
        var store = intMapStoreFactory.store();
        var key = await store.add(db!, {'offline': true});
        var value = (await store.record(key).get(db!))!;

        // specify a key
        key = 1234;
        await store.record(key).put(db!, {'offline': true});

        unused(value);
      }

      {
        // Use the animals store using Map records with int keys
        var store = intMapStoreFactory.store('animals');

        // Store some objects
        await db!.transaction((txn) async {
          await store.add(txn, {'name': 'fish'});
          await store.add(txn, {'name': 'cat'});
          await store.add(txn, {'name': 'dog'});
        });

        // Look for any animal 'greater than' (alphabetically) 'cat'
        // ordered by name
        var finder = Finder(
            filter: Filter.greaterThan('name', 'cat'),
            sortOrders: [SortOrder('name')]);
        var records = await store.find(db!, finder: finder);

        expect(records.length, 2);
        expect(records[0]['name'], 'dog');
        expect(records[1]['name'], 'fish');

        // Find the first record matching the finder
        var record = (await store.findFirst(db!, finder: finder))!;
        // Get the record id
        var recordId = record.key;
        // Get the record value
        var recordValue = record.value;

        expect(recordId, 3);
        expect(recordValue, {'name': 'dog'});

        // Track query changes
        var query = store.query(finder: finder);
        var subscription = query.onSnapshots(db!).listen((snapshots) {
          // snapshots always contains the list of records matching the query

          // ...
        });
        // cancel subscription. Important! not doing this might lead to
        // memory leaks
        unawaited(subscription.cancel());
      }

      {
        final store = intMapStoreFactory.store('animals');
        await store.drop(db!);

        // Store some objects
        late int key1, key2, key3;
        await db!.transaction((txn) async {
          key1 = await store.add(txn, {'name': 'fish'});
          key2 = await store.add(txn, {'name': 'cat'});
          key3 = await store.add(txn, {'name': 'dog'});
        });

        // Read by key
        var value = (await store.record(key1).get(db!))!;

        // read values are immutable/read-only. If you want to modify it you
        // should clone it first

        // the following will throw an exception
        try {
          value['name'] = 'nice fish';
          throw 'should fail';
        } on StateError catch (_) {}

        // clone the resulting map for modification
        var map = cloneMap(value);
        map['name'] = 'nice fish';

        // existing remain un changed
        expect(await store.record(key1).get(db!), {'name': 'fish'});

        // Read 2 records by key
        var records = await store.records([key2, key3]).get(db!);
        expect(records[0], {'name': 'cat'});
        expect(records[1], {'name': 'dog'});

        {
          // Look for any animal 'greater than' (alphabetically) 'cat'
          // ordered by name
          var finder = Finder(
              filter: Filter.greaterThan('name', 'cat'),
              sortOrders: [SortOrder('name')]);
          var records = await store.find(db!, finder: finder);

          expect(records.length, 2);
          expect(records[0]['name'], 'dog');
          expect(records[1]['name'], 'fish');
        }
        {
          // Look for the last created record
          var finder = Finder(sortOrders: [SortOrder(Field.key, false)]);
          var record = (await store.findFirst(db!, finder: finder))!;

          expect(record['name'], 'dog');
        }
        {
          // Look for the one after `cat`
          var finder = Finder(
              sortOrders: [SortOrder('name', true)],
              start: Boundary(values: ['cat']));
          var record = (await store.findFirst(db!, finder: finder))!;
          expect(record['name'], 'dog');

          record = (await store.findFirst(db!, finder: finder))!;

          // record snapshot are read-only.
          // If you want to modify it you should clone it
          var map = cloneMap(record.value);
          map['name'] = 'nice dog';

          // existing remains unchanged
          record = (await store.findFirst(db!, finder: finder))!;
          expect(record['name'], 'dog');
        }
        {
          // Upsert multiple records
          var records = store.records([key1, key2]);
          var result = await (records.put(
              db!,
              [
                {'value': 'new value for key1'},
                {'value_other': 'new value for key2'}
              ],
              merge: true));
          expect(result, [
            {'name': 'fish', 'value': 'new value for key1'},
            {'name': 'cat', 'value_other': 'new value for key2'}
          ]);
        }
        {
          // Our shop store
          var store = intMapStoreFactory.store('shop');

          await db!.transaction((txn) async {
            await store.add(txn, {'name': 'Lamp', 'price': 10});
            await store.add(txn, {'name': 'Chair', 'price': 10});
            await store.add(txn, {'name': 'Deco', 'price': 5});
            await store.add(txn, {'name': 'Table', 'price': 35});
          });

          // Look for object after Chair 10 (ordered by price then name) so
          // should the the Lamp 10
          var finder = Finder(
              sortOrders: [SortOrder('price'), SortOrder('name')],
              start: Boundary(values: [10, 'Chair']));
          var record = (await store.findFirst(db!, finder: finder))!;
          expect(record['name'], 'Lamp');

          // You can also specify to look after a given record
          finder = Finder(
              sortOrders: [SortOrder('price'), SortOrder('name')],
              start: Boundary(record: record));
          record = (await store.findFirst(db!, finder: finder))!;
          // After the lamp the more expensive one is the Table
          expect(record['name'], 'Table');

          {
            // The test before the doc..

            // Delete all record with a price greater then 10
            var filter = Filter.greaterThan('price', 10);
            var finder = Finder(filter: filter);
            final deleted = await store.delete(db!, finder: finder);
            expect(deleted, 1);

            // Clear all records from the store
            await store.delete(db!);
          }

          {
            // Delete all record with a price greater then 10
            var filter = Filter.greaterThan('price', 10);
            var finder = Finder(filter: filter);
            await store.delete(db!, finder: finder);

            // Clear all records from the store
            await store.delete(db!);
          }
        }
      }
    });

    test('Unique field', () async {
      {
        db = await setupForTest(ctx, 'doc/unique.db');
        var database = db!;
        {
          var db = database;

          // Let's assume a product where the unique key is an integer
          // But you want to have a unique code.
          // (Although as a side note, it is more clever to use the code as the key)
          var store = intMapStoreFactory.store('product');

          // Add some data
          await db.transaction((txn) async {
            await store.add(txn, {'code': '001', 'name': 'Lamp', 'price': 10});
            await store.add(txn, {'code': '002', 'name': 'Chair', 'price': 25});
          });

          /// Either add or modify records with a given 'code'
          Future<void> addOrUpdateProduct(Map<String, Object?> map) async {
            // Check if the record exists before adding or updating it.
            await db.transaction((txn) async {
              // Look of existing record
              var existing = await store
                  .query(
                      finder:
                          Finder(filter: Filter.equals('code', map['code'])))
                  .getSnapshot(txn);
              if (existing == null) {
                // code not found, add
                await store.add(txn, map);
              } else {
                // Update existing
                await existing.ref.update(txn, map);
              }
            });
          }

          // Update existing
          await addOrUpdateProduct(
              {'code': '002', 'name': 'Chair', 'price': 35});
          // Add new
          await addOrUpdateProduct(
              {'code': '003', 'name': 'Table', 'price': 82});

          // Should print:
          // {code: 001, name: Lamp, price: 10}
          // {code: 002, name: Chair, price: 35} - Updated
          // {code: 003, name: Table, price: 82}
          for (var snapshot in await store.query().getSnapshots(db)) {
            print(snapshot.value);
          }
        }
      }
    });
    test('New 1.15 shop_file_format', () async {
      db = await setupForTest(ctx, 'doc/new_1.15_shop_file_format.db');
      {
        // Our shop store sample data
        final store = intMapStoreFactory.store('shop');

        late int lampKey;
        late int chairKey;
        await db!.transaction((txn) async {
          // Add 2 records
          lampKey = await store.add(txn, {'name': 'Lamp', 'price': 10});
          chairKey = await store.add(txn, {'name': 'Chair', 'price': 15});
        });

        // update the price of the lamp record
        await store.record(lampKey).update(db!, {'price': 12});

        // Avoid unused warning that make the code easier-to read
        expect(chairKey, 2);

        var content = await exportDatabase(db!);
        expect(
            content,
            {
              'sembast_export': 1,
              'version': 1,
              'stores': [
                {
                  'name': 'shop',
                  'keys': [1, 2],
                  'values': [
                    {'name': 'Lamp', 'price': 12},
                    {'name': 'Chair', 'price': 15}
                  ]
                }
              ]
            },
            reason: jsonEncode(content));

        // Save as text
        var saved = jsonEncode(content);

        // await db.close();
        var databaseFactory = databaseFactoryMemory;

        // Import the data
        var map = jsonDecode(saved) as Map;
        var importedDb =
            await importDatabase(map, databaseFactory, 'imported.db');

        // Check the lamp price
        expect((await store.record(lampKey).get(importedDb))!['price'], 12);
      }
    });

    test('Write data', () async {
      db = await setupForTest(ctx, 'doc/write_data.db');
      {
        // Our product store.
        final store = intMapStoreFactory.store('product');

        late int lampKey;
        late int chairKey;
        await db!.transaction((txn) async {
          // Add 2 records
          lampKey = await store.add(txn, {'name': 'Lamp', 'price': 10});
          chairKey = await store.add(txn, {'name': 'Chair', 'price': 15});
        });

        expect(await store.record(lampKey).get(db!),
            {'name': 'Lamp', 'price': 10});

        // update the price of the lamp record
        await store.record(lampKey).update(db!, {'price': 12});

        var tableKey = 1000578;
        // Update or create the table product with key 1000578
        await store.record(tableKey).put(db!, {'name': 'Table', 'price': 120});

        // Avoid unused warning that make the code easier-to read
        expect(chairKey, 2);
      }
    });

    test('Preload data', () async {
      var path = dbPathFromName('doc/preload_data.db');
      await factory.deleteDatabase(path);
      {
        // Our shop store sample data
        var store = intMapStoreFactory.store('shop');

        var db = await factory.openDatabase(path, version: 1,
            onVersionChanged: (db, oldVersion, newVersion) async {
          // If the db does not exist, create some data
          if (oldVersion == 0) {
            await store.add(db, {'name': 'Lamp', 'price': 10});
            await store.add(db, {'name': 'Chair', 'price': 15});
          }
        });

        expect(await store.query().getSnapshots(db), hasLength(2));
      }
    });

    test('transaction', () async {
      var path = dbPathFromName('doc/transactions.db');
      await factory.deleteDatabase(path);
      {
        // By default, unless specified a new database has version 1
        // after being opened. While this value seems odd, it actually enforce
        // migration during `onVersionChanged`
        await factory.deleteDatabase(path);
        var db = await factory.openDatabase(path);

        // Let's assume a store with the following products
        var store = intMapStoreFactory.store('product');
        await store.addAll(db, [
          {'name': 'Lamp', 'price': 10, 'id': 'lamp'},
          {'name': 'Chair', 'price': 100, 'id': 'chair'},
          {'name': 'Table', 'price': 250, 'id': 'table'}
        ]);

        var products1 = [
          {'name': 'Lamp', 'price': 10, 'id': 'lamp'},
          {'name': 'Chair', 'price': 100, 'id': 'chair'},
          {'name': 'Table', 'price': 250, 'id': 'table'}
        ];
        //await store.addAll(db, products1);

        Future<List<Map<String, Object?>>> getProductMaps() async {
          var results = await store
              .stream(db)
              .map(((snapshot) => Map<String, Object?>.from(snapshot.value)
                ..['key'] = snapshot.key))
              .toList();
          return results;
        }

        Future printProducts() async {
          print(const JsonEncoder.withIndent('  ')
              .convert(await getProductMaps()));
        }

        Future<List<Map<String, Object?>>> getProductMapsNoKey() async {
          var results = await store
              .stream(db)
              .map(((snapshot) => Map<String, Object?>.from(snapshot.value)))
              .toList();
          return results;
        }

        {
          /// Let's assume you want a function to update all your products

          // Update without using transactions
          Future<void> updateProducts(
              List<Map<String, Object?>> products) async {
            // One transaction is created here
            await store.delete(db);
            // One transaction is created here
            await store.addAll(db, products);
          }

          await updateProducts(
            [
              {'name': 'Lamp', 'price': 17, 'id': 'lamp'},
              {'name': 'Bike', 'price': 999, 'id': 'bike'},
              {'name': 'Chair', 'price': 100, 'id': 'chair'}
            ],
          );

          await updateProducts(products1);
          // await printProducts();
          expect(await getProductMapsNoKey(), products1);
        }

        {
// Update in a transaction
          Future<void> updateProducts(
              List<Map<String, Object?>> products) async {
            await db.transaction((transaction) async {
              await store.delete(transaction);
              await store.addAll(transaction, products);
            });
          }

          await updateProducts(products1);
          // await printProducts();
          expect(await getProductMapsNoKey(), products1);
        }

        {
          await printProducts();

          /// Read products by ids and return a map
          Future<Map<String, RecordSnapshot<int, Map<String, Object?>>>>
              getProductsByIds(DatabaseClient db, List<String> ids) async {
            var snapshots = await store.find(db,
                finder: Finder(
                    filter: Filter.or(
                        ids.map((e) => Filter.equals('id', e)).toList())));
            return <String, RecordSnapshot<int, Map<String, Object?>>>{
              for (var snapshot in snapshots)
                snapshot.value['id']!.toString(): snapshot
            };
          }

          /// Update products
          ///
          /// - Unmodified records remain untouched
          /// - Modified records are updated
          /// - New records are added.
          /// - Missing one are deleted
          Future<void> updateProducts(
              List<Map<String, Object?>> products) async {
            await db.transaction((transaction) async {
              var productIds =
                  products.map((map) => map['id'] as String).toList();
              var map = await getProductsByIds(db, productIds);
              // Watch for deleted item
              var keysToDelete = (await store.findKeys(transaction)).toList();
              for (var product in products) {
                var snapshot = map[product['id'] as String];
                if (snapshot != null) {
                  // The record current key
                  var key = snapshot.key;
                  // Remove from deletion list
                  keysToDelete.remove(key);
                  // Don't update if no change
                  if (const DeepCollectionEquality()
                      .equals(snapshot.value, product)) {
                    // no changes
                    continue;
                  } else {
                    // Update product
                    await store.record(key).put(transaction, product);
                  }
                } else {
                  // Add missing product
                  await store.add(transaction, product);
                }
              }
              // Delete the one not present any more
              await store.records(keysToDelete).delete(transaction);
            });
          }

          var key1 =
              (await getProductsByIds(db, ['lamp'])).entries.first.value.key;
          print(await getProductsByIds(db, ['lamp']));
          print('key1: $key1');

          var products2 = [
            {'name': 'Lamp', 'price': 17, 'id': 'lamp'},
            {'name': 'Bike', 'price': 999, 'id': 'bike'},
            {'name': 'Chair', 'price': 100, 'id': 'chair'},
          ];

          await updateProducts(products2);

          var key2 =
              (await getProductsByIds(db, ['lamp'])).entries.first.value.key;
          await printProducts();
          expect(await getProductMapsNoKey(), [
            {'name': 'Lamp', 'price': 17, 'id': 'lamp'},
            {'name': 'Chair', 'price': 100, 'id': 'chair'},
            {'name': 'Bike', 'price': 999, 'id': 'bike'}
          ]);
          expect(key1, key2);
        }

        await db.close();
      }
    });

    test('migration data', () async {
      var path = dbPathFromName('doc/migration.db');
      await factory.deleteDatabase(path);
      {
        // By default, unless specified a new database has version 1
        // after being opened. While this value seems odd, it actually enforce
        // migration during `onVersionChanged`
        await factory.deleteDatabase(path);
        var db = await factory.openDatabase(path);
        expect(db.version, 1);
        await db.close();

        // It has version 0 if created in onVersionChanged
        await factory.deleteDatabase(path);
        db = await factory.openDatabase(path, version: 1,
            onVersionChanged: (db, oldVersion, newVersion) async {
          expect(oldVersion, 0);
          expect(newVersion, 1);
        });
        expect(db.version, 1);
        await db.close();

        // You can perform basic data migration, by specifying a version
        var store = stringMapStoreFactory.store('product');
        var demoProductRecord1 = store.record('demo_product_1');
        var demoProductRecord2 = store.record('demo_product_2');
        var demoProductRecord3 = store.record('demo_product_3');
        await factory.deleteDatabase(path);
        db = await factory.openDatabase(path, version: 1,
            onVersionChanged: (db, oldVersion, newVersion) async {
          // If the db does not exist, create some data
          if (oldVersion == 0) {
            await demoProductRecord1
                .put(db, {'name': 'Demo product 1', 'price': 10});
            await demoProductRecord2
                .put(db, {'name': 'Demo product 2', 'price': 100});
          }
        });

        Future<List<Map<String, Object?>>> getProductMaps() async {
          var results = await store
              .stream(db)
              .map(((snapshot) => Map<String, Object?>.from(snapshot.value)
                ..['id'] = snapshot.key))
              .toList();
          return results;
        }

        expect(await getProductMaps(), [
          {'name': 'Demo product 1', 'price': 10, 'id': 'demo_product_1'},
          {'name': 'Demo product 2', 'price': 100, 'id': 'demo_product_2'}
        ]);
        await db.close();

        // You can perform update migration, by specifying a new version
        // Here in version 2, we want to update the price of a demo product
        db = await factory.openDatabase(path, version: 2,
            onVersionChanged: (db, oldVersion, newVersion) async {
          if (oldVersion < 2) {
            // Creation
            await demoProductRecord1
                .put(db, {'name': 'Demo product 1', 'price': 15});
          }

          // Creation 0 -> 1
          if (oldVersion < 1) {
            await demoProductRecord2
                .put(db, {'name': 'Demo product 2', 'price': 100});
          } else if (oldVersion < 2) {
            // Migration 1 -> 2
            // no action needed.
          }
        });
        expect(await getProductMaps(), [
          {'name': 'Demo product 1', 'price': 15, 'id': 'demo_product_1'},
          {'name': 'Demo product 2', 'price': 100, 'id': 'demo_product_2'}
        ]);

        // Let's add a new demo product
        await demoProductRecord3
            .put(db, {'name': 'Demo product 3', 'price': 1000});
        await db.close();

        // Let say you want to tag your existing demo product as demo by adding
        // a tag propery
        db = await factory.openDatabase(path, version: 3,
            onVersionChanged: (db, oldVersion, newVersion) async {
          if (oldVersion < 3) {
            // Creation
            await demoProductRecord1.put(
                db, {'name': 'Demo product 1', 'price': 15, 'tag': 'demo'});
          }

          // Creation 0 -> 1
          if (oldVersion < 1) {
            await demoProductRecord2.put(
                db, {'name': 'Demo product 2', 'price': 100, 'tag': 'demo'});
          } else if (oldVersion < 3) {
            // Migration 1 -> 3
            // Add demo tag to all records containing 'demo' in their name
            // no action needed.
            await store.update(db, {'tag': 'demo'},
                finder: Finder(
                    filter: Filter.custom((record) => (record['name'] as String)
                        .toLowerCase()
                        .contains('demo'))));
          }
        });
        expect(await getProductMaps(), [
          {
            'name': 'Demo product 1',
            'price': 15,
            'tag': 'demo',
            'id': 'demo_product_1'
          },
          {
            'name': 'Demo product 2',
            'price': 100,
            'tag': 'demo',
            'id': 'demo_product_2'
          },
          {
            'name': 'Demo product 3',
            'price': 1000,
            'tag': 'demo',
            'id': 'demo_product_3'
          }
        ]);
        await db.close();
      }
    });
    test('database_utils', () async {
      db = await setupForTest(ctx, 'doc/database_utils.db');

      // Get the list of non-empty store names
      var names = getNonEmptyStoreNames(db!);

      expect(names, isEmpty);
    });
    test('record change', () async {
      var database = db = await setupForTest(ctx, 'doc/record_change.db');
      {
        var db = database;

        // Create a 'student' and 'enroll' store. A studen can enroll a course.
        var studentStore = intMapStoreFactory.store('student');
        var enrollStore = intMapStoreFactory.store('enroll');

        // Setup trigger to delete a record in enroll when a student is deleted
        studentStore.addOnChangesListener(db, (transaction, changes) async {
          // For each student deleted, delete the entry in enroll store
          for (var change in changes) {
            // newValue is null for deletion
            if (change.isDelete) {
              // Delete in enroll, use the transaction!
              await enrollStore.delete(transaction,
                  finder:
                      Finder(filter: Filter.equals('student', change.ref.key)));
            }
          }
        });

        // Add some data
        var studentId1 = await studentStore.add(db, {'name': 'Jack'});
        var studentId2 = await studentStore.add(db, {'name': 'Joe'});

        await enrollStore.add(db, {'student': studentId1, 'course': 'Math'});
        await enrollStore.add(db, {'student': studentId2, 'course': 'French'});
        await enrollStore.add(db, {'student': studentId1, 'course': 'French'});

        // The initial data in enroll is
        expect((await enrollStore.find(db)).map((e) => e.value), [
          {'student': 1, 'course': 'Math'},
          {'student': 2, 'course': 'French'},
          {'student': 1, 'course': 'French'}
        ]);

        // Delete the student
        await studentStore.record(studentId1).delete(db);

        // Data has been delete in enrollStore too!
        expect((await enrollStore.find(db)).map((e) => e.value), [
          {'student': 2, 'course': 'French'},
        ]);
      }
    });
    test('map list', () async {
      var store = stringMapStoreFactory.store('product');
      db = await setupForTest(ctx, 'doc/map_list.db');
      await store.addAll(db!, [
        {
          'name': 'Lamp',
          'attributes': [
            {'tag': 'furniture'},
            {'tag': 'plastic'}
          ]
        },
        {
          'name': 'Chair',
          'attributes': [
            {'tag': 'furniture'},
            {'tag': 'wood'}
          ]
        },
      ]);
      var records = await store.find(db!,
          finder:
              Finder(filter: Filter.equals('attributes.@.tag', 'furniture')));
      expect(records.length, 2);
    });
  });
}
