import 'dart:convert';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'portfolio_project.dart';

class PortfolioApi implements PortfolioRepository {
  @override
  Future<List<PortfolioProject>> fetchProjects() async {
    final endpoint = Uri.base.resolve('/data/projects.json');
    late final String body;

    try {
      final response = await web.window.fetch(endpoint.toString().toJS).toDart;
      if (!response.ok) {
        throw PortfolioApiException(
          'Project request failed with HTTP ${response.status}.',
        );
      }
      body = (await response.text().toDart).toDart;
    } on PortfolioApiException {
      rethrow;
    } on Object catch (error) {
      // Browser promises may reject with arbitrary JS values.
      throw PortfolioApiException(
        'Could not reach the portfolio data endpoint.',
        cause: error,
      );
    }

    try {
      final decoded = jsonDecode(body);
      if (decoded is! List<Object?>) {
        throw const FormatException('Expected a list of projects.');
      }

      final projects =
          decoded.map(PortfolioProject.fromJson).toList(growable: false);
      final ids = <String>{};
      for (final project in projects) {
        if (!ids.add(project.id)) {
          throw FormatException('Duplicate project id "${project.id}".');
        }
      }
      return projects;
    } on FormatException catch (error) {
      throw PortfolioApiException(
        'The portfolio endpoint returned invalid project data.',
        cause: error,
      );
    }
  }
}
