import 'package:web/web.dart' as web;

import '../core/ssr/markup.dart';

final _stylesheetReferences = <String, _StylesheetReference>{};

void Function() installMarkupStylesheets(MarkupNode tree) {
  final acquiredIds = <String>[];
  try {
    for (final stylesheet in collectMarkupStylesheets(tree)) {
      final id = markupStylesheetId(stylesheet);
      var reference = _stylesheetReferences[id];
      if (reference == null) {
        final existing = web.document.getElementById(id);
        final web.HTMLStyleElement element;
        final isOwned;
        if (existing != null) {
          if (existing is! web.HTMLStyleElement ||
              !existing.hasAttribute('data-sparrow-stylesheet') ||
              existing.textContent != stylesheet) {
            throw StateError('Conflicting generated stylesheet "$id".');
          }
          element = existing;
          isOwned = false;
        } else {
          final head = web.document.head;
          if (head == null) {
            throw StateError('The document has no head element.');
          }
          element = web.document.createElement('style') as web.HTMLStyleElement
            ..id = id
            ..setAttribute('data-sparrow-stylesheet', '')
            ..textContent = stylesheet;
          head.appendChild(element);
          isOwned = true;
        }
        reference = _StylesheetReference(element, isOwned: isOwned);
        _stylesheetReferences[id] = reference;
      } else if (reference.element.textContent != stylesheet) {
        throw StateError('Conflicting generated stylesheet "$id".');
      }

      reference.referenceCount++;
      acquiredIds.add(id);
    }
  } catch (_) {
    _releaseStylesheets(acquiredIds);
    rethrow;
  }

  var isDisposed = false;
  return () {
    if (isDisposed) return;
    isDisposed = true;
    _releaseStylesheets(acquiredIds);
  };
}

void _releaseStylesheets(List<String> ids) {
  for (final id in ids.reversed) {
    final reference = _stylesheetReferences[id];
    if (reference == null) continue;

    reference.referenceCount--;
    if (reference.referenceCount != 0) continue;

    if (reference.isOwned) reference.element.remove();
    _stylesheetReferences.remove(id);
  }
}

class _StylesheetReference {
  _StylesheetReference(this.element, {required this.isOwned});

  final web.HTMLStyleElement element;
  final bool isOwned;
  int referenceCount = 0;
}
