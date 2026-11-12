import 'dart:convert';

import 'package:web/web.dart' as web;

import '../../reactivity/signals.dart';
import 'json_ld.dart';
import 'metadata.dart';

export 'metadata.dart' show HeadMetadata;

class HeadManager {
  HeadManager()
      : _originalTitle = web.document.title,
        _originalLanguage = web.document.documentElement?.getAttribute('lang');

  final String _originalTitle;
  final String? _originalLanguage;
  final Map<String, _MetaBinding> _metaBindings = {};
  final List<web.HTMLScriptElement> _jsonLdScripts = [];
  _LinkBinding? _canonicalBinding;
  void Function()? _watchDisposer;
  bool _isDisposed = false;

  void Function() watch(HeadMetadata Function() build) {
    if (_isDisposed) {
      throw StateError('A disposed head manager cannot bind metadata.');
    }
    if (_watchDisposer != null) {
      throw StateError('A head manager can only have one metadata binding.');
    }

    final disposer = effect(() => apply(build()));
    _watchDisposer = disposer;
    return () {
      if (identical(_watchDisposer, disposer)) {
        _watchDisposer = null;
        disposer();
      }
    };
  }

  void apply(HeadMetadata metadata) {
    if (_isDisposed) {
      throw StateError('A disposed head manager cannot update metadata.');
    }

    final head = web.document.head;
    if (head == null) {
      throw StateError('The document has no head element.');
    }
    final documentElement = web.document.documentElement;
    if (documentElement == null) {
      throw StateError('The document has no root element.');
    }

    web.document.title = metadata.title;
    documentElement.setAttribute('lang', metadata.language);
    _applyCanonical(head, metadata.canonicalUrl);
    _applyMetaTags(head, metadata);
    _applyJsonLd(head, metadata.jsonLd);
  }

  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;

    _watchDisposer?.call();
    _watchDisposer = null;

    for (final binding in _metaBindings.values) {
      _restoreMeta(binding);
    }
    _metaBindings.clear();

    final canonical = _canonicalBinding;
    if (canonical != null) {
      _restoreCanonical(canonical);
      _canonicalBinding = null;
    }

    for (final script in _jsonLdScripts) {
      script.remove();
    }
    _jsonLdScripts.clear();
    web.document.title = _originalTitle;
    final documentElement = web.document.documentElement;
    if (documentElement != null) {
      final originalLanguage = _originalLanguage;
      if (originalLanguage == null) {
        documentElement.removeAttribute('lang');
      } else {
        documentElement.setAttribute('lang', originalLanguage);
      }
    }
  }

  void _applyMetaTags(web.HTMLHeadElement head, HeadMetadata metadata) {
    final desired = <String, MetaTag>{};
    final description = metadata.description;
    if (description != null) {
      final tag = MetaTag.name('description', description);
      desired[tag.id] = tag;
    }
    for (final tag in metadata.renderedMetaTags) {
      desired[tag.id] = tag;
    }

    for (final entry in _metaBindings.entries.toList()) {
      if (!desired.containsKey(entry.key)) {
        _restoreMeta(entry.value);
        _metaBindings.remove(entry.key);
      }
    }

    for (final entry in desired.entries) {
      final binding = _metaBindings.putIfAbsent(
        entry.key,
        () => _createMetaBinding(head, entry.value),
      );
      binding.element.setAttribute('content', entry.value.content);
    }
  }

  _MetaBinding _createMetaBinding(web.HTMLHeadElement head, MetaTag tag) {
    final metas = head.querySelectorAll('meta');
    for (var index = 0; index < metas.length; index++) {
      final node = metas.item(index);
      if (node is web.HTMLMetaElement &&
          node.getAttribute(tag.attribute) == tag.key) {
        return _MetaBinding(
          element: node,
          originalContent: node.getAttribute('content'),
          isCreated: false,
        );
      }
    }

    final element = web.document.createElement('meta') as web.HTMLMetaElement;
    element.setAttribute(tag.attribute, tag.key);
    head.appendChild(element);
    return _MetaBinding(element: element, isCreated: true);
  }

  void _restoreMeta(_MetaBinding binding) {
    if (binding.isCreated) {
      binding.element.remove();
    } else {
      final originalContent = binding.originalContent;
      if (originalContent == null) {
        binding.element.removeAttribute('content');
      } else {
        binding.element.setAttribute('content', originalContent);
      }
    }
  }

  void _applyCanonical(web.HTMLHeadElement head, String? canonicalUrl) {
    if (canonicalUrl == null) {
      final binding = _canonicalBinding;
      if (binding != null) {
        _restoreCanonical(binding);
        _canonicalBinding = null;
      }
      return;
    }

    final binding = _canonicalBinding ??= _createCanonicalBinding(head);
    binding.element.href = canonicalUrl;
  }

  _LinkBinding _createCanonicalBinding(web.HTMLHeadElement head) {
    final existing = head.querySelector('link[rel="canonical"]');
    if (existing is web.HTMLLinkElement) {
      return _LinkBinding(
        element: existing,
        originalHref: existing.getAttribute('href'),
        isCreated: false,
      );
    }

    final element = web.document.createElement('link') as web.HTMLLinkElement;
    element.rel = 'canonical';
    head.appendChild(element);
    return _LinkBinding(element: element, isCreated: true);
  }

  void _restoreCanonical(_LinkBinding binding) {
    if (binding.isCreated) {
      binding.element.remove();
    } else {
      final originalHref = binding.originalHref;
      if (originalHref == null) {
        binding.element.removeAttribute('href');
      } else {
        binding.element.setAttribute('href', originalHref);
      }
    }
  }

  void _applyJsonLd(
    web.HTMLHeadElement head,
    List<JsonLdSchema> schemas,
  ) {
    for (var index = 0; index < schemas.length; index++) {
      if (index == _jsonLdScripts.length) {
        final script =
            web.document.createElement('script') as web.HTMLScriptElement;
        script.type = 'application/ld+json';
        head.appendChild(script);
        _jsonLdScripts.add(script);
      }
      _jsonLdScripts[index].textContent = jsonEncode(
        schemas[index].toJsonLd(),
      );
    }

    while (_jsonLdScripts.length > schemas.length) {
      _jsonLdScripts.removeLast().remove();
    }
  }
}

class _MetaBinding {
  _MetaBinding({
    required this.element,
    required this.isCreated,
    this.originalContent,
  });

  final web.HTMLMetaElement element;
  final String? originalContent;
  final bool isCreated;
}

class _LinkBinding {
  _LinkBinding({
    required this.element,
    required this.isCreated,
    this.originalHref,
  });

  final web.HTMLLinkElement element;
  final String? originalHref;
  final bool isCreated;
}
