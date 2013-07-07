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

class LocalModelObject implements rt.CollaborativeObject {
  
  /// Local objects have no js Proxy
  final js.Proxy $unsafe = null;

  final String id;

  // TODO will be LocalObjectChangedEvent
  Stream<rt.ObjectChangedEvent> get onObjectChanged => null; // TODO implement this getter

  // TODO will be LocalValueChangedEvent
  Stream<rt.ValueChangedEvent> get onValueChanged => null; // TODO implement this getter

  /// Local objects have no js Proxy
  dynamic toJs() => null;
  
  static int _idNum = 0;
  static String get nextId => (_idNum++).toString();
  
  LocalModelObject() : id = nextId;
}