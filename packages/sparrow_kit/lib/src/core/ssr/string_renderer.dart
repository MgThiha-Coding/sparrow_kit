import 'dart:convert';

import '../seo/json_ld.dart';
import '../seo/metadata.dart';
import 'markup.dart';

class StringRenderer {
  String render(
    SsrComponent component, {
    HeadMetadata? metadata,
    String rootId = 'app',
    String? clientScript = '/main.dart.js',
  }) {
    final state = <String, Object?>{};
    final html = StringBuffer();
    final tree = component.render();
    final pageMetadata = metadata ?? HeadMetadata.defaults();

    html.write(
      '<!doctype html><html lang="${_escapeAttribute(pageMetadata.language)}"><head>',
    );
    html.write('<meta charset="utf-8">');
    html.write('<title>${_escapeText(pageMetadata.title)}</title>');
    if (pageMetadata.description != null) {
      html.write(
        '<meta name="description" content="${_escapeAttribute(pageMetadata.description!)}">',
      );
    }
    if (pageMetadata.canonicalUrl != null) {
      html.write(
        '<link rel="canonical" href="${_escapeAttribute(pageMetadata.canonicalUrl!)}">',
      );
    }
    for (final tag in pageMetadata.renderedMetaTags) {
      html.write(
        '<meta ${tag.attribute}="${_escapeAttribute(tag.key)}" content="${_escapeAttribute(tag.content)}">',
      );
    }
    for (final schema in pageMetadata.jsonLd) {
      _writeJsonLd(html, schema);
    }
    _writeStylesheets(html, tree);

    html.write('</head><body><div id="${_escapeAttribute(rootId)}">');
    _writeNode(html, tree, state);
    html.write('</div>');

    final encodedState = jsonEncode(state).replaceAll('<', r'\u003C');
    html.write(
      '<script id="__FRAMEWORK_STATE__" type="application/json">$encodedState</script>',
    );
    if (clientScript != null) {
      html.write(
        '<script defer src="${_escapeAttribute(clientScript)}"></script>',
      );
    }
    html.write('</body></html>');
    return html.toString();
  }

  void _writeNode(
    StringBuffer html,
    MarkupNode node,
    Map<String, Object?> state,
  ) {
    switch (node) {
      case MarkupText(:final value):
        html.write(_escapeText(value));
      case SignalText(:final id, :final signal):
        _collectState(state, id, signal.value);
        html.write('<!--fw:text:$id-->');
        html.write(_escapeText(_textValue(signal.value)));
        html.write('<!--fw:/text:$id-->');
      case MarkupKeyedChildren(
          :final id,
          :final itemTag,
          :final initialItems,
          :final source,
        ):
        _collectState(state, id, source.value);
        html.write('<!--fw:children:$id-->');
        for (final item in initialItems) {
          html.write(
            '<$itemTag data-sparrow-key="${_escapeAttribute(item.key)}">',
          );
          _writeNode(html, item.node, state);
          html.write('</$itemTag>');
        }
        html.write('<!--fw:/children:$id-->');
      case MarkupElement(
          :final tag,
          :final attributes,
          :final children,
        ):
        final isVoid = _voidElements.contains(tag.toLowerCase());
        if (isVoid && children.isNotEmpty) {
          throw ArgumentError('Void element <$tag> cannot have children.');
        }

        html.write('<$tag');
        for (final entry in attributes.entries) {
          if (!_validAttributeName.hasMatch(entry.key)) {
            throw ArgumentError.value(
              entry.key,
              'attribute',
              'Invalid HTML attribute name.',
            );
          }
          if (entry.key.toLowerCase().startsWith('on')) {
            throw ArgumentError.value(
              entry.key,
              'attribute',
              'Inline event attributes are not supported.',
            );
          }

          final rawValue = entry.value;
          final value =
              rawValue is SignalAttribute ? rawValue.signal.value : rawValue;
          if (rawValue is SignalAttribute) {
            _collectState(state, rawValue.id, value);
          }
          if (value == null || value == false) continue;

          html.write(' ${entry.key}="');
          html.write(value == true ? '' : _escapeAttribute(value.toString()));
          html.write('"');
        }

        if (isVoid) {
          html.write('>');
          return;
        }

        html.write('>');
        for (final child in children) {
          _writeNode(html, child, state);
        }
        html.write('</$tag>');
    }
  }

  void _writeJsonLd(StringBuffer html, JsonLdSchema schema) {
    final json = jsonEncode(schema.toJsonLd()).replaceAll('<', r'\u003C');
    html.write('<script type="application/ld+json">$json</script>');
  }

  void _writeStylesheets(StringBuffer html, MarkupNode tree) {
    for (final stylesheet in collectMarkupStylesheets(tree)) {
      html.write(
        '<style id="${markupStylesheetId(stylesheet)}" '
        'data-sparrow-stylesheet>',
      );
      html.write(
        stylesheet.replaceAll(
          RegExp(r'</style', caseSensitive: false),
          r'<\/style',
        ),
      );
      html.write('</style>');
    }
  }
}

String renderToString(
  SsrComponent component, {
  HeadMetadata? metadata,
  String rootId = 'app',
  String? clientScript = '/main.dart.js',
}) =>
    StringRenderer().render(
      component,
      metadata: metadata,
      rootId: rootId,
      clientScript: clientScript,
    );

final _validAttributeName = RegExp(r'^[A-Za-z_:][A-Za-z0-9:._-]*$');
const _voidElements = {
  'area',
  'base',
  'br',
  'col',
  'embed',
  'hr',
  'img',
  'input',
  'link',
  'meta',
  'param',
  'source',
  'track',
  'wbr',
};

void _collectState(Map<String, Object?> state, String id, Object? value) {
  if (state.containsKey(id) && state[id] != value) {
    throw StateError('Conflicting initial values for signal "$id".');
  }
  state[id] = value;
}

String _textValue(Object? value) => value?.toString() ?? '';

String _escapeText(String value) => value
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;');

String _escapeAttribute(String value) => _escapeText(
      value,
    ).replaceAll('"', '&quot;').replaceAll("'", '&#39;');
