abstract interface class PortfolioRepository {
  Future<List<PortfolioProject>> fetchProjects();
}

class PortfolioApiException implements Exception {
  const PortfolioApiException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => 'PortfolioApiException: $message';
}

class PortfolioProject {
  const PortfolioProject({
    required this.id,
    required this.category,
    required this.title,
    required this.description,
    required this.artLabel,
    required this.artCaption,
    required this.theme,
  });

  static const _themes = {'amber', 'lilac', 'green'};

  final String id;
  final String category;
  final String title;
  final String description;
  final String artLabel;
  final String artCaption;
  final String theme;

  factory PortfolioProject.fromJson(Object? value) {
    if (value is! Map<String, dynamic>) {
      throw const FormatException('Expected a project object.');
    }

    final theme = _requiredString(value, 'theme');
    if (!_themes.contains(theme)) {
      throw FormatException('Unsupported project theme "$theme".');
    }

    return PortfolioProject(
      id: _requiredString(value, 'id'),
      category: _requiredString(value, 'category'),
      title: _requiredString(value, 'title'),
      description: _requiredString(value, 'description'),
      artLabel: _requiredString(value, 'artLabel'),
      artCaption: _requiredString(value, 'artCaption'),
      theme: theme,
    );
  }
}

String _requiredString(Map<String, dynamic> value, String key) {
  final field = value[key];
  if (field is! String || field.trim().isEmpty) {
    throw FormatException('Expected "$key" to be a non-empty string.');
  }
  return field;
}
