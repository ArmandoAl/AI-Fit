import 'dart:async';

import 'package:web/web.dart' as web;

import 'dom.dart';

/// Confirmación modal nativa (`<dialog>`): foco atrapado, Esc cancela y el foco inicial queda en «Cancelar».
Future<bool> confirmDestructive({required String title, required String description, String confirmLabel = 'Eliminar'}) {
  final completer = Completer<bool>();
  var result = false;
  final dialog = web.document.createElement('dialog') as web.HTMLDialogElement
    ..className = 'modal'
    ..setAttribute('aria-labelledby', 'modal-title');
  final cancel = element('button', className: 'btn', text: 'Cancelar', attributes: {'type': 'button', 'autofocus': ''});
  final confirm = element('button', className: 'btn btn-danger', text: confirmLabel, attributes: {'type': 'button'});
  listen(cancel, 'click', (_) => dialog.close());
  listen(confirm, 'click', (_) {
    result = true;
    dialog.close();
  });
  listen(dialog, 'close', (_) {
    dialog.remove();
    if (!completer.isCompleted) completer.complete(result);
  });
  dialog
    ..append(element('h2', text: title, attributes: {'id': 'modal-title'}))
    ..append(element('p', text: description))
    ..append(element('div', className: 'modal-actions')
      ..append(cancel)
      ..append(confirm));
  web.document.body!.append(dialog);
  dialog.showModal();
  return completer.future;
}
