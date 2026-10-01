import 'dart:js_interop';

@JS('Blob')
extension type _Blob._(JSObject _) implements JSObject {
  external factory _Blob(JSArray<JSString> parts, JSObject options);
}
@JS('URL.createObjectURL')
external JSString _createObjectURL(_Blob blob);
@JS('URL.revokeObjectURL')
external void _revokeObjectURL(JSString url);
@JS('document.createElement')
external _Anchor _createElement(JSString name);
extension type _Anchor._(JSObject _) implements JSObject {
  external set href(JSString value);
  external set download(JSString value);
  external void click();
}
void downloadJson(String text) {
  final options =
      {'type': 'application/json;charset=utf-8'}.jsify() as JSObject;
  final blob = _Blob([text.toJS].toJS, options);
  final url = _createObjectURL(blob);
  final anchor = _createElement('a'.toJS);
  anchor.href = url;
  anchor.download = 'futuremint-export.json'.toJS;
  anchor.click();
  Future<void>.delayed(const Duration(seconds: 1), () => _revokeObjectURL(url));
}
