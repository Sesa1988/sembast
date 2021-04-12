library sembast.value_utils_test;

// basically same as the io runner but with extra output
import 'package:sembast/blob.dart';
// ignore_for_file: implementation_imports
import 'package:sembast/src/utils.dart' show compareValue, compareValueType;
import 'package:sembast/timestamp.dart';
import 'package:sembast/utils/value_utils.dart' as utils;

import 'test_common.dart';

void main() {
  group('value_utils', () {
    test('api', () {
      // ignore: unnecessary_statements
      utils.cloneMap;
      // ignore: unnecessary_statements
      utils.cloneList;
      // ignore: unnecessary_statements
      utils.cloneValue;
    });
    test('cloneMap', () {
      var existing = <String, Object?>{
        'test': 1,
        'nested': {
          'sub': 2,
          'list': [
            {'n': 1},
            2
          ]
        }
      };
      var cloned = utils.cloneMap(existing);
      expect(cloned, existing);
      existing['test'] = 3;
      (existing['nested'] as Map)['sub'] = 4;
      (((existing['nested'] as Map)['list'] as List)[0] as Map)['n'] = 5;
      // Make sure chaging the existing does not change the clone
      expect(existing, {
        'test': 3,
        'nested': {
          'sub': 4,
          'list': [
            {'n': 5},
            2
          ]
        }
      });
      expect(cloned, {
        'test': 1,
        'nested': {
          'sub': 2,
          'list': [
            {'n': 1},
            2
          ]
        }
      });
    });
    test('cloneValueList', () {
      var value = [
        [
          [
            {'t': 1}
          ]
        ]
      ];

      dynamic clone;
      void _test() {
        expect(clone, const TypeMatcher<List<Object?>>());
        expect(clone, value);
        expect(identical(clone, value), isFalse);
      }

      clone = utils.cloneValue(value);
      _test();

      clone = utils.cloneList(value);
      _test();
    });
    test('cloneValueMap', () {
      var value = {
        't': [1, 2]
      };
      dynamic clone;
      void _test() {
        expect(clone, const TypeMatcher<Map<String, Object?>>());
        expect(clone, value);
        expect(identical(clone, value), isFalse);
      }

      clone = utils.cloneValue(value);
      _test();
      clone = utils.cloneMap(value);
      _test();
    });
    test('compare', () {
      expect(compareValue('1', '2'), Comparable.compare('1', '2'));
      expect(compareValue(1, 2), Comparable.compare(1, 2));
      expect(compareValue(1, '2'), -1); // converted to string

      // compareValue
      expect(compareValue([0], [0]), 0);
    });
    test('compare int', () {
      expect(compareValue(1, 1), 0);
      expect(compareValue(1, 2), lessThan(0));
      expect(compareValue(2, 1), greaterThan(0));
      expect(compareValue(null, 1), lessThan(0));
      expect(compareValue(1, null), greaterThan(0));
    });
    test('compare bool', () {
      expect(compareValue(true, true), 0);
      expect(compareValue(false, true), lessThan(0));
      expect(compareValue(true, false), greaterThan(0));
      expect(compareValue(null, true), lessThan(0));
      expect(compareValue(false, null), greaterThan(0));
    });
    test('compare value type', () {
      expect(compareValueType(null, true), -1);
      expect(compareValueType(true, null), 1);
      expect(compareValueType(true, 1), -1);
      expect(compareValueType(1, Timestamp(0, 0)), -1);
      expect(compareValueType(Timestamp(0, 0), 1), 1);
      expect(compareValueType(Timestamp(0, 0), 'test'), -1);
      expect(compareValueType('test', Timestamp(0, 0)), 1);
      expect(compareValueType('test', Blob.fromList([1, 2, 3])), -1);
      expect(compareValueType(Blob.fromList([1, 2, 3]), 'test'), 1);
      expect(compareValueType(Blob.fromList([1, 2, 3]), [1, 2, 3]), -1);
      expect(compareValueType('test', [1, 2, 3]), -1);
      expect(compareValueType([1, 2, 3], 'test'), 1);
      expect(compareValueType([1, 2, 3], {}), -1);
      expect(compareValueType({}, [1, 2, 3]), 1);
      expect(compareValueType({}, _Dummy1()), -1);
      expect(compareValueType(_Dummy1(), _Dummy2()), -1);
    });
  });
}

class _Dummy1 {}

class _Dummy2 {}
