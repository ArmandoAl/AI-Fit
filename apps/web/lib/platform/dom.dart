import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Utilidades mínimas para construir DOM nativo (diálogos, captura) fuera del árbol de Jaspr.
web.HTMLElement element(String tag, {String? className, String? text, Map<String, String> attributes = const {}}) {
  final created = web.document.createElement(tag) as web.HTMLElement;
  if (className != null) created.className = className;
  if (text != null) created.textContent = text;
  attributes.forEach((name, value) => created.setAttribute(name, value));
  return created;
}

void listen(web.EventTarget target, String type, void Function(web.Event event) handler) =>
    target.addEventListener(type, handler.toJS);
