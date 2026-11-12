import 'dart:async';

import 'package:sparrow_kit/core.dart' as core;
import 'package:web/web.dart' as web;

import '../../components/common.dart';
import '../../components/project_card.dart';
import 'portfolio_api.dart';
import 'portfolio_store.dart';

class PortfolioSection extends core.Component<void> {
  PortfolioSection()
      : _store = PortfolioStore(repository: PortfolioApi()),
        super(null);

  final PortfolioStore _store;

  @override
  web.Node render() {
    final categories = _store.categories;
    final selectedCategory = _store.selectedCategory.value;
    final projects = _store.visibleProjects;
    final isLoading = _store.isLoading.value;
    final error = _store.error.value;

    return core.element(
      'section',
      attributes: const {
        'class': 'portfolio section-anchor',
        'id': 'portfolio',
      },
      children: [
        core.element(
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
            core.element(
              'div',
              attributes: const {
                'class': 'portfolio-filters',
                'role': 'group',
                'aria-label': 'Filter projects by category',
              },
              children: categories
                  .map(
                    (category) => core.button(
                      attributes: {
                        'class': 'portfolio-filter',
                        'aria-pressed':
                            (category == selectedCategory).toString(),
                      },
                      children: [category],
                      onClick: (_) => _store.selectedCategory.value = category,
                    ),
                  )
                  .toList(growable: false),
            ),
            if (isLoading)
              core.p(
                attributes: const {
                  'class': 'portfolio-status',
                  'role': 'status',
                },
                children: const ['Loading selected work…'],
              ),
            if (error != null)
              core.div(
                classes: const ['portfolio-status', 'portfolio-error'],
                children: [
                  core.p(
                    attributes: const {'role': 'alert'},
                    children: ['Could not load selected work. $error'],
                  ),
                  core.button(
                    attributes: const {'class': 'portfolio-retry'},
                    children: const ['Retry'],
                    onClick: (_) => unawaited(_store.load()),
                  ),
                ],
              ),
            if (!isLoading && error == null && projects.isEmpty)
              core.p(
                attributes: const {
                  'class': 'portfolio-status',
                  'role': 'status',
                },
                children: const ['No projects match this category.'],
              ),
            core.element(
              'div',
              attributes: const {'class': 'project-grid'},
              children: projects
                  .map((project) => projectCard(project))
                  .toList(growable: false),
            ),
          ],
        ),
      ],
    );
  }

  @override
  void onMount() {
    unawaited(_store.load());
  }
}
