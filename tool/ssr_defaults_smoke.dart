import 'package:sparrow_kit/server.dart';

class _Page implements SsrComponent {
  @override
  MarkupNode render() => MarkupElement(
        'main',
        children: [MarkupText('Ready')],
      );
}

void main() {
  final html = renderToString(_Page());
  for (final expected in [
    '<title>SparrowKit Application</title>',
    '<meta name="description" content="A web application built with SparrowKit.">',
    '<meta property="og:title" content="SparrowKit Application">',
    '<meta name="twitter:card" content="summary">',
    '<div id="app"><main>Ready</main></div>',
    '<script defer src="/main.dart.js"></script>',
  ]) {
    if (!html.contains(expected)) {
      throw StateError('Expected default SSR output to include: $expected');
    }
  }

  final staticHtml = renderToString(_Page(), clientScript: null);
  if (staticHtml.contains('<script defer src=')) {
    throw StateError('A null client script should disable the script tag.');
  }
}
