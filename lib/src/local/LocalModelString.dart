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

class _LocalModelString extends _LocalIndexReferenceContainer implements CollaborativeString {

  // TODO need local events
  StreamController<_LocalTextInsertedEvent> _onTextInserted
    = new StreamController<_LocalTextInsertedEvent>.broadcast(sync: true);
  StreamController<_LocalTextDeletedEvent> _onTextDeleted
    = new StreamController<_LocalTextDeletedEvent>.broadcast(sync: true);

  int get length => _string.length;

  void append(String text) {
    // add event to stream
    var insertEvent = new _LocalTextInsertedEvent._(_string.length, text, this);
    _emitEventsAndChanged([insertEvent]);
  }
  String get text => _string;
  void insertString(int index, String text) {
    var insertEvent = new _LocalTextInsertedEvent._(index, text, this);
    _emitEventsAndChanged([insertEvent]);
  }
  void removeRange(int startIndex, int endIndex) {
    // get removed text for event
    var removed = _string.substring(startIndex, endIndex);
    // add event to stream
    var deleteEvent = new _LocalTextDeletedEvent._(startIndex, removed, this);
    _emitEventsAndChanged([deleteEvent]);
  }
  void set text(String text) {
    // trivial edit decomposition algorithm
    // add event to stream
    var deleteEvent = new _LocalTextDeletedEvent._(0, _string, this);
    var insertEvent = new _LocalTextInsertedEvent._(0, text, this);
    _emitEventsAndChanged([deleteEvent, insertEvent]);
  }

  Stream<_LocalTextInsertedEvent> get onTextInserted => _onTextInserted.stream;
  Stream<_LocalTextDeletedEvent> get onTextDeleted => _onTextDeleted.stream;

  _LocalModelString([String initialValue]) {
    // initialize
    if(initialValue != null) {
      // don't emit events
      _string = initialValue;
    }

    _eventStreamControllers[EventType.TEXT_DELETED.value] = _onTextDeleted;
    _eventStreamControllers[EventType.TEXT_INSERTED.value] = _onTextInserted;
  }

  void _executeEvent(_LocalUndoableEvent event_in) {
    // handle insert and delete events
    // TODO deal with type warnings
    if(event_in.type == EventType.TEXT_DELETED.value) {
      var event = event_in as _LocalTextDeletedEvent;
      // update string
      _string = "${_string.substring(0, event.index)}${_string.substring(event.index + event.text.length)}";
      // update references
      _shiftReferencesOnDelete(event.index, event.text.length);
    } else if(event_in.type == EventType.TEXT_INSERTED.value) {
      var event = event_in as _LocalTextInsertedEvent;
      // update string
      _string = "${_string.substring(0, event.index)}${event.text}${_string.substring(event.index)}";
      // update references
      _shiftReferencesOnInsert(event.index, event.text.length);
    } else {
      super._executeEvent(event_in);
    }
  }

  // current string value
  String _string = "";

  /// JSON serialized data
  Map toJSON() {
    return {
      "id": this.id,
      "type": "EditableString",
      "value": this._string
    };
  }
}