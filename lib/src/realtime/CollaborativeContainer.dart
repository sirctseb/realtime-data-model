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

class CollaborativeContainer<V> extends CollaborativeObject {
  CollaborativeContainer._fromProxy(js.JsObject proxy) : super._fromProxy(proxy);

  static final Translator _realtimeTranslator = new CollaborativeContainerTranslator();
  final Translator<V> _translator = _realtimeTranslator;

  dynamic _toJs(V e) => _translator == null ? e : _translator.toJs(e);
  V _fromJs(dynamic value) => _translator == null ? value : _translator.fromJs(value);
}