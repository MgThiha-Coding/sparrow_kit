import 'package:web/web.dart' as web;

import 'package:sparrow_kit/core.dart' as dom;

web.HTMLElement buildFooter() => dom.element(
      'footer',
      attributes: const {'class': 'site-footer'},
      children: [
        dom.element(
          'div',
          attributes: const {'class': 'shell'},
          children: [
            dom.element(
              'div',
              attributes: const {'class': 'footer-main'},
              children: [
                dom.element(
                  'div',
                  attributes: const {'class': 'footer-about'},
                  children: [
                    dom.element(
                      'a',
                      attributes: const {
                        'class': 'brand footer-brand',
                        'href': '#home',
                      },
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
                      'p',
                      attributes: const {'class': 'footer-summary'},
                      children: const [
                        'An independent creative company building thoughtful brands and digital experiences.',
                      ],
                    ),
                  ],
                ),
                dom.element(
                  'div',
                  attributes: const {'class': 'footer-links-group'},
                  children: [
                    dom.element(
                      'h2',
                      attributes: const {'class': 'footer-heading'},
                      children: const ['Explore'],
                    ),
                    _footerLink('Home', '#home'),
                    _footerLink('Portfolio', '#portfolio'),
                    _footerLink('Services', '#services'),
                    _footerLink('Contact', '#contact'),
                  ],
                ),
                dom.element(
                  'div',
                  attributes: const {'class': 'footer-links-group'},
                  children: [
                    dom.element(
                      'h2',
                      attributes: const {'class': 'footer-heading'},
                      children: const ['Say hello'],
                    ),
                    _footerLink('Email us ↗', 'mailto:hello@mycompany.com'),
                    dom.element(
                      'span',
                      attributes: const {'class': 'footer-location'},
                      children: const ['Brooklyn, NY · Working everywhere'],
                    ),
                  ],
                ),
              ],
            ),
            dom.element(
              'div',
              attributes: const {'class': 'footer-bottom'},
              children: [
                dom.element(
                  'span',
                  children: const ['© 2026 MyCompany. All Rights Reserved.'],
                ),
                dom.element(
                  'span',
                  children: const ['Made with intention.'],
                ),
              ],
            ),
          ],
        ),
      ],
    );

web.HTMLElement _footerLink(String label, String href) => dom.element(
      'a',
      attributes: {'class': 'footer-link', 'href': href},
      children: [label],
    );
