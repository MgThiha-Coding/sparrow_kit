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
  })  : metaTags = List<MetaTag>.unmodifiable(metaTags),
        jsonLd = List<JsonLdSchema>.unmodifiable(jsonLd);

  final String title;
  final String? description;
  final String? canonicalUrl;
  final List<MetaTag> metaTags;
  final List<JsonLdSchema> jsonLd;
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
