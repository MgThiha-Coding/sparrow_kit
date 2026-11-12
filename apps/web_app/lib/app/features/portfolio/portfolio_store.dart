import 'package:sparrow_kit/reactivity.dart';

import 'portfolio_project.dart';

class PortfolioStore {
  PortfolioStore({required PortfolioRepository repository})
      : _repository = repository;

  final PortfolioRepository _repository;
  final Signal<List<PortfolioProject>> projects =
      Signal<List<PortfolioProject>>([]);
  final Signal<String> selectedCategory = Signal<String>('All');
  final Signal<bool> isLoading = Signal<bool>(true);
  final Signal<String?> error = Signal<String?>(null);

  List<String> get categories {
    final values = <String>{'All'};
    for (final project in projects.value) {
      values.add(project.category);
    }
    return List<String>.unmodifiable(values);
  }

  List<PortfolioProject> get visibleProjects {
    final selected = selectedCategory.value;
    final allProjects = projects.value;
    if (selected == 'All') return allProjects;
    return List<PortfolioProject>.unmodifiable(
      allProjects.where((project) => project.category == selected),
    );
  }

  Future<void> load() async {
    isLoading.value = true;
    error.value = null;
    try {
      projects.value = List<PortfolioProject>.unmodifiable(
        await _repository.fetchProjects(),
      );
    } on PortfolioApiException catch (exception) {
      error.value = exception.message;
    } finally {
      isLoading.value = false;
    }
  }
}
