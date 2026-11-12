import 'package:sparrow_kit/core.dart' as core;

import '../features/portfolio/portfolio_project.dart';

final projectCard = core.component<PortfolioProject>((_, project) {
  return core.element(
    'article',
    attributes: const {'class': 'project-card'},
    children: [
      core.element(
        'div',
        attributes: {'class': 'project-art project-art-${project.theme}'},
        children: [
          core.element(
            'span',
            attributes: const {'class': 'art-index'},
            children: [project.id],
          ),
          core.element(
            'div',
            attributes: const {'class': 'project-art-object'},
            children: [project.artLabel],
          ),
          core.element(
            'span',
            attributes: const {'class': 'project-art-caption'},
            children: [project.artCaption],
          ),
        ],
      ),
      core.element(
        'div',
        attributes: const {'class': 'project-info'},
        children: [
          core.element(
            'span',
            attributes: const {'class': 'project-category'},
            children: [project.category],
          ),
          core.element(
            'h3',
            children: [
              core.element(
                'a',
                attributes: const {'href': '#contact'},
                children: [project.title, ' ↗'],
              ),
            ],
          ),
          core.element(
            'p',
            attributes: const {'class': 'project-description'},
            children: [project.description],
          ),
        ],
      ),
    ],
  );
});
