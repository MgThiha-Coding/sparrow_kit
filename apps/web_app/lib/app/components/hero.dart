import 'package:web/web.dart' as web;

import 'package:sparrow_kit/core.dart' as dom;
import 'common.dart';

web.HTMLElement buildHero() => dom.element(
      'section',
      attributes: const {'class': 'hero section-anchor', 'id': 'home'},
      children: [
        dom.element(
          'div',
          attributes: const {'class': 'hero-grid shell'},
          children: [
            dom.element(
              'div',
              attributes: const {'class': 'hero-copy'},
              children: [
                buildEyebrow('Independent creative company · Est. 2016'),
                dom.element(
                  'h1',
                  children: [
                    'Make your next ',
                    dom.element(
                      'span',
                      attributes: const {'class': 'text-accent'},
                      children: ['big thing'],
                    ),
                    ' your best thing.',
                  ],
                ),
                dom.element(
                  'p',
                  attributes: const {'class': 'hero-description'},
                  children: [
                    'We build brands, digital products, and experiences for people shaping what comes next.',
                  ],
                ),
                dom.element(
                  'div',
                  attributes: const {'class': 'hero-actions'},
                  children: [
                    buildPrimaryLink('Explore our work', '#portfolio'),
                    dom.element(
                      'a',
                      attributes: const {
                        'class': 'text-link',
                        'href': '#services',
                      },
                      children: const ['What we do', '↓'],
                    ),
                  ],
                ),
                dom.element(
                  'div',
                  attributes: const {'class': 'hero-proof'},
                  children: [
                    dom.element(
                      'span',
                      attributes: const {
                        'class': 'proof-dot',
                        'aria-hidden': 'true',
                      },
                    ),
                    dom.element(
                      'span',
                      children: const ['A small team for ambitious ideas'],
                    ),
                  ],
                ),
              ],
            ),
            _buildHeroArtwork(),
          ],
        ),
        dom.element(
          'div',
          attributes: const {'class': 'hero-bottom shell'},
          children: [
            dom.element(
              'span',
              children: const ['Selected work · 2022—2026'],
            ),
            dom.element('span', children: const ['Scroll to explore ↓']),
          ],
        ),
      ],
    );

web.HTMLElement _buildHeroArtwork() => dom.element(
      'div',
      attributes: const {'class': 'hero-artwork', 'aria-hidden': 'true'},
      children: [
        dom.element(
          'div',
          attributes: const {'class': 'art-orbit orbit-one'},
        ),
        dom.element(
          'div',
          attributes: const {'class': 'art-orbit orbit-two'},
        ),
        dom.element(
          'div',
          attributes: const {'class': 'art-card art-card-back'},
          children: [
            dom.element('span', children: const ['FORM / FUNCTION']),
            dom.element('strong', children: const ['Ideas in motion.']),
          ],
        ),
        dom.element(
          'div',
          attributes: const {'class': 'art-card art-card-front'},
          children: [
            dom.element(
              'span',
              attributes: const {'class': 'art-card-label'},
              children: const ['DIGITAL / CULTURE'],
            ),
            dom.element(
              'div',
              attributes: const {'class': 'art-shape'},
              children: [
                dom.element('span', children: const ['M']),
              ],
            ),
            dom.element(
              'div',
              attributes: const {'class': 'art-card-caption'},
              children: [
                dom.element('strong', children: const ['New perspective']),
                dom.element('span', children: const ['A study in contrast']),
              ],
            ),
          ],
        ),
        dom.element(
          'div',
          attributes: const {'class': 'art-sticker'},
          children: const ['TRUSTED DELIVERY'],
        ),
      ],
    );
