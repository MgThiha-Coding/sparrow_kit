import 'json_ld.dart';

class MetaTag {
  const MetaTag._({
    required this.attribute,
    required this.key,
    required this.content,
  });

  factory MetaTag.name(String name, String content) {
    return MetaTag._(attribute: 'name', key: name, content: content);
  }

  factory MetaTag.property(String property, String content) {
    return MetaTag._(attribute: 'property', key: property, content: content);
  }

  final String attribute;
  final String key;
  final String content;

  String get id => '$attribute:$key';
}

class HeadMetadata {
  HeadMetadata({
    required this.title,
    this.description,
    this.canonicalUrl,
    Iterable<MetaTag> metaTags = const [],
    Iterable<JsonLdSchema> jsonLd = const [],
    this.openGraph,
    this.twitterCard,
    this.robots,
    this.language = 'en',
    this.locale,
  })  : metaTags = List<MetaTag>.unmodifiable(metaTags),
        jsonLd = List<JsonLdSchema>.unmodifiable(jsonLd) {
    if (language.trim().isEmpty) {
      throw ArgumentError.value(language, 'language', 'Cannot be empty.');
    }
    if (locale != null && locale!.trim().isEmpty) {
      throw ArgumentError.value(locale, 'locale', 'Cannot be empty.');
    }
  }

  final String title;
  final String? description;
  final String? canonicalUrl;
  final List<MetaTag> metaTags;
  final List<JsonLdSchema> jsonLd;
  final OpenGraphMetadata? openGraph;
  final TwitterCardMetadata? twitterCard;
  final RobotsDirectives? robots;
  final String language;
  final String? locale;

  List<MetaTag> get renderedMetaTags {
    if (openGraph == null &&
        twitterCard == null &&
        robots == null &&
        locale == null) {
      return metaTags;
    }

    final tags = <String, MetaTag>{};
    for (final tag in metaTags) {
      tags[tag.id] = tag;
    }
    for (final tag in openGraph?.toMetaTags() ?? const <MetaTag>[]) {
      tags[tag.id] = tag;
    }
    for (final tag in twitterCard?.toMetaTags() ?? const <MetaTag>[]) {
      tags[tag.id] = tag;
    }
    if (robots != null) {
      final tag = MetaTag.name('robots', robots!.toMetaContent());
      tags[tag.id] = tag;
    }
    if (locale != null) {
      final tag = MetaTag.property('og:locale', locale!);
      tags[tag.id] = tag;
    }
    return List<MetaTag>.unmodifiable(tags.values);
  }

  factory HeadMetadata.defaults({
    String title = 'SparrowKit Application',
    String description = 'A web application built with SparrowKit.',
  }) {
    return HeadMetadata(
      title: title,
      description: description,
      metaTags: [
        MetaTag.property('og:title', title),
        MetaTag.property('og:type', 'website'),
        MetaTag.property('og:description', description),
        MetaTag.name('twitter:card', 'summary'),
        MetaTag.name('twitter:title', title),
        MetaTag.name('twitter:description', description),
      ],
    );
  }
}

class OpenGraphMetadata {
  const OpenGraphMetadata({
    required this.title,
    required this.type,
    required this.url,
    required this.image,
    this.description,
    this.siteName,
  });

  final String title;
  final String type;
  final String url;
  final String image;
  final String? description;
  final String? siteName;

  List<MetaTag> toMetaTags() => [
        MetaTag.property('og:title', title),
        MetaTag.property('og:type', type),
        MetaTag.property('og:url', url),
        MetaTag.property('og:image', image),
        if (description != null)
          MetaTag.property('og:description', description!),
        if (siteName != null) MetaTag.property('og:site_name', siteName!),
      ];
}

class RobotsDirectives {
  const RobotsDirectives({
    this.index = true,
    this.follow = true,
    this.archive = true,
    this.snippets = true,
    this.imageIndex = true,
  });

  final bool index;
  final bool follow;
  final bool archive;
  final bool snippets;
  final bool imageIndex;

  RobotsDirectives copyWith({
    bool? index,
    bool? follow,
    bool? archive,
    bool? snippets,
    bool? imageIndex,
  }) =>
      RobotsDirectives(
        index: index ?? this.index,
        follow: follow ?? this.follow,
        archive: archive ?? this.archive,
        snippets: snippets ?? this.snippets,
        imageIndex: imageIndex ?? this.imageIndex,
      );

  String toMetaContent() => [
        index ? 'index' : 'noindex',
        follow ? 'follow' : 'nofollow',
        if (!archive) 'noarchive',
        if (!snippets) 'nosnippet',
        if (!imageIndex) 'noimageindex',
      ].join(', ');
}

class TwitterCardMetadata {
  const TwitterCardMetadata({
    required this.card,
    required this.title,
    this.description,
    this.image,
    this.site,
    this.creator,
  });

  final String card;
  final String title;
  final String? description;
  final String? image;
  final String? site;
  final String? creator;

  List<MetaTag> toMetaTags() => [
        MetaTag.name('twitter:card', card),
        MetaTag.name('twitter:title', title),
        if (description != null)
          MetaTag.name('twitter:description', description!),
        if (image != null) MetaTag.name('twitter:image', image!),
        if (site != null) MetaTag.name('twitter:site', site!),
        if (creator != null) MetaTag.name('twitter:creator', creator!),
      ];
}
