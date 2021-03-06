import 'dart:html';

import 'package:js/js.dart' as js;
import 'package:js/js_wrapping.dart' as jsw;
import 'package:realtime_data_model/realtime_data_model.dart' as rt;
//import 'package:realtime_data_model/realtime_data_model_custom.dart' as rtc;

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

initializeModel(model) {
  var book = model.create(Book.NAME);
  model.root['book'] = book;
}

/**
 * This function is called when the Realtime file has been loaded. It should
 * be used to initialize any user interface components and event handlers
 * depending on the Realtime model. In this case, create a text control binder
 * and bind it to our string model that we created in initializeModel.
 * @param doc {gapi.drive.realtime.Document} the Realtime document.
 */
onFileLoaded(doc) {
  Book book = doc.model.root['book'];

  // collaborators listener
  doc.onCollaboratorJoined.listen((rt.CollaboratorJoinedEvent e){
    print("user joined : ${e.collaborator.displayName}");
  });
  doc.onCollaboratorLeft.listen((rt.CollaboratorLeftEvent e){
    print("user left : ${e.collaborator.displayName}");
  });

  // listener on keyup
  final title = document.getElementById('title') as TextInputElement;
  title.value = book.title != null ? book.title : "";
  title.onKeyUp.listen((e) {
    book.title = title.value;
  });

  // update input on changes
  book.onObjectChanged.listen((rt.ObjectChangedEvent e){
    print("object changes : ${e}");
    title.value = book.title;
  });
  book.onValueChanged.listen((rt.ValueChangedEvent e){
    print("value changes : ${e}");
  });

  // Enabling UI Elements.
  title.disabled = false;
}

main() {
  // set clientId
  rt.GoogleDocProvider.clientId = 'INSERT YOUR CLIENT ID HERE';

  var docProvider = new rt.GoogleDocProvider.newDoc('rdm test doc');
//  var docProvider = new rt.LocalDocumentProvider();

  docProvider.registerType(Book, "Book", ["title", "author", "isbn", "isCheckedOut", "reviews"]);
//  rt.CustomObject.registerType(Book, "Book", ["title", "author", "isbn", "isCheckedOut", "reviews"]);

  docProvider.loadDocument(initializeModel).then(onFileLoaded);

  //var realtimeLoader = new js.Proxy(js.context.rtclient.RealtimeLoader, realtimeOptions);
//  realtimeLoader.start((){
    //Book.registerType();
//  });
}
