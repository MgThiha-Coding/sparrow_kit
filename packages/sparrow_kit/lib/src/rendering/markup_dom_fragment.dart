import 'package:web/web.dart' as web;

import '../core/ssr/markup.dart';
import '../core/ssr/string_renderer.dart';

void appendMarkupDomFragment(MarkupNode node, web.Element parent) {
  final html = StringRenderer().render(
    _MarkupFragment(node),
    rootId: 'sparrow-fragment',
    clientScript: null,
  );
  final parsed = web.DOMParser().parseFromString(html, 'text/html');
  final root = parsed.getElementById('sparrow-fragment');
  if (root == null) {
    throw StateError('Could not render a markup fragment.');
  }

  final appended = <web.Node>[];
  try {
    var child = root.firstChild;
    while (child != null) {
      final next = child.nextSibling;
      final clone = child.cloneNode(true);
      parent.appendChild(clone);
      appended.add(clone);
      child = next;
    }
  } catch (_) {
    for (final child in appended.reversed) {
      child.parentNode?.removeChild(child);
    }
    rethrow;
  }
}

class _MarkupFragment implements SsrComponent {
  const _MarkupFragment(this.node);

  final MarkupNode node;

  @override
  MarkupNode render() => node;
}
