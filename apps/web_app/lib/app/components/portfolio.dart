import 'package:web/web.dart' as web;

import 'package:sparrow_kit/core.dart' as dom;
import 'common.dart';

web.HTMLElement buildPortfolio() => dom.element(
      'section',
      attributes: const {
        'class': 'portfolio section-anchor',
        'id': 'portfolio',
      },
      children: [
        dom.element(
          'div',
          attributes: const {'class': 'shell'},
          children: [
            buildSectionHeading(
              eyebrow: 'A few good things',
              title: 'Work with a point of view.',
              description:
                  'Different challenges, shared intent: make useful things feel unforgettable.',
              trailing: buildTextLink(
                'All projects',
                'mailto:hello@mycompany.com',
              ),
            ),
            dom.element(
              'div',
              attributes: const {'class': 'project-grid'},
              children: [
                _projectCard(
                  number: '01',
                  category: 'DIGITAL COMMERCE',
                  title: 'Objects for everyday',
                  description:
                      'A clearer, more considered storefront for a new generation of makers.',
                  artworkClass: 'project-art-amber',
                  artLabel: 'FORM',
                  artCaption: 'Made to be kept.',
                ),
                _projectCard(
                  number: '02',
                  category: 'BRAND PLATFORM',
                  title: 'A brighter kind of energy',
                  description:
                      'A confident identity system built to move at the speed of change.',
                  artworkClass: 'project-art-lilac',
                  artLabel: 'VOLT',
                  artCaption: 'Power your next.',
                ),
                _projectCard(
                  number: '03',
                  category: 'CULTURE & EDITORIAL',
                  title: 'Room for new voices',
                  description:
                      'An editorial experience that puts independent culture in focus.',
                  artworkClass: 'project-art-green',
                  artLabel: 'COMMON',
                  artCaption: 'Culture, in good company.',
                ),
              ],
            ),
          ],
        ),
      ],
    );

web.HTMLElement _projectCard({
  required String number,
  required String category,
  required String title,
  required String description,
  required String artworkClass,
  required String artLabel,
  required String artCaption,
}) =>
    dom.element(
      'article',
      attributes: const {'class': 'project-card'},
      children: [
        dom.element(
          'div',
          attributes: {'class': 'project-art $artworkClass'},
          children: [
            dom.element(
              'span',
              attributes: const {'class': 'art-index'},
              children: [number],
            ),
            dom.element(
              'div',
              attributes: const {'class': 'project-art-object'},
              children: [artLabel],
            ),
            dom.element(
              'span',
              attributes: const {'class': 'project-art-caption'},
              children: [artCaption],
            ),
          ],
        ),
        dom.element(
          'div',
          attributes: const {'class': 'project-info'},
          children: [
            dom.element(
              'span',
              attributes: const {'class': 'project-category'},
              children: [category],
            ),
            dom.element(
              'h3',
              children: [
                dom.element(
                  'a',
                  attributes: const {'href': '#contact'},
                  children: [title, ' ↗'],
                ),
              ],
            ),
            dom.element(
              'p',
              attributes: const {'class': 'project-description'},
              children: [description],
            ),
          ],
        ),
      ],
    );
