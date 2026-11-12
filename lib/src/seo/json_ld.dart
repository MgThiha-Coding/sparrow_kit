abstract interface class JsonLdSchema {
  Map<String, Object?> toJsonLd();
}

class ProductJsonLd implements JsonLdSchema {
  const ProductJsonLd({
    required this.name,
    required this.description,
    required this.image,
    required this.sku,
    required this.price,
    required this.currency,
    required this.url,
    this.availability = 'https://schema.org/InStock',
  });

  final String name;
  final String description;
  final String image;
  final String sku;
  final num price;
  final String currency;
  final String url;
  final String availability;

  @override
  Map<String, Object?> toJsonLd() => {
        '@context': 'https://schema.org',
        '@type': 'Product',
        'name': name,
        'description': description,
        'image': image,
        'sku': sku,
        'offers': {
          '@type': 'Offer',
          'price': price,
          'priceCurrency': currency,
          'availability': availability,
          'url': url,
        },
      };
}

class ArticleJsonLd implements JsonLdSchema {
  const ArticleJsonLd({
    required this.headline,
    required this.description,
    required this.image,
    required this.datePublished,
    required this.author,
    required this.publisher,
    required this.url,
    this.dateModified,
  });

  final String headline;
  final String description;
  final String image;
  final String datePublished;
  final String? dateModified;
  final String author;
  final String publisher;
  final String url;

  @override
  Map<String, Object?> toJsonLd() => {
        '@context': 'https://schema.org',
        '@type': 'Article',
        'headline': headline,
        'description': description,
        'image': image,
        'datePublished': datePublished,
        if (dateModified != null) 'dateModified': dateModified,
        'author': {'@type': 'Person', 'name': author},
        'publisher': {'@type': 'Organization', 'name': publisher},
        'mainEntityOfPage': url,
      };
}
