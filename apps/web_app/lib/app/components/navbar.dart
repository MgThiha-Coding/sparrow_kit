import 'package:web/web.dart' as web;

import 'package:sparrow_kit/core.dart' as dom;

web.HTMLElement buildNavbar() => dom.element(
      'header',
      attributes: const {'class': 'site-header'},
      children: [
        dom.element(
          'nav',
          attributes: const {
            'class': 'navbar shell',
            'aria-label': 'Main navigation',
          },
          children: [
            dom.element(
              'a',
              attributes: const {'class': 'brand', 'href': '#home'},
              children: [
                dom.element(
                  'span',
                  attributes: const {
                    'class': 'brand-mark',
                    'aria-hidden': 'true',
                  },
                  children: const ['M'],
                ),
                dom.element(
                  'span',
                  attributes: const {'class': 'brand-name'},
                  children: const ['MYCOMPANY'],
                ),
              ],
            ),
            dom.element(
              'div',
              attributes: const {'class': 'nav-links'},
              children: [
                _navLink('Home', '#home'),
                _navLink('Portfolio', '#portfolio'),
                _navLink('Services', '#services'),
                _navLink('Contact', '#contact'),
              ],
            ),
            dom.element(
              'a',
              attributes: const {'class': 'nav-cta', 'href': '#contact'},
              children: const ['Let’s talk', '↗'],
            ),
          ],
        ),
      ],
    );

web.HTMLElement _navLink(String label, String href) => dom.element(
      'a',
      attributes: {'href': href},
      children: [label],
    );
