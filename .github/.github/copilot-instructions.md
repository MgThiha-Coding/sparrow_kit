# Custom Dart Web Framework - Architecture Rules
- Target Environment: Dart Web (Compiled to JS via dart2js).
- Core Dependency: `package:web`.
- Rule 1: NO Virtual DOM. Do direct DOM manipulation via `package:web`.
- Rule 2: NO Flutter Runtime, NO Skia/CanvasKit. This is a DOM-first native web framework.
- Reactivity: Fine-grained reactivity using Signals (SolidJS style).
- Coding Style: Strict null-safety, performance-first, clean production-grade code.