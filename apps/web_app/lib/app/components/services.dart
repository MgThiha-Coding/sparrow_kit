import 'package:web/web.dart' as web;

import 'package:sparrow_kit/core.dart' as dom;
import 'common.dart';

web.HTMLElement buildServices() => dom.element(
      'section',
      attributes: const {'class': 'services section-anchor', 'id': 'services'},
      children: [
        dom.element(
          'div',
          attributes: const {'class': 'shell'},
          children: [
            buildSectionHeading(
              eyebrow: 'What we bring',
              title: 'Good thinking. Better making.',
              description:
                  'From first sketch to final launch, we connect the dots between strategy, design, and technology.',
            ),
            dom.element(
              'div',
              attributes: const {'class': 'service-grid'},
              children: [
                _serviceCard(
                  number: '01',
                  title: 'Brand & strategy',
                  description:
                      'Find your focus, sharpen your story, and build a brand people can believe in.',
                  services: 'Positioning · Identity · Art direction',
                ),
                _serviceCard(
                  number: '02',
                  title: 'Digital experiences',
                  description:
                      'Turn complex ideas into intuitive websites and digital products.',
                  services: 'Websites · Product design · Prototyping',
                ),
                _serviceCard(
                  number: '03',
                  title: 'Commerce & content',
                  description:
                      'Create connected shopping and publishing experiences that keep moving.',
                  services: 'E-commerce · CMS · Campaigns',
                ),
              ],
            ),
          ],
        ),
      ],
    );

web.HTMLElement _serviceCard({
  required String number,
  required String title,
  required String description,
  required String services,
}) =>
    dom.element(
      'article',
      attributes: const {'class': 'service-card'},
      children: [
        dom.element(
          'div',
          attributes: const {'class': 'service-card-top'},
          children: [
            dom.element(
              'span',
              attributes: const {'class': 'service-number'},
              children: [number],
            ),
            dom.element(
              'span',
              attributes: const {
                'class': 'service-arrow',
                'aria-hidden': 'true',
              },
              children: const ['↗'],
            ),
          ],
        ),
        dom.element('h3', children: [title]),
        dom.element(
          'p',
          attributes: const {'class': 'service-description'},
          children: [description],
        ),
        dom.element(
          'p',
          attributes: const {'class': 'service-list'},
          children: [services],
        ),
      ],
    );
