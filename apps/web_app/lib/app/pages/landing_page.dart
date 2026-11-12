import 'package:sparrow_kit/ssr.dart';

import '../features/portfolio/portfolio_project.dart';

const landingCategories = [
  'All',
  'Digital commerce',
  'Brand platform',
  'Culture & editorial',
];

const landingProjects = [
  PortfolioProject(
    id: '01',
    category: 'Digital commerce',
    title: 'Objects for everyday',
    description:
        'A clearer, more considered storefront for a new generation of makers.',
    artLabel: 'FORM',
    artCaption: 'Made to be kept.',
    theme: 'amber',
  ),
  PortfolioProject(
    id: '02',
    category: 'Brand platform',
    title: 'A brighter kind of energy',
    description:
        'A confident identity system built to move at the speed of change.',
    artLabel: 'VOLT',
    artCaption: 'Power your next.',
    theme: 'lilac',
  ),
  PortfolioProject(
    id: '03',
    category: 'Culture & editorial',
    title: 'Room for new voices',
    description:
        'An editorial experience that puts independent culture in focus.',
    artLabel: 'COMMON',
    artCaption: 'Culture, in good company.',
    theme: 'green',
  ),
];

String landingCategorySignalId(int index) => 'landing_category_$index';
String landingProjectHiddenSignalId(int index) =>
    'landing_project_${index}_hidden';

HeadMetadata companyLandingMetadata() => HeadMetadata(
      title: 'MyCompany | Independent Creative Company',
      description:
          'An independent creative company building thoughtful brands, digital products, and experiences for people shaping what comes next.',
      metaTags: [
        MetaTag.name('viewport', 'width=device-width, initial-scale=1'),
        MetaTag.name('theme-color', '#0b1220'),
        MetaTag.property('og:type', 'website'),
        MetaTag.property(
          'og:title',
          'MyCompany | Independent Creative Company',
        ),
        MetaTag.property(
          'og:description',
          'An independent creative company building thoughtful brands, digital products, and experiences for people shaping what comes next.',
        ),
        MetaTag.property('og:image', '/og-image.svg'),
        MetaTag.property('og:site_name', 'MyCompany'),
        MetaTag.name('twitter:card', 'summary_large_image'),
        MetaTag.name(
          'twitter:title',
          'MyCompany | Independent Creative Company',
        ),
        MetaTag.name(
          'twitter:description',
          'An independent creative company building thoughtful brands, digital products, and experiences for people shaping what comes next.',
        ),
        MetaTag.name('twitter:image', '/og-image.svg'),
      ],
    );

class LandingPageState {
  LandingPageState({
    required List<Signal<String>> categorySelection,
    required List<Signal<bool>> hiddenProjects,
  })  : categorySelection =
            List<Signal<String>>.unmodifiable(categorySelection),
        hiddenProjects = List<Signal<bool>>.unmodifiable(hiddenProjects) {
    if (this.categorySelection.length != landingCategories.length ||
        this.hiddenProjects.length != landingProjects.length) {
      throw ArgumentError('Landing page state does not match the page data.');
    }
  }

  factory LandingPageState.initial() => LandingPageState(
        categorySelection: [
          for (var index = 0; index < landingCategories.length; index++)
            Signal<String>(index == 0 ? 'true' : 'false'),
        ],
        hiddenProjects: [
          for (var index = 0; index < landingProjects.length; index++)
            Signal<bool>(false),
        ],
      );

  final List<Signal<String>> categorySelection;
  final List<Signal<bool>> hiddenProjects;

  void selectCategory(int selectedIndex) {
    if (selectedIndex < 0 || selectedIndex >= landingCategories.length) {
      throw RangeError.index(selectedIndex, landingCategories);
    }
    for (var index = 0; index < categorySelection.length; index++) {
      categorySelection[index].value =
          index == selectedIndex ? 'true' : 'false';
    }
    for (var index = 0; index < landingProjects.length; index++) {
      hiddenProjects[index].value = selectedIndex != 0 &&
          landingProjects[index].category != landingCategories[selectedIndex];
    }
  }
}

class CompanyLandingPage implements SsrComponent {
  CompanyLandingPage(this.state);

  final LandingPageState state;

  @override
  MarkupNode render() => _element(
        'div',
        children: [
          _element(
            'link',
            attributes: const {
              'rel': 'stylesheet',
              'href': '/landing.css',
            },
          ),
          _header(),
          _element(
            'main',
            attributes: const {'id': 'main-content'},
            children: [
              _hero(),
              _portfolio(),
              _services(),
              _contact(),
            ],
          ),
          _footer(),
        ],
      );

  MarkupElement _header() => _element(
        'header',
        attributes: const {'class': 'site-header'},
        children: [
          _element(
            'nav',
            attributes: const {
              'class': 'navbar shell',
              'aria-label': 'Main navigation',
            },
            children: [
              _element(
                'a',
                attributes: const {'class': 'brand', 'href': '#home'},
                children: [
                  _element(
                    'span',
                    attributes: const {
                      'class': 'brand-mark',
                      'aria-hidden': 'true',
                    },
                    children: [_text('M')],
                  ),
                  _element(
                    'span',
                    attributes: const {'class': 'brand-name'},
                    children: [_text('MYCOMPANY')],
                  ),
                ],
              ),
              _element(
                'div',
                attributes: const {'class': 'nav-links'},
                children: [
                  _link('Home', '#home'),
                  _link('Portfolio', '#portfolio'),
                  _link('Services', '#services'),
                  _link('Contact', '#contact'),
                ],
              ),
              _link(
                "Let's talk ↗",
                '#contact',
                className: 'nav-cta',
              ),
            ],
          ),
        ],
      );

  MarkupElement _hero() => _element(
        'section',
        attributes: const {'class': 'hero section-anchor', 'id': 'home'},
        children: [
          _element(
            'div',
            attributes: const {'class': 'hero-grid shell'},
            children: [
              _element(
                'div',
                attributes: const {'class': 'hero-copy'},
                children: [
                  _eyebrow('Independent creative company · Est. 2016'),
                  _element(
                    'h1',
                    children: [
                      _text('Make your next '),
                      _element(
                        'span',
                        attributes: const {'class': 'text-accent'},
                        children: [_text('big thing')],
                      ),
                      _text(' your best thing.'),
                    ],
                  ),
                  _element(
                    'p',
                    attributes: const {'class': 'hero-description'},
                    children: [
                      _text(
                        'We build brands, digital products, and experiences for people shaping what comes next.',
                      ),
                    ],
                  ),
                  _element(
                    'div',
                    attributes: const {'class': 'hero-actions'},
                    children: [
                      _primaryLink('Explore our work', '#portfolio'),
                      _textLink('What we do', '#services'),
                    ],
                  ),
                  _element(
                    'div',
                    attributes: const {'class': 'hero-proof'},
                    children: [
                      _element(
                        'span',
                        attributes: const {
                          'class': 'proof-dot',
                          'aria-hidden': 'true',
                        },
                      ),
                      _element(
                        'span',
                        children: [_text('A small team for ambitious ideas')],
                      ),
                    ],
                  ),
                ],
              ),
              _heroArtwork(),
            ],
          ),
          _element(
            'div',
            attributes: const {'class': 'hero-bottom shell'},
            children: [
              _element(
                'span',
                children: [_text('Selected work · 2022—2026')],
              ),
              _element('span', children: [_text('Scroll to explore ↓')]),
            ],
          ),
        ],
      );

  MarkupElement _heroArtwork() => _element(
        'div',
        attributes: const {'class': 'hero-artwork', 'aria-hidden': 'true'},
        children: [
          _element('div', attributes: const {'class': 'art-orbit orbit-one'}),
          _element('div', attributes: const {'class': 'art-orbit orbit-two'}),
          _element(
            'div',
            attributes: const {'class': 'art-card art-card-back'},
            children: [
              _element('span', children: [_text('FORM / FUNCTION')]),
              _element('strong', children: [_text('Ideas in motion.')]),
            ],
          ),
          _element(
            'div',
            attributes: const {'class': 'art-card art-card-front'},
            children: [
              _element(
                'span',
                attributes: const {'class': 'art-card-label'},
                children: [_text('DIGITAL / CULTURE')],
              ),
              _element(
                'div',
                attributes: const {'class': 'art-shape'},
                children: [
                  _element('span', children: [_text('M')]),
                ],
              ),
              _element(
                'div',
                attributes: const {'class': 'art-card-caption'},
                children: [
                  _element('strong', children: [_text('New perspective')]),
                  _element('span', children: [_text('A study in contrast')]),
                ],
              ),
            ],
          ),
          _element(
            'div',
            attributes: const {'class': 'art-sticker'},
            children: [_text('TRUSTED DELIVERY')],
          ),
        ],
      );

  MarkupElement _portfolio() => _element(
        'section',
        attributes: const {
          'class': 'portfolio section-anchor',
          'id': 'portfolio',
        },
        children: [
          _element(
            'div',
            attributes: const {'class': 'shell'},
            children: [
              _sectionHeading(
                eyebrow: 'A few good things',
                title: 'Work with a point of view.',
                description:
                    'Different challenges, shared intent: make useful things feel unforgettable.',
                trailing: _textLink(
                  'All projects',
                  'mailto:hello@mycompany.com',
                ),
              ),
              _element(
                'div',
                attributes: const {
                  'class': 'portfolio-filters',
                  'role': 'group',
                  'aria-label': 'Filter projects by category',
                },
                children: [
                  for (var index = 0; index < landingCategories.length; index++)
                    _element(
                      'button',
                      attributes: {
                        'type': 'button',
                        'class': 'portfolio-filter',
                        'aria-pressed': SignalAttribute(
                          landingCategorySignalId(index),
                          state.categorySelection[index],
                        ),
                      },
                      children: [_text(landingCategories[index])],
                      events: {
                        'click': (_) => state.selectCategory(index),
                      },
                    ),
                ],
              ),
              _element(
                'p',
                attributes: const {
                  'class': 'portfolio-status',
                  'role': 'status',
                },
                children: [_text('Selected work from across our practice.')],
              ),
              _element(
                'div',
                attributes: const {'class': 'project-grid'},
                children: [
                  for (var index = 0; index < landingProjects.length; index++)
                    _projectCard(index),
                ],
              ),
            ],
          ),
        ],
      );

  MarkupElement _projectCard(int index) {
    final project = landingProjects[index];
    return _element(
      'article',
      attributes: {
        'class': 'project-card',
        'hidden': SignalAttribute(
          landingProjectHiddenSignalId(index),
          state.hiddenProjects[index],
        ),
      },
      children: [
        _element(
          'div',
          attributes: {'class': 'project-art project-art-${project.theme}'},
          children: [
            _element(
              'span',
              attributes: const {'class': 'art-index'},
              children: [_text(project.id)],
            ),
            _element(
              'div',
              attributes: const {'class': 'project-art-object'},
              children: [_text(project.artLabel)],
            ),
            _element(
              'span',
              attributes: const {'class': 'project-art-caption'},
              children: [_text(project.artCaption)],
            ),
          ],
        ),
        _element(
          'div',
          attributes: const {'class': 'project-info'},
          children: [
            _element(
              'span',
              attributes: const {'class': 'project-category'},
              children: [_text(project.category)],
            ),
            _element(
              'h3',
              children: [
                _element(
                  'a',
                  attributes: const {'href': '#contact'},
                  children: [_text('${project.title} ↗')],
                ),
              ],
            ),
            _element(
              'p',
              attributes: const {'class': 'project-description'},
              children: [_text(project.description)],
            ),
          ],
        ),
      ],
    );
  }

  MarkupElement _services() => _element(
        'section',
        attributes: const {
          'class': 'services section-anchor',
          'id': 'services'
        },
        children: [
          _element(
            'div',
            attributes: const {'class': 'shell'},
            children: [
              _sectionHeading(
                eyebrow: 'What we bring',
                title: 'Good thinking. Better making.',
                description:
                    'From first sketch to final launch, we connect the dots between strategy, design, and technology.',
              ),
              _element(
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

  MarkupElement _serviceCard({
    required String number,
    required String title,
    required String description,
    required String services,
  }) =>
      _element(
        'article',
        attributes: const {'class': 'service-card'},
        children: [
          _element(
            'div',
            attributes: const {'class': 'service-card-top'},
            children: [
              _element(
                'span',
                attributes: const {'class': 'service-number'},
                children: [_text(number)],
              ),
              _element(
                'span',
                attributes: const {
                  'class': 'service-arrow',
                  'aria-hidden': 'true',
                },
                children: [_text('↗')],
              ),
            ],
          ),
          _element('h3', children: [_text(title)]),
          _element(
            'p',
            attributes: const {'class': 'service-description'},
            children: [_text(description)],
          ),
          _element(
            'p',
            attributes: const {'class': 'service-list'},
            children: [_text(services)],
          ),
        ],
      );

  MarkupElement _contact() => _element(
        'section',
        attributes: const {'class': 'contact section-anchor', 'id': 'contact'},
        children: [
          _element(
            'div',
            attributes: const {'class': 'contact-panel shell'},
            children: [
              _element(
                'div',
                attributes: const {'class': 'contact-copy'},
                children: [
                  _eyebrow('Have a good one in mind?'),
                  _element(
                    'h2',
                    children: [
                      _text("Let's make "),
                      _element(
                        'span',
                        attributes: const {'class': 'text-accent'},
                        children: [_text('something matter.')],
                      ),
                    ],
                  ),
                  _element(
                    'p',
                    attributes: const {'class': 'contact-description'},
                    children: [
                      _text(
                        "Tell us where you want to go. We'll bring thoughtful questions and a fresh pot of coffee.",
                      ),
                    ],
                  ),
                ],
              ),
              _element(
                'div',
                attributes: const {'class': 'contact-action'},
                children: [
                  _primaryLink(
                    'Start a conversation',
                    'mailto:hello@mycompany.com',
                  ),
                  _element(
                    'span',
                    attributes: const {'class': 'contact-email'},
                    children: [_text('hello@mycompany.com')],
                  ),
                ],
              ),
            ],
          ),
        ],
      );

  MarkupElement _footer() => _element(
        'footer',
        attributes: const {'class': 'site-footer'},
        children: [
          _element(
            'div',
            attributes: const {'class': 'shell'},
            children: [
              _element(
                'div',
                attributes: const {'class': 'footer-main'},
                children: [
                  _element(
                    'div',
                    attributes: const {'class': 'footer-about'},
                    children: [
                      _element(
                        'a',
                        attributes: const {
                          'class': 'brand footer-brand',
                          'href': '#home',
                        },
                        children: [
                          _element(
                            'span',
                            attributes: const {
                              'class': 'brand-mark',
                              'aria-hidden': 'true',
                            },
                            children: [_text('M')],
                          ),
                          _element(
                            'span',
                            attributes: const {'class': 'brand-name'},
                            children: [_text('MYCOMPANY')],
                          ),
                        ],
                      ),
                      _element(
                        'p',
                        attributes: const {'class': 'footer-summary'},
                        children: [
                          _text(
                            'An independent creative company building thoughtful brands and digital experiences.',
                          ),
                        ],
                      ),
                    ],
                  ),
                  _element(
                    'div',
                    attributes: const {'class': 'footer-links-group'},
                    children: [
                      _element(
                        'h2',
                        attributes: const {'class': 'footer-heading'},
                        children: [_text('Explore')],
                      ),
                      _footerLink('Home', '#home'),
                      _footerLink('Portfolio', '#portfolio'),
                      _footerLink('Services', '#services'),
                      _footerLink('Contact', '#contact'),
                    ],
                  ),
                  _element(
                    'div',
                    attributes: const {'class': 'footer-links-group'},
                    children: [
                      _element(
                        'h2',
                        attributes: const {'class': 'footer-heading'},
                        children: [_text('Say hello')],
                      ),
                      _footerLink(
                        'Email us ↗',
                        'mailto:hello@mycompany.com',
                      ),
                      _element(
                        'span',
                        attributes: const {'class': 'footer-location'},
                        children: [_text('Brooklyn, NY · Working everywhere')],
                      ),
                    ],
                  ),
                ],
              ),
              _element(
                'div',
                attributes: const {'class': 'footer-bottom'},
                children: [
                  _element(
                    'span',
                    children: [_text('© 2026 MyCompany. All Rights Reserved.')],
                  ),
                  _element('span', children: [_text('Made with intention.')]),
                ],
              ),
            ],
          ),
        ],
      );
}

MarkupElement _sectionHeading({
  required String eyebrow,
  required String title,
  required String description,
  MarkupElement? trailing,
}) =>
    _element(
      'div',
      attributes: const {'class': 'section-heading'},
      children: [
        _element(
          'div',
          children: [
            _eyebrow(eyebrow),
            _element('h2', children: [_text(title)]),
            _element(
              'p',
              attributes: const {'class': 'section-description'},
              children: [_text(description)],
            ),
          ],
        ),
        if (trailing != null) trailing,
      ],
    );

MarkupElement _eyebrow(String text) => _element(
      'p',
      attributes: const {'class': 'eyebrow'},
      children: [_text(text)],
    );

MarkupElement _primaryLink(String text, String href) => _link(
      '$text ↗',
      href,
      className: 'button button-primary',
    );

MarkupElement _textLink(String text, String href) => _link(
      '$text ↗',
      href,
      className: 'text-link',
    );

MarkupElement _footerLink(String text, String href) => _link(
      text,
      href,
      className: 'footer-link',
    );

MarkupElement _link(String text, String href, {String? className}) => _element(
      'a',
      attributes: {
        if (className != null) 'class': className,
        'href': href,
      },
      children: [_text(text)],
    );

MarkupElement _element(
  String tag, {
  Map<String, Object?> attributes = const {},
  Iterable<MarkupNode> children = const [],
  Map<String, MarkupEventHandler> events = const {},
}) =>
    MarkupElement(
      tag,
      attributes: attributes,
      children: children,
      events: events,
    );

MarkupText _text(String text) => MarkupText(text);
