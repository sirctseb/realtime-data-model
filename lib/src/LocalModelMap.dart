// Copyright (c) 2013, Christopher Best
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

part of realtime_data_model;

class LocalModelMap<V> extends LocalModelObject implements rt.CollaborativeMap<V> {
  // TODO add promotes back in here

  @override int get length => _map.length;

  @override V operator [](String key) => _map[key];
  // TODO event
  @override void operator []=(String key, V value) {
    // send the event
    var event = new LocalValueChangedEvent._(value, _map[key], key, this);
    _emitEventsAndChanged([_onValueChanged], [event]);
  }

  void clear() {
    // remove each key and let it produce the event
    keys.forEach((key) => remove(key));
  }
  // TODO event
  @override V remove(String key) {
    // create the event
    var event = new LocalValueChangedEvent._(null, _map[key], key, this);
    // send the event
    _emitEventsAndChanged([_onValueChanged], [event]);
  }
  /// deprecated : use `xxx.remove(key)`
  @deprecated V delete(String key) => remove(key);
  /// deprecated : use `xxx[key]`
  @deprecated V get(String key) => this[key];
  @override bool containsKey(String key) => _map.containsKey(key);
  /// deprecated : use `xxx.containsKey(key)`
  @deprecated bool has(String key) => containsKey(key);
  @override bool get isEmpty => _map.isEmpty;
  // TODO figure out what type to return
  List<List<V>> get items => _map.keys.map((key) => [key, _map[key]]).toList();
  // TODO return TypePromotingList object
  @override List<String> get keys => _map.keys.toList();
  /// deprecated : use `xxx[key] = value`
  @deprecated V set(String key, V value) {
    this[key] = value;
    return value;
  }
  // TODO return TypePromotingList object
  @override List<V> get values => _map.values;
  @override bool get isNotEmpty => !isEmpty;

  Stream<rt.ValueChangedEvent> get onValueChanged => _onValueChanged.stream;

  // backing map instance
  Map<String, V> _map = new Map<String, V>();
  // map of subscriptions for object changed events for model objects contained in this
  Map<String, StreamSubscription<LocalObjectChangedEvent>> _ssMap
    = new Map<String, StreamSubscription<LocalObjectChangedEvent>>();
  // stream controller
  // TODO should be use a subscribestreamprovider? I don't think we need to
  // TODO we are using a broadcast stream so that new listeners don't get back events. is this the correct approach?
  StreamController<rt.ValueChangedEvent> _onValueChanged = new StreamController<rt.ValueChangedEvent>.broadcast(sync: true);

  void addAll(Map<String, V> other) {
    other.forEach((key,val) => this[key] = val);
  }

  bool containsValue(V value) => Maps.containsValue(this, value);

  void forEach(void f(String key, V value)) => Maps.forEach(this, f);

  V putIfAbsent(String key, V ifAbsent()) => Maps.putIfAbsent(this, key, ifAbsent);

  int get size => length;

  LocalModelMap([Map initialValue]) {
    // initialize with value
    if(initialValue != null) {
      // don't emit events, but do propagate changes
      _map.addAll(initialValue);
      _map.forEach((key,value) {
        _ssMap[key] = (value as LocalModelObject)._onPostObjectChanged.listen((e) {
          // fire normal change event
          _onObjectChanged.add(e);
          // fire on propagation stream
          _onPostObjectChangedController.add(e);
        });
      });
    }

    _eventStreamControllers[ModelEventType.VALUE_CHANGED.value] = _onValueChanged;
  }

  void _executeEvent(LocalUndoableEvent event_in) {
    if(event_in.type == ModelEventType.VALUE_CHANGED.value) {
        var event = event_in as LocalValueChangedEvent;
        // TODO are we considering null values distinct from unset values?
        _map[event.property] = event.newValue;
        // stop propagating changes if we're writing over a model object
        if(_ssMap.containsKey(event.property)) {
          _ssMap[event.property].cancel();
          _ssMap.remove(event.property);
        }
        // propagate changes on model data objects
        // TODO pipe?
        if(event.newValue is LocalModelObject) {
          _ssMap[event.property] = (event.newValue as LocalModelObject)._onPostObjectChanged.listen((e) {
            // fire normal change event
            _onObjectChanged.add(e);
            // fire on propagation stream
            _onPostObjectChangedController.add(e);
          });
        }
    } else {
        super._executeEvent(event_in);
    }
  }
}