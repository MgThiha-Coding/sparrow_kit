import 'package:web/web.dart' as web;

import 'package:sparrow_kit/core.dart' as dom;
import 'common.dart';

web.HTMLElement buildContact() => dom.element(
      'section',
      attributes: const {'class': 'contact section-anchor', 'id': 'contact'},
      children: [
        dom.element(
          'div',
          attributes: const {'class': 'contact-panel shell'},
          children: [
            dom.element(
              'div',
              attributes: const {'class': 'contact-copy'},
              children: [
                buildEyebrow('Have a good one in mind?'),
                dom.element(
                  'h2',
                  children: [
                    'Let’s make ',
                    dom.element(
                      'span',
                      attributes: const {'class': 'text-accent'},
                      children: ['something matter.'],
                    ),
                  ],
                ),
                dom.element(
                  'p',
                  attributes: const {'class': 'contact-description'},
                  children: const [
                    'Tell us where you want to go. We’ll bring thoughtful questions and a fresh pot of coffee.',
                  ],
                ),
              ],
            ),
            dom.element(
              'div',
              attributes: const {'class': 'contact-action'},
              children: [
                buildPrimaryLink(
                  'Start a conversation',
                  'mailto:hello@mycompany.com',
                ),
                dom.element(
                  'span',
                  attributes: const {'class': 'contact-email'},
                  children: const ['hello@mycompany.com'],
                ),
              ],
            ),
          ],
        ),
      ],
    );
