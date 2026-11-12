import 'package:web/web.dart' as web;

import 'package:sparrow_kit/core.dart' as dom;

web.HTMLElement buildEyebrow(String text) => dom.element(
      'p',
      attributes: const {'class': 'eyebrow'},
      children: [text],
    );

web.HTMLElement buildSectionHeading({
  required String eyebrow,
  required String title,
  required String description,
  web.Node? trailing,
}) =>
    dom.element(
      'div',
      attributes: const {'class': 'section-heading'},
      children: [
        dom.element(
          'div',
          children: [
            buildEyebrow(eyebrow),
            dom.element('h2', children: [title]),
            dom.element(
              'p',
              attributes: const {'class': 'section-description'},
              children: [description],
            ),
          ],
        ),
        if (trailing != null) trailing,
      ],
    );

web.HTMLElement buildPrimaryLink(String text, String href) => dom.element(
      'a',
      attributes: {'class': 'button button-primary', 'href': href},
      children: [text, ' ↗'],
    );

web.HTMLElement buildTextLink(String text, String href) => dom.element(
      'a',
      attributes: {'class': 'text-link', 'href': href},
      children: [text, ' ↗'],
    );
