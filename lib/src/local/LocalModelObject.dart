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

part of local_realtime_data_model;

class LocalModelObject extends LocalRetainable implements rt.CollaborativeObject {

  /// Local objects have no js Proxy
  final js.Proxy $unsafe = null;

  final String id;

  StreamController<LocalObjectChangedEvent> _onObjectChanged
    = new StreamController<LocalObjectChangedEvent>.broadcast(sync: true);
  Stream<LocalObjectChangedEvent> get onObjectChanged => _onObjectChanged.stream;
  // a separate stream to which object changed events are sent after they are
  // send to _onObjectChanged. this is to propogate up in the correct order
  // TODO there's almost certainly a better way to do this
  StreamController<LocalObjectChangedEvent> _onPostObjectChangedController
    = new StreamController<LocalObjectChangedEvent>.broadcast(sync: true);
  Stream<LocalObjectChangedEvent> get _onPostObjectChanged => _onPostObjectChangedController.stream;

  // TODO implement custom objects
  Stream<rt.ValueChangedEvent> get onValueChanged => null; // TODO implement this getter

  /// Local objects have no js Proxy
  dynamic toJs() => null;

  static int _idNum = 0;
  static String get nextId => (_idNum++).toString();

  LocalModelObject() : id = nextId;

  static bool _inEmitEventsAndChangedScope = false;

  // create an emit a LocalObjectChangedEvent from a list of events
  void _emitEventsAndChanged(List<StreamController> controllers, List<LocalUndoableEvent> events) {
    bool terminal = !_inEmitEventsAndChangedScope;
    if(terminal) {
      _inEmitEventsAndChangedScope = true;
    }
    // construct change event before firing actual events
    var event = new LocalObjectChangedEvent._(events,this,terminal);
    for(int i = 0; i < events.length; i++) {
      // execute events
      _executeEvent(events[i]);
      // fire actual events
      controllers[i].add(events[i]);
    }
    // fire change event on normal stream
    _onObjectChanged.add(event);
    // fire on propagation stream
    _onPostObjectChangedController.add(event);
    if(terminal) {
      _inEmitEventsAndChangedScope = false;
    }
  }
  void _executeAndEmitEvent(LocalUndoableEvent event) {
    // make change
    _executeEvent(event);
    // emit event
    _eventStreamControllers[event.type].add(event);
  }

  void _executeEvent(LocalUndoableEvent event) {
    // TODO implement custom objects
  }


  // map from event type to stream controller they go on
  // TODO with this we don't need to pass controllers to _emitEventsAndChanged
  Map<String, StreamController> _eventStreamControllers = {};

  /// JSON serialized data
  Map toJSON() {
    // TODO implement for custom object
    return {
      "id": this.id,
      "type": "", // TODO
      "value": {} // TODO
    };
  }
}