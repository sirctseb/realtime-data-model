import 'dart:async';
import 'dart:convert';

import 'package:realtime_data_model/realtime_data_model.dart' as rt;
import 'package:logging_handlers/logging_handlers_shared.dart';
import 'package:unittest/unittest.dart';
import 'package:unittest/html_config.dart';
import 'package:logging/logging.dart';

initializeModel(rt.Model model) {
  group('isInitialized in initializeModel', () {
    test('isInitialized', () {
      expect(model.isInitialized, false);
    });
  });

  model.root['text'] = model.createString('Hello Realtime World!');
  model.root['list'] = model.createList();
  model.root['map'] = model.createMap();
  model.root['book'] = model.create('Book');
}

onFileLoaded(rt.Document doc) {
  group('isInitialized in onFileLoaded', () {
    test('isInitialized', () {
      expect(doc.model.isInitialized, true);
    });
  });

  group('Undo', () {
    test("start undo state", () {
      expect(doc.model.canUndo, false);
      expect(doc.model.canRedo, false);
    });
    test('undo state after change', () {
      doc.model.root['text'].text = 'redid';
      expect(doc.model.canUndo, true);
      expect(doc.model.canRedo, false);
      expect(doc.model.root['text'].text, 'redid');
    });
    test('undo state after undo', () {
      doc.model.undo();
      expect(doc.model.canUndo, false);
      expect(doc.model.canRedo, true);
    });
    test('string state after undo', () {
      expect(doc.model.root['text'].text, 'Hello Realtime World!');
    });
    test('string state after redo and event/model state matching', () {
      StreamSubscription ssUndo;
      ssUndo = doc.model.onUndoRedoStateChanged.listen(expectAsync1((event) {
        // test that event properties match model
        expect(doc.model.canUndo, event.canUndo);
        expect(doc.model.canRedo, event.canRedo);
        // test that undo/redo state is what we expect
        expect(doc.model.canUndo, true);
        expect(doc.model.canRedo, false);
        ssUndo.cancel();
      }));
      doc.model.redo();
      expect(doc.model.root['text'].text, 'redid');
      doc.model.undo();
    });
    test('undo event type', () {
      StreamSubscription ssVR;
      ssVR = doc.model.root['list'].onValuesRemoved.listen((e) {
        expect(e.type, rt.EventType.VALUES_REMOVED);
      });
      StreamSubscription ssVA;
      ssVA = doc.model.root['list'].onValuesAdded.listen((e) {
        expect(e.type, rt.EventType.VALUES_ADDED);
      });
      doc.model.root['list'].push('value');
      doc.model.undo();
      ssVR.cancel();
      ssVA.cancel();
    });
    test('event order during undo', () {
      rt.CollaborativeMap map = doc.model.root['map'];
      rt.CollaborativeList list = doc.model.root['list'];
      map.clear();
      list.clear();
      String orderString = '';
      doc.model.beginCompoundOperation();
      map['key1'] = 'value1';
      list.push('value');
      map['key2'] = 'value2';
      doc.model.endCompoundOperation();
      var ssVC;
      ssVC = map.onValueChanged.listen((e) {
        orderString += 'mapVC${e.property}';
      });
      var ssVR;
      ssVR = list.onValuesRemoved.listen((e) {
        orderString += 'listVR${e.values[0]}';
      });
      doc.model.undo();
      ssVC.cancel();
      ssVR.cancel();
      expect(orderString, 'mapVCkey2listVRvaluemapVCkey1');
    });
    test('event order with event handler', () {
      var map = doc.model.root['map'];
      var list = doc.model.root['list'];
      map.clear();
      list.clear();
      list.push(1);
      var first = true;
      var orderString = '';
      var ssVC;
      ssVC = map.onValueChanged.listen((e) {
        orderString += 'mapVC';
        if(first) {
          list[0] = 2;
          expect(list[0], 2);
          first = false;
        }
      });
      var ssVS;
      ssVS = list.onValuesSet.listen((e) {
        orderString += 'listVS${e.newValues[0]}';
      });
      map['key'] = 'val';
      expect(list[0], 2);
      expect(orderString, 'mapVClistVS2');
      orderString = '';
      doc.model.undo();
      expect(list[0], 1);
      expect(orderString, 'listVS1');
      orderString = '';
      doc.model.redo();
      expect(list[0], 2);
      expect(orderString, 'listVS2');
      ssVC.cancel();
      ssVS.cancel();
    });
    test('isUndo', () {
      var map = doc.model.root['map'];
      map.clear();
      var ssNotUndo = map.onValueChanged.listen((e) {
        expect(e.isUndo, false);
      });
      map['key'] = 'value';
      ssNotUndo.cancel();
      var ssUndo = map.onValueChanged.listen((e) {
        expect(e.isUndo, true);
      });
      doc.model.undo();
      ssUndo.cancel();
    });
    test('isRedo', () {
      var map = doc.model.root['map'];
      map.clear();
      var ssNotRedo = map.onValueChanged.listen((e) {
        expect(e.isRedo, false);
      });
      map['key'] = 'value';
      doc.model.undo();
      ssNotRedo.cancel();
      var ssRedo = map.onValueChanged.listen((e) {
        expect(e.isRedo, true);
      });
      doc.model.redo();
      ssRedo.cancel();
    });
    test('target', () {
      var map = doc.model.root['map'];
      map.clear();
      var ssVC = map.onValueChanged.listen((e) {
        expect(e.target.id, map.id);
      });
      var ssRoot = doc.model.root.onObjectChanged.listen((e) {
        expect(e.events[0].target.id, map.id);
      });
      map['key'] = 'blah';
      ssVC.cancel();
      ssRoot.cancel();
    });
    test('stopPropagation', () {
      var map = doc.model.root['map'];
      map.clear();
      // TODO I think this should be object changed
      var ssVC = map.onObjectChanged.listen((e) {
        expect(e.target.id, map.id);
        e.stopPropagation();
      });
      var ssRoot = doc.model.root.onObjectChanged.listen((e) {
        // TODO how to assert something doesn't happen?
        expect(true, false);
      });
      map['key'] = 'value';
      ssVC.cancel();
      ssRoot.cancel();
    });
    // TODO compoundOperationNames
  });

  group('Compound Operations', () {
    rt.CollaborativeMap map = doc.model.root['map'];
    rt.CollaborativeList list = doc.model.root['list'];
    rt.CollaborativeString string = doc.model.root['text'];
    test('Compoun map additions', () {
      map['compound1'] = 'val1';
      map['compound2'] = 'val2';
      doc.model.undo();
      expect(map.keys.indexOf('compound1'), isNot(-1));
      expect(map.keys.indexOf('compound2'), -1);
      doc.model.undo();
      doc.model.beginCompoundOperation();
      map['compound1'] = 'val1';
      map['compound2'] = 'val2';
      doc.model.endCompoundOperation();
      expect(map['compound1'], 'val1');
      expect(map['compound2'], 'val2');
      doc.model.undo();
      expect(map.keys.indexOf('compound1'), -1);
      expect(map.keys.indexOf('compound2'), -1);
    });
    test('Compound events', () {
      // TODO expect(8);
      // TODO implementing with variable, check if built-in
      int count = 0;
      map.clear();
      var rootOC;
      var mapVC;
      var mapOC;
      rootOC = doc.model.root.onObjectChanged.listen((e) {
        expect(e.type, rt.EventType.OBJECT_CHANGED);
        count++;
      });
      mapVC = map.onValueChanged.listen((e){
        expect(e.type, rt.EventType.VALUE_CHANGED);
        count++;
      });
      mapOC = map.onObjectChanged.listen((e) {
        expect(e.type, rt.EventType.OBJECT_CHANGED);
        count++;
      });
      doc.model.beginCompoundOperation();
      map['compound1'] = 'val1';
      map['compound2'] = 'val2';
      doc.model.endCompoundOperation();
      doc.model.undo();
      rootOC.cancel();
      mapVC.cancel();
      mapOC.cancel();
      expect(count, 8);
    });
    test('Commpound list, string, map', () {
      map.clear();
      map['key1'] = 'val1';
      list.clear();
      list.push('val1');
      string.text = 'val1';
      doc.model.beginCompoundOperation();
      map.remove('key1');
      map['key2'] = 'val2';
      list.remove(0);
      list.push('val2');
      string.text = 'val2';
      doc.model.endCompoundOperation();
      expect(map.keys.indexOf('key1'), -1);
      expect(map['key2'], 'val2');
      expect(list.indexOf('val1'), -1);
      expect(list[0], 'val2');
      expect(string.text, 'val2');
      doc.model.undo();
      expect(map.keys.indexOf('key2'), -1);
      expect(map['key1'], 'val1');
      expect(list.indexOf('val2'), -1);
      expect(list[0], 'val1');
      expect(string.text, 'val1');
    });
    test('list, map events', () {
      // TODO expect(4)
      int count = 0;
      map.clear();
      list.clear();
      doc.model.beginCompoundOperation();
      map['key1'] = 'val1';
      map['key2'] = 'val2';
      list.push('val1');
      doc.model.endCompoundOperation();
      var rootOC;
      var listOC;
      var mapOC;
      rootOC = doc.model.root.onObjectChanged.listen((e) {
        expect(e.type, rt.EventType.OBJECT_CHANGED);
        count++;
      });
      mapOC = map.onObjectChanged.listen((e) {
        expect(e.type, rt.EventType.OBJECT_CHANGED);
        count++;
      });
      listOC = list.onObjectChanged.listen((e) {
        expect(e.type, rt.EventType.OBJECT_CHANGED);
        count++;
      });
      doc.model.undo();
      expect(count, 4);
      rootOC.cancel();
      listOC.cancel();
      mapOC.cancel();
    });
    test('nested compound operations', () {
      map.clear();
      map['key'] = 0;
      list.clear();
      list.push(0);
      string.text = '0';
      doc.model.beginCompoundOperation();
      map['key'] = 1;
      doc.model.beginCompoundOperation();
      list[0] = 1;
      doc.model.endCompoundOperation();
      string.text = '1';
      doc.model.endCompoundOperation();
      expect(map['key'], 1);
      expect(list[0], 1);
      expect(string.text, '1');
      doc.model.undo();
      expect(map['key'], 0);
      expect(list[0], 0);
      expect(string.text, '0');
    });
    test('unmatched endCompoundOperation', () {
      expect(() => doc.model.endCompoundOperation(), throwsA(predicate((e) => e.message == 'Not in a compound operation.')));
    });
    test('Empty Compound Operation', () {
      var count = 0;

      string.append('append');
      var ssDeleted = string.onTextDeleted.listen((event) {
        count++;
        expect(event.text, 'append');
      });

      doc.model.beginCompoundOperation();
      doc.model.endCompoundOperation();

      doc.model.undo();

      ssDeleted.cancel();

      expect(count, 1);
    });
    test('Compound Operation Names', () {
      var count = 0;
      doc.model.beginCompoundOperation('outer');
      doc.model.beginCompoundOperation('inner');
      var ssAdd = list.onValuesAdded.listen((e) {
        expect(e.compoundOperationNames, ['outer', 'inner']);
        count++;
      });
      var ssObj = list.onObjectChanged.listen((e) {
        expect(e.compoundOperationNames, ['outer', 'inner']);
        count++;
      });
      list.push(0);
      doc.model.endCompoundOperation();
      doc.model.endCompoundOperation();
      ssAdd.cancel();
      ssObj.cancel();
      expect(count, 2);
    });
  });

  group('CollaborativeString', () {
    var string = doc.model.root['text'];
    setUp((){
      string.text = 'unittest';
    });
    test('type', () {
      expect(string.type, rt.CollaborativeTypes.COLLABORATIVE_STRING.value);
    });
    test('get length', () {
      expect(string.length, 8);
    });
    test('append(String text)', () {
      string.append(' append');
      expect(string.text, 'unittest append');
    });
    test('get text', () {
      expect(string.text, 'unittest');
    });
    test('insertString(int index, String text)', () {
      string.insertString(4, ' append ');
      expect(string.text, 'unit append test');
    });
    test('removeRange(int startIndex, int endIndex)', () {
      string.removeRange(4, 6);
      expect(string.text, 'unitst');
    });
    test('set text(String text)', () {
      string.text = 'newValue';
      expect(string.text, 'newValue');
    });
    test('onTextInserted', () {
      StreamSubscription ssInsert;
      StreamSubscription ssDelete;
      ssInsert = string.onTextInserted.listen(expectAsync1((rt.TextInsertedEvent e) {
        expect(e.index, 4);
        expect(e.text, ' append ');
        ssInsert.cancel();
        ssDelete.cancel();
      }));
      ssDelete = string.onTextDeleted.listen(expectAsync1((rt.TextDeletedEvent e) {
        fail("delete should not be call");
      }, count: 0));
      string.insertString(4, ' append ');
    });
    test('onTextDeleted', () {
      StreamSubscription ssInsert;
      StreamSubscription ssDelete;
      ssInsert = string.onTextInserted.listen(expectAsync1((rt.TextInsertedEvent e) {
        fail("insert should not be call");
      }, count: 0));
      ssDelete = string.onTextDeleted.listen(expectAsync1((rt.TextDeletedEvent e) {
        expect(e.index, 4);
        expect(e.text, 'te');
        ssInsert.cancel();
        ssDelete.cancel();
      }));
      string.removeRange(4, 6);
    });
    test('string diff', () {
      var events = [];
      string.text = 'Hello Realtime World!';
      var ssOC;
      ssOC = string.onObjectChanged.listen((e) {
        events.addAll(e.events.map((event) {
          return {'type': event.type, 'text': event.text, 'index': event.index};
        }));
      });
      string.text = 'redid';
      ssOC.cancel();
      var jsonString = '[{"type":"text_deleted","text":"Hello R","index":0},{"type":"text_inserted","text":"r","index":0},{"type":"text_deleted","text":"alt","index":2},{"type":"text_inserted","text":"d","index":2},{"type":"text_deleted","text":"me World!","index":4},{"type":"text_inserted","text":"d","index":4}]';
      expect(events, equals(JSON.decode(jsonString)));
    });
    test('toString', () {
      string.text = 'stringValue';
      expect(string.toString(), 'stringValue');
    });
  });

  group('CollaborativeList', () {
    var list = doc.model.root['list'];
    setUp((){
      list.clear();
      list.push('s1');
    });
    test('type', () {
      expect(list.type, rt.CollaborativeTypes.COLLABORATIVE_LIST.value);
    });
    test('get length', () {
      expect(list.length, 1);
    });
    test('set length', () {
      list.push('s2');
      expect(list.length, 2);
      list.length = 1;
      expect(list.length, 1);
      expect(() {list.length = 3;}, throwsA(predicate((e) => e.message == 'Cannot set the list length to be greater than the current value.')));
    });
    test('asArray()', () {
      var array = [1,2,3,4];
      var l = doc.model.createList(array);
      expect(array, l.asArray());
    });
    test('clear()', () {
      list.clear();
      expect(list.length, 0);
    });
    test('operator [](int index)', () {
      expect(list[0], 's1');
      expect(() => list[-1], throwsA(predicate((e) => e.message == 'Index: -1, Size: 1')));
      expect(() => list[1], throwsA(predicate((e) => e.message == 'Index: 1, Size: 1')));
    });
    test('operator []=(int index, E value)', () {
      list[0] = 'new s1';
      expect(list[0], 'new s1');
    });
    test('indexOf(value, opt_comparatorFn)', () {
      list.clear();
      list.pushAll([1,2,3]);
      expect(list.indexOf(2), 1);
      expect(list.indexOf(4), -1);
    });
    test('insert(int index, E value)', () {
      list.insert(0, 's0');
      expect(list.length, 2);
      expect(list[0], 's0');
      expect(list[1], 's1');
    });
    test('insertAll(int index, values)', () {
      list.clear();
      list.pushAll([0,3]);
      list.insertAll(1, [1,2]);
      expect(list.asArray(), [0,1,2,3]);
    });
    test('lastIndexOf(value, opt_comparatorFn)', () {
      list.clear();
      list.pushAll([1,2,3]);
      expect(list.lastIndexOf(2), 1);
      expect(list.lastIndexOf(0), -1);
    });
    test('move(index, destinationIndex)', () {
      // TODO expect(15);
      list.clear();
      list.pushAll([0,1,2]);
      var ssSet = list.onValuesSet.listen(expectAsync1((rt.ValuesSetEvent e) {
        fail('Set event should not occur');
      }, count: 0));
      var iter = 0;
      var ssAdd = list.onValuesAdded.listen(expectAsync1((rt.ValuesAddedEvent e) {
        expect(e.values, [0]);
        expect(e.index, [0,1,2][iter]);
        expect(e.movedFromIndex, 0);
        iter++;
      }, count: 3));
      var ssRemove = list.onValuesRemoved.listen(expectAsync1((rt.ValuesRemovedEvent e) {
        expect(e.values, [0]);
        expect(e.index, 0);
      }, count: 3));
      // TODO rt implementation hangs on index = -1
      // list.move(-1, 0);
      // throws(() => list.move(-1, 0));
      list.move(0,0);
      expect(list.asArray(), [0,1,2]);
      list.move(0,1);
      expect(list.asArray(), [0,1,2]);
      list.move(0,2);
      expect(list.asArray(), [1,0,2]);
      ssSet.cancel();
      ssAdd.cancel();
      ssRemove.cancel();
    });
    test('moveToList(index, destination, destinationIndex)', () {
      list.clear();
      list.pushAll([0,1,2]);
      var list2 = doc.model.createList([0,1,2]);
      doc.model.root['list2'] = list2;
      var toList = list;
      var ssList = list.onValuesRemoved.listen((e) {
        expect(e.movedToList.id, toList.id);
      });
      list.moveToList(0, list, 2);
      expect(list.asArray(), [1,0,2]);
      toList = list2;
      list.moveToList(0, list2, 2);
      ssList.cancel();
      expect(list2.asArray(), [0,1,1,2]);
      doc.model.root.remove('list2');
    });
    test('push(E value)', () {
      expect(list.push('s2'), 2);
      expect(list.length, 2);
      expect(list[0], 's1');
      expect(list[1], 's2');
    });
    test('pushAll(values)', () {
      list.clear();
      list.pushAll([0,1,2]);
      expect(list.asArray(), [0,1,2]);
    });
    test('remove(int index)', () {
      list.remove(0);
      expect(list.length, 0);
    });
    test('removeRange(startIndex, endIndex)', () {
      list.clear();
      list.pushAll([0,1,2,3]);
      list.removeRange(1,3);
      expect(list.asArray(), [0,3]);
    });
    test('removeValue(value)', () {
      list.clear();
      list.pushAll([1,2,3]);
      list.removeValue(2);
      expect(list.asArray(), [1,3]);
    });
    test('replaceRange(index, values)', () {
      // TODO expect(6);
      list.clear();
      list.pushAll([0,1,2,3]);
      var ssAdd = list.onValuesAdded.listen(expectAsync1((rt.ValuesAddedEvent e) {
        // TODO is there a simple ok test?
        expect(true, true);
      }, count: 0));
      var ssRemove = list.onValuesRemoved.listen(expectAsync1((rt.ValuesRemovedEvent e) {
        expect(true, true);
      }, count: 0));
      var ssSet = list.onValuesSet.listen(expectAsync1((rt.ValuesSetEvent e) {
        expect(e.newValues, [4,5]);
        expect(e.oldValues, [1,2]);
      }, count: 1));
      list.replaceRange(1, [4,5]);
      expect(list.asArray(), [0,4,5,3]);
      expect(() => list.replaceRange(3, [6,7]), throws);
      expect(() => list.replaceRange(-1, [1,2]), throws);
      ssAdd.cancel();
      ssRemove.cancel();
      ssSet.cancel();
    });
    test('onValuesAdded', () {
      StreamSubscription ss;
      ss = list.onValuesAdded.listen(expectAsync1((rt.ValuesAddedEvent e) {
        expect(e.index, 1);
        expect(e.values, ['s2']);
        ss.cancel();
      }));
      list.push('s2');
    });
    test('onValuesRemoved', () {
      StreamSubscription ss;
      ss = list.onValuesRemoved.listen(expectAsync1((rt.ValuesRemovedEvent e) {
        expect(e.index, 0);
        expect(e.values, ['s1']);
        ss.cancel();
      }));
      list.clear();
    });
    test('onValuesSet', () {
      StreamSubscription ss;
      ss = list.onValuesSet.listen(expectAsync1((rt.ValuesSetEvent e) {
        expect(e.index, 0);
        expect(e.oldValues, ['s1']);
        expect(e.newValues, ['s2']);
        ss.cancel();
      }));
      list[0] = 's2';
    });
    test('propogation', () {
      var ss;
      ss = doc.model.root.onObjectChanged.listen((e) {
        expect(e.events[0].type, rt.EventType.VALUES_ADDED);
      });
      list.push('value');
      ss.cancel();
    });
    test('same value', () {
      // expect(4);
      var ssVS;
      ssVS = list.onValuesSet.listen((e) {
        expect(e.type, rt.EventType.VALUES_SET);
        expect(e.newValues[0], 1);
      });
      list[0] = 1;
      list[0] = 1;
      ssVS.cancel();
    });
    test('set out of range', () {
      expect(() {list.set(-1,1);}, throws);
    });
    test('toString', () {
      list.clear();
      list.push(1);
      list.push([1,2,3]);
      list.push('string');
      list.push({'string': 1});
      list.push(doc.model.createString('collabString'));
      list.push(doc.model.createList([1,2,3]));
      list.push(doc.model.createMap({'string': 1}));
      expect(list.toString(), "[[JsonValue 1], [JsonValue [1,2,3]], [JsonValue \"string\"], [JsonValue {\"string\":1}], collabString, [[JsonValue 1], [JsonValue 2], [JsonValue 3]], {string: [JsonValue 1]}]");
    });
  });

  group('CollaborativeMap', () {
    var map = doc.model.root['map'];
    setUp(() {
      map.clear();
      map['key1'] = 4;
    });
    test('type', () {
      expect(map.type, rt.CollaborativeTypes.COLLABORATIVE_MAP.value);
    });
    test('absent key', () {
      expect(map['absent'], null);
    });
    test('null value', () {
      expect(map['nullkey'], null);
      expect(map.containsKey('nullkey'), false);
      map['nullkey'] = null;
      expect(map['nullkey'], null);
      expect(map.containsKey('nullkey'), false);
      expect(map.keys.indexOf('nullkey'), -1);
      map['nullkey'] = 'value';
      doc.model.undo();
      expect(map.containsKey('nullkey'), false);
      expect(map.keys.indexOf('nullkey'), -1);
    });
    test('size with null', () {
      expect(map.size, 1);
      map['nullkey'] = null;
      expect(map.size, 1);
    });
    test('operator [](String key)', () {
      expect(map['key1'], 4);
      expect(map.length, 1);
    });
    test('operator []=(String key, E value)', () {
      map['key2'] = 5;
      expect(map['key2'], 5);
    });
    test('remove', () {
      map.remove('key1');
      expect(map.length, 0);
      expect(map['key1'], null);
    });
    test('clear', () {
      map.clear();
      expect(map.length, 0);
    });
    test('keys', () {
      map.clear();
      map['a'] = 'a';
      map['b'] = 'b';
      map['c'] = 'c';
      map['d'] = 'd';
      map['e'] = 'e';
      expect(map.keys, ['e', 'a', 'c', 'd', 'b']);
    });
    test('addAll', () {
      map.addAll({
        'key2': 5,
        'key3': 6
      });
      expect(map.length, 3);
      expect(map['key2'], 5);
      expect(map['key3'], 6);
    });
    test('onValueChanged', () {
      StreamSubscription ssChanged;
      ssChanged = map.onValueChanged.listen(expectAsync1((rt.ValueChangedEvent e) {
        expect(e.property, 'key1');
        expect(e.newValue, 5);
        expect(e.oldValue, 4);
        ssChanged.cancel();
      }));
      map['key1'] = 5;
    });
    test('onValueChanged add', () {
      StreamSubscription ssAdd;
      ssAdd = map.onValueChanged.listen(expectAsync1((rt.ValueChangedEvent e) {
        expect(e.property, 'prop');
        expect(e.newValue, 'newVal');
        expect(e.oldValue, null);
        ssAdd.cancel();
      }));
      map['prop'] = 'newVal';
    });
    test('onValueChanged remove', () {
      StreamSubscription ssRemove;
      ssRemove = map.onValueChanged.listen(expectAsync1((rt.ValueChangedEvent e) {
        expect(e.property, 'key1');
        expect(e.oldValue, 4);
        expect(e.newValue, null);
        ssRemove.cancel();
      }));
      map.remove('key1');
    });
    test('onValueChanged clear', () {
      map['key2'] = 'val2';
      StreamSubscription ssClear;
      ssClear = map.onValueChanged.listen(expectAsync1((rt.ValueChangedEvent e) {
        expect(e.newValue, null);
      }, count: 2));
      map.clear();
      ssClear.cancel();
    });
    test('map length on null assignment', () {
      expect(map.length, 1);
      map['key1'] = null;
      expect(map.length, 0);
    });
    test('set return value', () {
      map.clear();
      map['key'] = 'val';
      expect(map.set('key', 'val2'), 'val');
    });
    test('delete return value', () {
      map['key'] = 'val';
      expect(map.remove('key'), 'val');
    });
    test('same value', () {
      // TODO expect(3)
      map.clear();
      map['key1'] = 'val1';
      var ssVC;
      ssVC = map.onValueChanged.listen((e) {
        fail('Value changed handler should not be called');
        expect(e.newValue, 'val1');
        expect(e.oldValue, 'val1');
      });
      expect(map.set('key1', 'val1'), 'val1');
      ssVC.cancel();
    });
    test('undo to absent', () {
      map.clear();
      expect(map.containsKey('key1'), false);
      expect(map.keys.indexOf('key1'), -1);
      map['key1'] = 'val1';
      expect(map.containsKey('key1'), true);
      expect(map.keys.indexOf('key1'), isNot(-1));
      doc.model.undo();
      expect(map.containsKey('key1'), false);
      expect(map.keys.indexOf('key1'), -1);
    });
    test('toString', () {
      map.clear();
      map.set('string', 1);
      expect(map.toString(), '{string: [JsonValue 1]}');
    });
  });

  group('RealtimeIndexReference', () {
    rt.CollaborativeString string = doc.model.root['text'];
    rt.CollaborativeList list = doc.model.root['list'];
    test('RealtimeString Reference Value', () {
      string.text = "aaaaaaaaaa";
      rt.IndexReference ref = string.registerReference(5, false);
      expect(ref.index, 5);
      string.insertString(2, "x");
      expect(ref.index, 6);
      doc.model.undo();
      expect(ref.index, 5);
      string.insertString(8, "x");
      expect(ref.index, 5);
      string.removeRange(0, 2);
      expect(ref.index, 3);
      string.removeRange(2, 4);
      expect(ref.index, 2);
    });
    test('RealtimeString Delete Reference', () {
      rt.IndexReference ref = string.registerReference(5, true);
      expect(ref.index, 5);
      string.removeRange(4, 6);
      expect(ref.index, -1);
    });
    test('RealtimeList Reference Value', () {
      list.clear();
      list.pushAll([1,2,3,4,5,6,7,8,9,10,11,12]);
      rt.IndexReference ref = list.registerReference(5, false);
      expect(ref.index, 5);
      list.insert(2, 9);
      expect(ref.index, 6);
      doc.model.undo();
      expect(ref.index, 5);
      list.insert(8, 9);
      expect(ref.index, 5);
      list.removeRange(0, 2);
      expect(ref.index, 3);
      list.removeRange(2, 4);
      expect(ref.index, 2);
    });
    test('RealtimeList Delete Reference', () {
      rt.IndexReference ref = list.registerReference(5, true);
      expect(ref.index, 5);
      list.removeRange(4, 6);
      expect(ref.index, -1);
    });
    // TODO newObject and oldObject
    test('RealtimeString Reference Events', () {
      string.text = "aaaaaaaaaa";
      rt.IndexReference ref = string.registerReference(5, true);
      StreamSubscription ssRef;
      ssRef = ref.onReferenceShifted.listen(expectAsync1((rt.ReferenceShiftedEvent event) {
        expect(event.oldIndex, 5);
        expect(event.newIndex, 7);
        expect(ref.index, 7);
      }));
      string.insertString(0, "xx");
      ssRef.cancel();
    });
    test('Assign index', () {
      string.text = 'aaaaaaaaa';
      var ref = string.registerReference(5, true);
      expect(ref.index, 5);
      ref.index = 7;
      expect(ref.index, 7);
      string.insertString(0,  'xx');
      expect(ref.index, 9);
    });
    test('resurrect index', () {
      var ref = string.registerReference(2, true);
      string.removeRange(1,3);
      expect(ref.index, -1);
      ref.index = 3;
      expect(ref.index, 3);
      string.insertString(0, 'x');
      expect(ref.index, 4);
    });
    test('canBeDeleted', () {
      var refTrue = string.registerReference(3, true);
      expect(refTrue.canBeDeleted, true);
      var refFalse = string.registerReference(3, false);
      expect(refFalse.canBeDeleted, false);
    });
    test('referencedObject', () {
      var ref = string.registerReference(2, false);
      expect(ref.referencedObject.text, string.text);
    });
    test('type', () {
      var ref = string.registerReference(2, false);
      expect(ref.type, rt.CollaborativeTypes.INDEX_REFERENCE.value);
    });
    test('DeleteMode', () {
      var ref = string.registerReference(2, true);
      expect(ref.deleteMode, rt.IndexReference.DeleteMode.SHIFT_TO_INVALID);
      var ref2 = string.registerReference(2, false);
      expect(ref2.deleteMode, rt.IndexReference.DeleteMode.SHIFT_AFTER_DELETE);
    });
  });

  group('Initial Values', () {
    test('map', () {
      doc.model.root['filled-map'] = doc.model.createMap({'key1': doc.model.createString(), 'key2': 4});
      expect(doc.model.root['filled-map']['key1'].text, '');
      expect(doc.model.root['filled-map']['key2'], 4);
    });
    test('list', () {
      doc.model.root['filled-list'] = doc.model.createList([doc.model.createString(), 4]);
      expect(doc.model.root['filled-list'][0].text, '');
      expect(doc.model.root['filled-list'][1], 4);
    });
    test('string', () {
      doc.model.root['filled-string'] = doc.model.createString('content');
      expect(doc.model.root['filled-string'].text, 'content');
    });
  });

  group('Events', () {
    // TODO Object Change Bubbling
    test('Execution order', () {
      doc.model.root['text'].text = 'abc';
      var td = doc.model.root['text'].onTextDeleted.listen(expectAsync1((_) {
        expect(doc.model.root['text'].text, 'def');
      }));
      doc.model.root['text'].text = 'def';
      td.cancel();
    });
  });

  group('Native Objects', () {
    test('map', () {
      doc.model.root['native-map'] = {'map': {'key': 'val'}, 'list': [1,2,3], 'string': 'value'};
      expect(doc.model.root['native-map']['map']['key'], 'val');
      expect(doc.model.root['native-map']['list'][1], 2);
      expect(doc.model.root['native-map']['string'], 'value');
    });
    test('list', () {
      doc.model.root['native-list'] = [{'key': 'value'}, [1,2,3], 'value'];
      expect(doc.model.root['native-list'][0]['key'], 'value');
      expect(doc.model.root['native-list'][1][1], 2);
      expect(doc.model.root['native-list'][2], 'value');
    });
    test('string', () {
      doc.model.root['native-string'] = 'value';
      expect(doc.model.root['native-string'], 'value');
    });
  });

  group('Multiple entries', () {
    test('Twice in one map', () {
      var str = doc.model.createString('dup');
      doc.model.root['map']['duplicate1'] = str;
      doc.model.root['map']['duplicate2'] = str;
      expect(doc.model.root['map']['duplicate1'].text,
             doc.model.root['map']['duplicate2'].text);
      var ssObjChanged;
      ssObjChanged = doc.model.root['map'].onObjectChanged.listen(expectAsync1((e) {
        expect(e.events[0].type, 'text_inserted');
        expect(e.events[0].text, 'whatever');
      }, count: 1));
      doc.model.root['map']['duplicate1'].append('whatever');
      ssObjChanged.cancel();
    });
    // TODO this same test for lists
    test('One of two removed from map', () {
      var str = doc.model.createString('dup');
      doc.model.root['map']['removeOne'] = doc.model.createMap();
      doc.model.root['map']['removeOne']['duplicate1'] = str;
      doc.model.root['map']['removeOne']['duplicate2'] = str;
      expect(doc.model.root['map']['removeOne']['duplicate1'].text,
             doc.model.root['map']['removeOne']['duplicate2'].text);
      doc.model.root['map']['removeOne'].remove('duplicate2');
      var ssObjChanged;
      ssObjChanged = doc.model.root['map']['removeOne'].onObjectChanged.listen(expectAsync1((e) {
        expect(e.events[0].type, 'text_inserted');
        expect(e.events[0].text, 'something');
      }, count: 1));
      doc.model.root['map']['removeOne']['duplicate1'].append('something');
      ssObjChanged.cancel();
    });
    test('Once in two maps each', () {
      var str = doc.model.createString('dup');
      doc.model.root['map']['dupmap1'] = doc.model.createMap();
      doc.model.root['map']['dupmap2'] = doc.model.createMap();
      doc.model.root['map']['dupmap1']['str'] = str;
      doc.model.root['map']['dupmap2']['str'] = str;
      // can only compare text because they won't be the same object
      expect(doc.model.root['map']['dupmap1']['str'].text,
             doc.model.root['map']['dupmap2']['str'].text);
      var ssObjChanged1;
      ssObjChanged1 = doc.model.root['map']['dupmap1'].onObjectChanged.listen(expectAsync1((e) {
        print('dupmap1 handler');
        expect(e.events[0].type, 'text_inserted');
      }));
      var ssObjChanged2;
      ssObjChanged2 = doc.model.root['map']['dupmap2'].onObjectChanged.listen(expectAsync1((e) {
        print('dupmap2 handler');
        expect(e.events[0].type, 'text_inserted');
      }));
      var ssRootChanged;
      ssRootChanged = doc.model.root['map'].onObjectChanged.listen(expectAsync1((e) {
        print('root handler');
        expect(e.events[0].type, 'text_inserted');
      }, count: 1));
      doc.model.root['map']['dupmap1']['str'].append('hello');
      ssObjChanged1.cancel();
      ssObjChanged2.cancel();
      ssRootChanged.cancel();
    });
    test('String in map and sub map', () {
      var str = doc.model.createString('dup');
      var subsubmap = doc.model.createMap();
      var submap = doc.model.createMap();
      var topmap = doc.model.createMap();

      doc.model.root['map']['mapwithsub'] = topmap;
      doc.model.root['map']['mapwithsub']['submap'] = submap;
      doc.model.root['map']['mapwithsub']['submap']['subsubmap'] = subsubmap;

      doc.model.root['map']['mapwithsub']['str'] = str;
      doc.model.root['map']['mapwithsub']['submap']['subsubmap']['str'] = str;

      var ssMap = doc.model.root['map'].onObjectChanged.listen((e) {
        expect(e.events[0].type, rt.EventType.TEXT_INSERTED);
      });

      var ssSubMap = doc.model.root['map'].onObjectChanged.listen((e) {
        expect(e.events[0].type, rt.EventType.TEXT_INSERTED);
      });

      var ssSubSubMap = doc.model.root['map'].onObjectChanged.listen((e) {
        expect(e.events[0].type, rt.EventType.TEXT_INSERTED);
      });

      str.append('something');

      ssMap.cancel();
      ssSubMap.cancel();
      ssSubSubMap.cancel();
    });
    test('loop length 2', () {
      var map1 = doc.model.createMap();
      var map2 = doc.model.createMap();
      doc.model.root['map']['loop'] = map1;
      map1['map2'] = map2;
      map2['map1'] = map1;
      map1['map2b'] = map2;

      var ssMap1 = map1.onObjectChanged.listen((e) {
        expect(e.events[0].type, rt.EventType.VALUE_CHANGED);
      });
      var ssMap2 = map2.onObjectChanged.listen((e) {
        expect(e.events[0].type, rt.EventType.VALUE_CHANGED);
      });
      var ssMap = doc.model.root['map'].onObjectChanged.listen((e) {
        expect(e.events[0].type, rt.EventType.VALUE_CHANGED);
      });

      map1['text'] = 'text value';

      ssMap1.cancel();
      ssMap2.cancel();
      ssMap.cancel();
    });
  });

  group('Weird', () {
    test('Map in self', () {
      doc.model.root['self'] = doc.model.root;
      expect(doc.model.root.id, doc.model.root['self'].id);
      var ssRoot = doc.model.root.onObjectChanged.listen((e) {
        expect(e.events[0].type, rt.EventType.VALUE_CHANGED);
      });

      doc.model.root['self']['key'] = 'val';

      ssRoot.cancel();
    });
  });

  group('Identical objects', () {
    test('In Map', () {
      var obj = {'a': 'a'};
      doc.model.root['map']['dup1'] = obj;
      doc.model.root['map']['dup2'] = obj;
      obj['a'] = 'b';
      expect(doc.model.root['map']['dup1']['a'], 'a');
    });
  });

  // TODO export

  group('Custom', () {
    test('Book is custom object', () {
      expect(rt.isCustomObject(doc.model.root['book']), true);
      expect(rt.isCustomObject(doc.model.root['text']), false);
    });
    test('Set title', () {
      expect(doc.model.root['book'].title, null);
      doc.model.root['book'].onObjectChanged.listen((e) {
        print(e);
      });
      doc.model.root['book'].onValueChanged.listen((e) {
        print('${e.property} changed from ${e.oldValue} to ${e.newValue}');
      });
      doc.model.root['book'].title = 'title';
      expect(doc.model.root['book'].title, 'title');
    });
    test('custom.getModel', () {
      // can't compare to doc.model because it's a new object
      expect(rt.getModel(doc.model.root['book']) is rt.Model, true);
    });
    test('custom.getId', () {
      expect(rt.getId(doc.model.root['book']) is String, true);

      // TODO hack to reset state to original so repeated tests work on the same doc
      doc.model.root['text'].text = 'Hello Realtime World!';
      doc.model.root['list'].clear();
      doc.model.root['map'].clear();
      doc.model.root['book'] = doc.model.create('Book');
    });
  });

  group('Model', () {
    // TODO I think this wasn't intended to be public
//    test('getObject', () {
//      expect(doc.model.root.id, rt.Model.getObject(doc.model, doc.model.root.id).id);
//    });
    test('serverRevision', () {
      expect(doc.model.serverRevision, greaterThan(0));
    });
    // TODO toJson
  });

  // Local
  group('Local', () {
    // TODO fix missing fields from Book custom object in this test
    test('Local document from data', () {
      var data = '{"appId":"1066816720974","revision":243,"data":{"id":"root","type":"Map","value":{"book":' +
                   '{"id":"XlvCsSlXfioK","type":"Book","value":{"title":{"json":"title"}}},"filled-list":{"id"' +
                   ':"KbY54ouZfjDj","type":"List","value":[{"id":"5ojDCWtyfjDj","type":"EditableString","value"' +
                   ':""},{"json":4}]},"filled-map":{"id":"u162QBQRfjDg","type":"Map","value":{"key1":{"id":' +
                   '"h8YUGMm-fjDg","type":"EditableString","value":""},"key2":{"json":4}}},"filled-string":{"id"' +
                   ':"sHwruTA4fjDo","type":"EditableString","value":"content"},"key":{"json":"val"},"list":{"id":' +
                   '"lDoU1aUnfioJ","type":"List","value":[{"json":3},{"json":4},{"json":7},{"json":8},{"json":10},' +
                   '{"json":11},{"json":12}]},"map":{"id":"yxOq4amKfioJ","type":"Map","value":{"duplicate1":{"id":' +
                   '"Ffz9b8VifjEC","type":"EditableString","value":"dupwhatever"},"duplicate2":{"ref":"Ffz9b8VifjEC"}' +
                   ',"dupmap1":{"id":"jYbvf3qufjEI","type":"Map","value":{"str":{"id":"mdsF6PUlfjEH","type":"EditableString"' +
                   ',"value":"duphello"}}},"dupmap2":{"id":"3zTkGJRnfjEI","type":"Map","value":{"str":{"ref":"mdsF6PUlfjEH"' +
                   '}}},"loop":{"id":"3oQwUdslfjET","type":"Map","value":{"map2":{"id":"PBG2cdrhfjET","type":"Map",' +
                   '"value":{"map1":{"ref":"3oQwUdslfjET"}}},"map2b":{"ref":"PBG2cdrhfjET"},"text":{"json":"text value"}}}' +
                   ',"mapwithsub":{"id":"Q7VHKEdkfjEO","type":"Map","value":{"str":{"id":"3Ozrz4-afjEO","type":"EditableString"' +
                   ',"value":"dupsomething"},"submap":{"id":"sNZxu4TdfjEO","type":"Map","value":{"subsubmap":{"id":' +
                   '"09j9Bti4fjEO","type":"Map","value":{"str":{"ref":"3Ozrz4-afjEO"}}}}}}},"string":{"json":1}}},' +
                   '"self":{"ref":"root"},"text":{"id":"eUO6WzdGfioE","type":"EditableString","value":"xxxaaaaaaaaa"}}}}';
      rt.Document localDoc = rt.GoogleDocProvider.loadFromJson(data);
      expect(localDoc, isNotNull);
      /*var dp = new rt.LocalDocumentProvider(data);
      dp.loadDocument().then(expectAsync1((doc) {
        dp.exportDocument().then(expectAsync1((result) {
          // correct value
          var jsonValue = {"appId":"1066816720974","revision":243,"data":{"id":"root","type":"Map",
            "value":{"book":{"id":"XlvCsSlXfioK","type":"Book","value":{"title":{"json":"title"}}},
            "filled-list":{"id":"KbY54ouZfjDj","type":"List","value":[{"id":"5ojDCWtyfjDj","type":"EditableString",
            "value":""},{"json":4}]},"filled-map":{"id":"u162QBQRfjDg","type":"Map","value":{"key1":{"id":"h8YUGMm-fjDg",
            "type":"EditableString","value":""},"key2":{"json":4}}},"filled-string":{"id":"sHwruTA4fjDo",
            "type":"EditableString","value":"content"},"key":{"json":"val"},"list":{"id":"lDoU1aUnfioJ",
            "type":"List","value":[{"json":3},{"json":4},{"json":7},{"json":8},{"json":10},{"json":11},{"json":12}]},
            "map":{"id":"yxOq4amKfioJ","type":"Map","value":{"duplicate1":{"id":"Ffz9b8VifjEC","type":"EditableString",
            "value":"dupwhatever"},"duplicate2":{"ref":"Ffz9b8VifjEC"},"dupmap1":{"id":"jYbvf3qufjEI","type":"Map",
            "value":{"str":{"id":"mdsF6PUlfjEH","type":"EditableString","value":"duphello"}}},"dupmap2":{"id":"3zTkGJRnfjEI",
            "type":"Map","value":{"str":{"ref":"mdsF6PUlfjEH"}}},"loop":{"id":"3oQwUdslfjET","type":"Map",
            "value":{"map2":{"id":"PBG2cdrhfjET","type":"Map","value":{"map1":{"ref":"3oQwUdslfjET"}}},
            "map2b":{"ref":"PBG2cdrhfjET"},"text":{"json":"text value"}}},"mapwithsub":{"id":"Q7VHKEdkfjEO","type":"Map",
            "value":{"str":{"id":"3Ozrz4-afjEO","type":"EditableString","value":"dupsomething"},"submap":{"id":"sNZxu4TdfjEO",
            "type":"Map","value":{"subsubmap":{"id":"09j9Bti4fjEO","type":"Map","value":{"str":{"ref":"3Ozrz4-afjEO"}}}}}}},
            "string":{"json":1}}},"self":{"ref":"root"},"text":{"id":"eUO6WzdGfioE","type":"EditableString","value":"xxxaaaaaaaaa"}}}};
          jsonValue['revision'] = 0;
          jsonValue['appId'] = 0;
          jsonValue = JSON.encode(jsonValue);
          jsonValue = jsonValue.replaceAllMapped(new RegExp('"(id|ref)":"[^"]+"'),
              (match) => '"${match[1]}":"ID"');
          jsonValue = JSON.decode(jsonValue);

          result['revision'] = 0;
          result['appId'] = 0;
          var stringified = JSON.encode(result);
          stringified = stringified.replaceAllMapped(new RegExp('"(id|ref)":"[^"]+"'),
              (match) => '"${match[1]}":"ID"');
          result = JSON.decode(stringified);

          expect(result, jsonValue);
        }));
      }));*/
    });
  });

  group('Collaborator', () {
    // TODO collaborators doesn't include this instance
    test('Properties', () {
      var collab = doc.collaborators[0];
      expect(collab, isNotNull);
      expect(collab.displayName, isNotNull);
      expect(collab.isAnonymous, false);
      expect(collab.isMe, true);
      expect(collab.permissionId, isNotNull);
      expect(collab.photoUrl, isNotNull);
      expect(collab.sessionId, isNotNull);
      expect(collab.userId,isNotNull);
    });
    // TODO can't test events without collaborators joining/leaving
  });

  group('Enums', () {
    test('CollaborativeTypes', () {
      expect(rt.CollaborativeTypes.COLLABORATIVE_LIST.value, 'List');
      expect(rt.CollaborativeTypes.COLLABORATIVE_MAP.value, 'Map');
      expect(rt.CollaborativeTypes.COLLABORATIVE_STRING.value, 'EditableString');
      expect(rt.CollaborativeTypes.INDEX_REFERENCE.value, 'IndexReference');
    });
    test('ErrorType', () {
      expect(rt.ErrorType.CONCURRENT_CREATION.value, 'concurrent_creation');
      expect(rt.ErrorType.INVALID_COMPOUND_OPERATION.value, 'invalid_compound_operation');
      expect(rt.ErrorType.INVALID_JSON_SYNTAX.value, 'invalid_json_syntax');
      expect(rt.ErrorType.MISSING_PROPERTY.value, 'missing_property');
      expect(rt.ErrorType.NOT_FOUND.value, 'not_found');
      expect(rt.ErrorType.FORBIDDEN.value, 'forbidden');
      expect(rt.ErrorType.SERVER_ERROR.value, 'server_error');
      expect(rt.ErrorType.CLIENT_ERROR.value, 'client_error');
      expect(rt.ErrorType.TOKEN_REFRESH_REQUIRED.value, 'token_refresh_required');
      expect(rt.ErrorType.INVALID_ELEMENT_TYPE.value, 'invalid_element_type');
      expect(rt.ErrorType.NO_WRITE_PERMISSION.value, 'no_write_permission');
    });
    test('EventType', () {
      expect(rt.EventType.OBJECT_CHANGED.value, 'object_changed');
      expect(rt.EventType.VALUES_SET.value, 'values_set');
      expect(rt.EventType.VALUES_ADDED.value, 'values_added');
      expect(rt.EventType.VALUES_REMOVED.value, 'values_removed');
      expect(rt.EventType.VALUE_CHANGED.value, 'value_changed');
      expect(rt.EventType.TEXT_INSERTED.value, 'text_inserted');
      expect(rt.EventType.TEXT_DELETED.value, 'text_deleted');
      expect(rt.EventType.COLLABORATOR_JOINED.value, 'collaborator_joined');
      expect(rt.EventType.COLLABORATOR_LEFT.value, 'collaborator_left');
      expect(rt.EventType.REFERENCE_SHIFTED.value, 'reference_shifted');
      expect(rt.EventType.DOCUMENT_SAVE_STATE_CHANGED.value, 'document_save_state_changed');
      expect(rt.EventType.UNDO_REDO_STATE_CHANGED.value, 'undo_redo_state_changed');
      expect(rt.EventType.ATTRIBUTE_CHANGED.value, 'attribute_changed');
    });
  });

  // Document
  // TODO saveAs test
  group('Document', () {
    test('isClosed while open', () {
      expect(doc.isClosed, false);
    });
    test('isClosed when closed', () {
      doc.close();
      expect(doc.isClosed, true);
    });
    test('is closed error', () {
      try {
        doc.collaborators;
      } catch (e) {
        expect(e, 'DocumentClosedError: Document is closed.');
      }
    });
  });
}

class Book extends rt.CustomObject {
  static const NAME = 'Book';

  String get title => get('title');
  String get author => get('author');
  String get isbon => get('isbn');
  bool get isCheckedOut => get('isCheckedOut');
  String get reviews => get('reviews');
  set title(String title) => set('title', title);
  set author(String author) => set('author', author);
  set isbn(String isbn) => set('isbn', isbn);
  set isCheckedOut(bool isCheckedOut) => set('isCheckedOut', isCheckedOut);
  set reviews(String reviews) => set('reviews', reviews);
}

main() {
  hierarchicalLoggingEnabled = true;
  Logger.root.onRecord.listen(new LogPrintHandler());
  Logger.root.level = Level.INFO;

  useHtmlConfiguration();

  // set clientId
  rt.GoogleDocProvider.setClientId('1066816720974.apps.googleusercontent.com');

  rt.GoogleDocProvider.globalSetup().then((val) {

  //  var docProvider = new rt.GoogleDocProvider('0B0OUnldiyG0hSEU0U3VnalQ1a1U');
  ////  var docProvider = new rt.GoogleDocProvider.newDoc('rdm test doc');
    var docProvider = new rt.LocalDocumentProvider();

    rt.registerType(Book, Book.NAME);
    rt.collaborativeField(Book.NAME, "title");
    rt.collaborativeField(Book.NAME, "author");
    rt.collaborativeField(Book.NAME, "isbn");
    rt.collaborativeField(Book.NAME, "isCheckedOut");
    rt.collaborativeField(Book.NAME, "reviews");

    docProvider.loadDocument(initializeModel).then(onFileLoaded);
  });
}
