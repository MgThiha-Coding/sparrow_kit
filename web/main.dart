import 'package:web/web.dart' as web;

import '../lib/src/dsl/html.dart';
import '../lib/src/reactivity/signals.dart';
import '../lib/src/runtime/component.dart';
import '../lib/src/seo/head_manager.dart';
import '../lib/src/seo/json_ld.dart';
import '../lib/src/seo/metadata.dart';

class Product {
  const Product({
    required this.name,
    required this.description,
    required this.imageUrl,
    required this.sku,
    required this.price,
    required this.slug,
  });

  final String name;
  final String description;
  final String imageUrl;
  final String sku;
  final double price;
  final String slug;
}

class ProductDetailPage extends Component<void> {
  ProductDetailPage() : super(null);

  static const _initialProduct = Product(
    name: 'Aurora Wireless Headphones',
    description:
        'Comfortable wireless headphones with clear sound and all-day battery life.',
    imageUrl: 'https://example.com/images/aurora-headphones.jpg',
    sku: 'AUR-100',
    price: 129.99,
    slug: 'aurora-headphones',
  );

  static const _alternateProduct = Product(
    name: 'Summit Trail Backpack',
    description:
        'A durable lightweight backpack designed for day hikes and weekend trips.',
    imageUrl: 'https://example.com/images/summit-backpack.jpg',
    sku: 'SUM-220',
    price: 84.50,
    slug: 'summit-trail-backpack',
  );

  final HeadManager _headManager = HeadManager();
  final Signal<Product> _product = Signal<Product>(_initialProduct);

  @override
  web.Node render() {
    final product = _product.value;

    return element(
      'main',
      classes: const ['product-page'],
      styles: const {
        'font-family': 'system-ui, sans-serif',
        'max-width': '42rem',
        'margin': '3rem auto',
      },
      children: [
        h1(children: ['${product.name} | Example Store']),
        element(
          'img',
          attributes: {
            'src': product.imageUrl,
            'alt': product.name,
            'width': '640',
          },
          styles: const {'max-width': '100%', 'height': 'auto'},
        ),
        p(children: [product.description]),
        p(children: ['Price: \$${product.price.toStringAsFixed(2)}']),
        p(children: ['SKU: ${product.sku}']),
        button(
          children: const ['View another product'],
          onClick: (_) {
            _product.value = _product.value.sku == _alternateProduct.sku
                ? _initialProduct
                : _alternateProduct;
          },
        ),
      ],
    );
  }

  @override
  void onMount() {
    _headManager.watch(() {
      final product = _product.value;
      final url = 'https://example.com/products/${product.slug}';

      return HeadMetadata(
        title: '${product.name} | Example Store',
        description: product.description,
        canonicalUrl: url,
        metaTags: [
          ...OpenGraphMetadata(
            title: product.name,
            type: 'product',
            url: url,
            image: product.imageUrl,
            description: product.description,
            siteName: 'Example Store',
          ).toMetaTags(),
          ...TwitterCardMetadata(
            card: 'summary_large_image',
            title: product.name,
            description: product.description,
            image: product.imageUrl,
            site: '@examplestore',
          ).toMetaTags(),
        ],
        jsonLd: [
          ProductJsonLd(
            name: product.name,
            description: product.description,
            image: product.imageUrl,
            sku: product.sku,
            price: product.price,
            currency: 'USD',
            url: url,
          ),
        ],
      );
    });
  }

  @override
  void onDispose() {
    _headManager.dispose();
  }
}

void main() {
  ProductDetailPage().mount('#app');
}
