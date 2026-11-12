import 'package:web/web.dart' as web;

import '../core/hydration/hydration_engine.dart';
import '../core/seo/head_manager.dart';
import '../core/seo/metadata.dart';
import '../core/ssr/markup.dart';
import '../rendering/component.dart' as runtime;

void Function() runApp<P>(
  runtime.Component<P> app, {
  String rootSelector = '#app',
  HeadMetadata? metadata,
}) {
  final headManager = HeadManager();
  try {
    headManager.apply(metadata ?? _documentMetadata());
    app.mount(rootSelector);
  } catch (_) {
    headManager.dispose();
    rethrow;
  }

  var isDisposed = false;
  return () {
    if (isDisposed) return;
    isDisposed = true;
    try {
      app.dispose();
    } finally {
      headManager.dispose();
    }
  };
}

void Function() hydrateApp(
  MarkupNode Function(HydrationState state) build, {
  String rootId = 'app',
  HeadMetadata? metadata,
}) {
  final state = HydrationState.fromDocument();
  final container = web.document.getElementById(rootId);
  if (container is! web.Element) {
    throw StateError('The server-rendered app root "$rootId" was not found.');
  }

  final headManager = HeadManager();
  try {
    headManager.apply(metadata ?? _documentMetadata());
    final disposeHydration = HydrationEngine().hydrate(
      container: container,
      tree: build(state),
    );

    var isDisposed = false;
    return () {
      if (isDisposed) return;
      isDisposed = true;
      try {
        disposeHydration();
      } finally {
        headManager.dispose();
      }
    };
  } catch (_) {
    headManager.dispose();
    rethrow;
  }
}

HeadMetadata _documentMetadata() {
  final title = web.document.title.trim();
  final description = web.document
          .querySelector('meta[name="description"]')
          ?.getAttribute('content')
          ?.trim() ??
      '';
  final defaults = HeadMetadata.defaults(
    title: title.isEmpty ? 'SparrowKit Application' : title,
    description: description.isEmpty
        ? 'A web application built with SparrowKit.'
        : description,
  );
  final existingCanonical = web.document
          .querySelector('link[rel="canonical"]')
          ?.getAttribute('href')
          ?.trim() ??
      '';
  final existingLanguage =
      web.document.documentElement?.getAttribute('lang')?.trim() ?? '';
  final location = Uri.tryParse(web.window.location.href);
  final canonicalUrl = existingCanonical.isNotEmpty
      ? existingCanonical
      : location != null &&
              (location.scheme == 'http' || location.scheme == 'https')
          ? location.replace(query: '', fragment: '').toString()
          : null;

  return HeadMetadata(
    title: defaults.title,
    description: defaults.description,
    canonicalUrl: canonicalUrl,
    language: existingLanguage.isEmpty ? 'en' : existingLanguage,
    metaTags: [
      for (final tag in defaults.metaTags) _existingOrDefault(tag),
      if (canonicalUrl != null &&
          _existingMetaContent('property', 'og:url') == null)
        MetaTag.property('og:url', canonicalUrl),
    ],
  );
}

MetaTag _existingOrDefault(MetaTag fallback) {
  final content = _existingMetaContent(fallback.attribute, fallback.key);
  if (content == null) return fallback;
  return fallback.attribute == 'name'
      ? MetaTag.name(fallback.key, content)
      : MetaTag.property(fallback.key, content);
}

String? _existingMetaContent(String attribute, String key) {
  return web.document
      .querySelector('meta[$attribute="$key"]')
      ?.getAttribute('content');
}
