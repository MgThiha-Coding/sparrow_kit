import 'package:sparrow_kit/sparrow_kit.dart' show HydrationState;
import 'package:sparrow_kit/ssr.dart' show MarkupNode;

import 'app/pages/landing_page.dart';

MarkupNode buildCompanyLandingPage(HydrationState hydration) {
  final state = LandingPageState(
    categorySelection: [
      for (var index = 0; index < landingCategories.length; index++)
        hydration.signal<String>(
          landingCategorySignalId(index),
          fallback: index == 0 ? 'true' : 'false',
        ),
    ],
    hiddenProjects: [
      for (var index = 0; index < landingProjects.length; index++)
        hydration.signal<bool>(
          landingProjectHiddenSignalId(index),
          fallback: false,
        ),
    ],
  );
  return CompanyLandingPage(state).render();
}
