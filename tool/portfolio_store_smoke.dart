import 'package:web_app/app/features/portfolio/portfolio_project.dart';
import 'package:web_app/app/features/portfolio/portfolio_store.dart';

void main() async {
  final decodedProject = PortfolioProject.fromJson({
    'id': '01',
    'category': 'Digital commerce',
    'title': 'Objects for everyday',
    'description': 'A considered storefront.',
    'artLabel': 'FORM',
    'artCaption': 'Made to be kept.',
    'theme': 'amber',
  });
  _expect(
    decodedProject.theme == 'amber',
    'project JSON should be parsed into a typed model',
  );
  try {
    PortfolioProject.fromJson({'theme': 'unexpected'});
    throw StateError('invalid project data should be rejected');
  } on FormatException {
    // Expected validation failure.
  }

  final repository = _FakePortfolioRepository([
    _project('01', 'Digital commerce'),
    _project('02', 'Brand platform'),
  ]);
  final store = PortfolioStore(repository: repository);

  await store.load();
  _expect(!store.isLoading.value, 'successful load should finish loading');
  _expect(store.error.value == null, 'successful load should clear errors');
  _expect(store.projects.value.length == 2, 'projects should be stored');
  _expect(
    store.categories.join(',') == 'All,Digital commerce,Brand platform',
    'categories should follow project order',
  );

  store.selectedCategory.value = 'Brand platform';
  _expect(
    store.visibleProjects.single.id == '02',
    'category selection should filter projects',
  );

  final failedStore = PortfolioStore(
    repository: _FakePortfolioRepository.failure(
      const PortfolioApiException('Unavailable'),
    ),
  );
  await failedStore.load();
  _expect(
    !failedStore.isLoading.value && failedStore.error.value == 'Unavailable',
    'API failures should become visible store errors',
  );
}

PortfolioProject _project(String id, String category) => PortfolioProject(
      id: id,
      category: category,
      title: 'Project $id',
      description: 'Description $id',
      artLabel: 'ART',
      artCaption: 'Caption',
      theme: 'amber',
    );

class _FakePortfolioRepository implements PortfolioRepository {
  _FakePortfolioRepository(this.projects) : _error = null;

  _FakePortfolioRepository.failure(PortfolioApiException error)
      : projects = const [],
        _error = error;

  final List<PortfolioProject> projects;
  final PortfolioApiException? _error;

  @override
  Future<List<PortfolioProject>> fetchProjects() async {
    final error = _error;
    if (error != null) throw error;
    return projects;
  }
}

void _expect(bool condition, String message) {
  if (!condition) throw StateError(message);
}
