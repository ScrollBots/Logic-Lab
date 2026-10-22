# Logic Lab — آزمایشگاه منطق

A **fully offline**, Persian-first digital logic learning and simulation laboratory for Android.

Logic Lab lets you build real combinational and sequential circuits on an interactive canvas, watch the
simulator recompute outputs live, step a clock through flip-flops, counters and registers, generate
truth tables from the actual circuit, analyse and compare circuits, and practise with challenges that
are graded by real circuit behaviour. Everything is stored locally; the app never needs an account, a
network connection, or a cloud service, and it works in airplane mode.

---

## 1. Environment

| Item | Version / note |
|------|----------------|
| Flutter | 3.29.3 (stable) |
| Dart | 3.7.2 |
| Android SDK | 36.1.0, NDK 27.0.12077973, AGP 8.7.0, Kotlin 1.8.22 |
| Target device | Android 5.0 (API 21) and above, `minSdk` from Flutter |
| Application id | `ir.logiclab.logic_lab` (unchanged, so upgrades keep user data) |
| Build output | `build/app/outputs/flutter-apk/app-release.apk` (R8 minified) |

## 2. Package choices

| Package | Version | Why |
|---------|---------|-----|
| `provider` | 6.1.5 | Small, explicit state management. The simulator itself is pure Dart and has no Flutter dependency, so state management never leaks into the domain layer. |
| `sqflite` | 2.4.2 | Native SQLite for projects and learning progress. Chosen over a document store because projects are relational, need sorting/search, and must be queryable offline. |
| `shared_preferences` | 2.5.3 | Theme mode, palette, custom accent, haptics/animations toggles and circuit signal colours — small key/value settings only. |
| `path_provider` / `path` | 2.1.5 / 1.9.1 | Platform path handling for user-initiated file export. |
| `file_picker` | 11.0.3 | User-initiated JSON import (project files and full backups). |
| `share_plus` | 10.1.4 | Android share sheet for CSV and JSON export. 10.x is pinned because it builds with the Kotlin 1.8 toolchain shipped with Flutter 3.29. |
| `flutter_localizations` | SDK | Persian (`fa_IR`) Material/Cupertino strings and correct RTL behaviour. |
| `flutter_lints` | 5.0.0 | Lint baseline for `flutter analyze`. |

Fonts are **bundled locally** (no remote fonts, works offline):

* [Vazirmatn](https://github.com/rastikerdar/vazirmatn) — Persian UI font, SIL Open Font License 1.1
  (`assets/fonts/OFL.txt`).
* JetBrains Mono — technical values, identifiers and binary strings, SIL Open Font License 1.1
  (`assets/fonts/JetBrainsMono-OFL.txt`).

## 3. Architecture

Feature-first with a strict separation between the four layers. Nothing in the *domain* layer
imports Flutter widgets, so the whole simulator is testable without a widget tree.

```
lib/
├─ app/                     # Application root, bootstrap splash, navigation shell
│  ├─ app.dart              # MaterialApp, RTL locale, theme wiring, providers
│  ├─ bootstrap.dart        # Opens the local database and shows the branded splash
│  └─ shell/app_shell.dart  # Morphing navigation (5 destinations)
├─ core/                    # Cross-cutting infrastructure
│  ├─ data/                 # SQLite bootstrap (conditional IO/web import)
│  ├─ localization/         # Persian digits, Jalali dates, relative dates
│  ├─ services/             # File import/export + Android share
│  ├─ theme/                # Design system: palettes, Material 3 theme, extensions
│  ├─ utils/                # Identifier generation
│  ├─ widgets/              # Shared UI: cards, brand mark, signal pills, gate symbols
│  └─ app_info.dart         # Single source of truth for the version and identity
└─ features/
   ├─ editor/               # Circuit domain, simulation, canvas, editor screen
   │  ├─ domain/            # Graph model, component specs, geometry, simulator, templates
   │  ├─ application/       # Editor state: undo/redo, autosave, selection, clock control
   │  └─ presentation/      # CustomPainter canvas, preview painter, editor screen
   ├─ projects/             # Project model, JSON codec, repository, list screen
   ├─ truth_table/          # Truth table generator + screen (multi-output, filterable)
   ├─ analysis/             # Circuit statistics, equivalence, comparison screen
   ├─ boolean_tools/        # Parser, evaluator, simplifier, converter, equivalence, workspace
   ├─ learn/                # Gate reference, lessons, challenges, progress
   ├─ lab/                  # Interactive gate bench + ready-made circuits
   ├─ home/                 # Dashboard
   ├─ settings/             # Appearance, behaviour, data management
   └─ splash/               # Branded splash (Logic Lab / آزمایشگاه منطق)
```

Data flow:

```
UI (presentation)  →  Controller (application)  →  Domain (pure Dart)
                                             ↘  Repository (persistence)
```

* `CircuitGraph`, `CircuitSimulator`, `ComponentLibrary`, `TruthTableGenerator`,
  `BooleanExpressionParser` and `BooleanSimplifier` contain **no Flutter imports**.
* Persistence is reached only through the `ProjectRepository` and `LearningProgressRepository`
  interfaces; SQLite and in-memory implementations are interchangeable, which is what makes the
  widget tests fast and deterministic.

## 4. Component library

All components are described by a single `ComponentSpec` registry
(`lib/features/editor/domain/component_spec.dart`) that defines the ports, the drawing kind and the
behaviour. The simulator, the canvas, the component drawer and the truth table all read from it, so a
new component only has to be described once.

| Group | Components |
|-------|------------|
| Base | Input pin, output probe, clock source |
| Basic gates | AND, OR, NOT, NAND, NOR, XOR, XNOR, Buffer, Tri-state buffer (Z) |
| Multi-input | AND / OR / NAND / NOR / XOR / XNOR with 2–8 inputs (XOR/XNOR use parity) |
| Compound | AOI21, AOI22, OAI21, OAI22 |
| Arithmetic | Half adder, full adder, half subtractor, full subtractor, 2-bit comparator |
| Selection / coding | MUX 2:1, MUX 4:1, DEMUX 1:2, DEMUX 1:4, decoder 2→4, decoder 3→8, encoder 4→2, encoder 8→3, priority encoder |
| Sequential | SR latch, gated SR latch, D latch, D / T / JK flip-flop, 4-bit register, 4-bit shift register, 4-bit counter, up/down counter |

Compound and sequential components expose several ports, so a node can have more than one output.
The wire format already carried a source port index, which made this possible without breaking
existing files.

## 5. Simulation model (documented behaviour)

The simulator is four-valued and never guesses.

* **HIGH / LOW / UNKNOWN / HIGH-IMPEDANCE.** Inputs are always definitive HIGH or LOW from their
  switches. `UNKNOWN` means the value cannot be proven; `Z` is the explicit high-impedance state of a
  disabled tri-state driver and is drawn and reported differently.
* **Three-valued logic.** `AND` with a LOW input is LOW even if another input is unknown, and `OR`
  with a HIGH input is HIGH. This follows the usual IEEE 1164 style interpretation.
* **Propagation.** A gate output is UNKNOWN if any of its required inputs is missing, duplicated or
  UNKNOWN. UNKNOWN never degrades into LOW.
* **Connectivity rules.** A signal may only flow from an output pin to an input pin. Each input
  port accepts at most one wire. Connecting an output to an output, an input to an input, or
  connecting a port twice is rejected with a Persian explanation, and the editor refuses to create
  such a wire.
* **Combinational cycles.** A cycle made only of gates and modules makes the circuit invalid. Every
  node in the cycle reports UNKNOWN; the app never presents a "valid" result for a cyclic circuit.
  The editor also blocks user gestures that would create such a cycle.
* **Valid sequential feedback.** A loop that runs *through* a stateful element (flip-flop, latch,
  register, counter) is not a combinational cycle: the state element breaks the loop. Such a
  connection is allowed by the editor and simulated correctly, so a toggle flip-flop
  (`Q → NOT → D`) can be built.
* **Sequential elements.** Level-sensitive latches update their state while they are enabled.
  Edge-triggered elements (flip-flops, registers, counters) capture their input **only on a rising
  clock edge**. The clock is controlled by the user: step, run/pause, reset, and the clock generator
  component.
* **Sequential state is three-valued too.** A flip-flop that captures an unknown or floating data
  line stores UNKNOWN instead of silently pretending it captured a zero. An unknown `T`/`J`/`K`
  control likewise yields an unknown output rather than a guess.
* **Unknown clock.** A clock input that is UNKNOWN or floating produces no edge and is reported with
  a dedicated warning.
* **Incomplete circuits.** A gate or output pin with an unconnected required input is reported as
  an error. A circuit without an output pin is reported as well.
* **Fan-out.** One output may feed several inputs; a junction dot marks the branch on the canvas.
* **Multi-stage circuits.** Evaluation uses a topological order, so chained gates resolve in one pass.
* **Determinism.** The same graph and the same input values always produce the same result; the
  engine has no randomness and no hidden state except the documented sequential state.

### The simulation step

One evaluation of the engine is one *simulation step* and always runs the same four phases:

1. **Validation** – the graph is checked (missing nodes, invalid ports, duplicated connections,
   unconnected inputs, combinational cycles).
2. **Signal phase** – every combinational node is evaluated from the sequential state that was
   current at the *start* of the step. The evaluation order is a topological order of the
   combinational subgraph; a stateful node is a *source* in that subgraph, because its output comes
   from its stored state and not from its inputs.
3. **State phase** – the inputs of every stateful node are read from the settled signals of phase 2
   and the stored state is updated: edge-triggered elements capture on a rising clock edge,
   level-sensitive elements update while they are enabled.
4. **Settling** – phases 2 and 3 repeat while the state keeps changing (a latch that feeds logic
   back into itself settles within a few rounds). The number of rounds is bounded; an unstable
   feedback loop is reported instead of freezing the app, and the reported signals always belong to
   the *final* state of the step.

Because the data inputs of a flip-flop are read in phase 3, they are always the settled values of
phase 2 — a flip-flop can never capture a value that was simply not computed yet.

Truth tables are produced by *running the simulator* for every input combination, never by
re-implementing the logic in the table code. Circuits that exceed the configurable computation limit
(64 / 256 / 1024 rows) are refused with an explanatory message instead of hanging. A circuit with
sequential elements states clearly that every row is computed from the *initial* state of those
elements.

## 6. Boolean expression tools

* Parser: recursive descent with `&` (AND), `|` (OR), `!` (NOT), `^` (XOR), parentheses, the
  constants `0`/`1`, and the English keywords `AND`, `OR`, `NOT`, `XOR`.
* Errors are reported with a message and the offending position.
* Evaluation and automatic truth-table generation for up to 8 variables.
* Simplification: Quine–McCluskey prime implicants plus an exhaustive branch-and-bound cover
  search. **A result is only labelled exact after the simplified expression has been re-parsed and
  compared with the original for every assignment.** A minimisation may also *remove* a variable
  that turns out to be irrelevant; the result is accepted as long as it introduces no new variable
  and stays equivalent for every assignment. For more than six variables the tool refuses to claim
  a minimum and says so explicitly.
* The minimiser is cross-checked against an independent brute-force implementation: for **every**
  three-variable function the number of terms and literals must match the reference search, and
  randomised expressions are verified for equivalence with a fixed seed.
* Comparison of two expressions by comparing their truth tables over the union of their variables.
* Equivalence between an expression and a stored circuit.
* Conversion of an expression into a real circuit graph (AND/OR/NOT/XOR gates plus wires) that
  can be opened in the editor and simulated.

## 7. Editor and navigation

* **Searchable component drawer** with categories, gate symbols and a description for every part.
* **Interactive canvas** with real schematic symbols, module blocks with named ports, junction dots,
  signal colours, a legend (۱ / ۰ / ؟ / Z) that never relies on colour alone, grid, grid snapping,
  zoom, pan, fit-to-screen and reset view.
* **Editing**: add, drag, connect (tap output then input), select, multi-select (long press),
  duplicate, delete, undo and redo, plus a property sheet for labels, input counts and initial
  values.
* **Simulation toolbar**: run, pause, step the clock and reset the sequential state.
* **Automatic saving** with a visible save state, undo/redo history and a status dock that reports
  invalid circuits instead of showing a misleading result.
* **Analysis screen**: gate counts, circuit depth, sequential element count, the simulation status
  and a comparison with another circuit that reports the first differing input combination.

### Morphing navigation

The five destinations are hosted by an `IndexedStack`, so scroll positions and the circuit canvas
are never rebuilt or lost. Switching a section runs one coordinated 320 ms transition:

* the page settles with a small scale (98.5 % → 100 %) and a 14 px rise,
* an accent rail slides along the top edge to the selected section,
* the capsule highlight glides to the new item and the icon cross-fades with a subtle scale.

The motion is disabled when the user turns off animations in the settings, and it never interferes
with the back gesture.

## 8. Data, import/export and backup

* Projects are stored in SQLite with creation/modification timestamps, names and the full circuit
  JSON. The list supports search and sorting by modification date, creation date or name.
* Project export produces a portable, versioned JSON envelope
  (`format: logic-lab-project`, `version: 1`) with no absolute paths. Import validates the format,
  the version and the circuit payload, and refuses malformed or newer files.
* **Import is validated completely before anything is replaced.** A file is only accepted after the
  whole circuit has been checked: every wire must point at an existing component and at a port that
  really exists, duplicate identifiers are rejected, and files above 4 MB are refused before they
  are parsed. A failed import never touches the project that is currently open.
* A full backup (`format: logic-lab-backup`) contains projects, learning progress and settings.
* Corrupted database rows are skipped instead of crashing the app; malformed import files produce
  a readable error.
* **Backward compatibility**: circuits saved by older builds still load (the new `outputCount` field
  is optional), and a component type that this build does not know is loaded as an "unsupported"
  component and reported instead of breaking the whole project.
* "Delete all data" is available behind an explicit destructive confirmation.

## 9. Version and identity

* The version lives in `pubspec.yaml` (`version: 1.1.0+2`) and is mirrored in
  `lib/core/app_info.dart`. A unit test reads `pubspec.yaml` and fails if the two ever drift apart.
* The About screen shows the user-facing version as the dot separated `1.1.0` and keeps the build
  number separate. The version is never localised into `1/0/0` or `1٫0٫0`.
* The Android launcher label is **Logic Lab**; the Persian subtitle **آزمایشگاه منطق** appears on
  the branded splash screen and in the About screen, because launchers only show a single label.
* The launcher uses an adaptive icon (vector background, foreground and a monochrome layer for
  Android 13 themed icons) built from the same gate glyph as the app.

## 10. Accessibility and localisation

* Persian is the default locale (`fa_IR`) with `GlobalMaterialLocalizations`, so system dialogs,
  text fields, selection controls and directionality behave correctly.
* Persian digits are used in Persian-facing UI; technical values (binary bits, identifiers,
  expressions, code) keep ASCII digits and are rendered LTR inside a `Directionality.ltr` island.
* Circuit symbols, wire direction and Boolean expressions always keep their conventional
  left-to-right meaning; only the surrounding chrome is mirrored.
* Dates are shown with an accurate Jalali conversion plus relative Persian labels.
* Semantic labels on navigation items, canvas pins, table rows, signal pills and icon buttons,
  tooltips on every icon action, 44–48 dp touch targets and text scaling up to 1.4×.

## 11. Build and release

```bash
flutter pub get
flutter analyze          # static analysis
flutter test             # unit + widget tests
flutter build apk --release
```

Release signing: copy `android/key.properties.example` to `android/key.properties` and fill in
your upload keystore. Without that file the release build falls back to the debug key (useful for
CI), so `flutter build apk --release` always works. R8 minification and resource shrinking are
enabled, with the extra rules in `android/app/proguard-rules.pro`.

## 12. Tests

`flutter test` runs 233 automated tests:

| Area | File |
|------|------|
| Basic gates, multi-stage composition, invalid connections, cycles, connection rules | `test/features/editor/circuit_validator_test.dart` |
| Advanced components: multi-input gates, tri-state, compound gates, arithmetic, mux/demux/decoder/encoder, sequential elements and clock edges | `test/features/editor/advanced_components_test.dart` |
| **Exhaustive truth tables of every gate against independent reference tables** | `test/features/editor/gate_truth_tables_test.dart` |
| **Exhaustive arithmetic and selection modules (adders, subtractors, comparator, mux, demux, decoder, encoder)** | `test/features/editor/arithmetic_and_selection_test.dart` |
| **Sequential components over several clock edges: latches, flip-flops, registers, shift registers, counters, valid feedback vs. invalid loops, UNKNOWN/Z at clock and data** | `test/features/editor/sequential_components_test.dart` |
| **Consistency of a simulation step: outputs, inputs, evaluated nodes, problems and clock level describe the same state** | `test/features/editor/simulation_result_consistency_test.dart` |
| **Simulation benchmark with a growth guard (catches a return to quadratic lookups)** | `test/features/editor/simulation_benchmark_test.dart` |
| **Editor layout: the component drawer lists every category once, the Boolean tool header stays readable on small screens** | `test/features/editor/editor_ui_layout_test.dart` |
| Editor controller: add, connect, refuse invalid connections, toggle inputs, undo/redo, duplicate, delete, autosave | `test/features/editor/circuit_editor_controller_test.dart` |
| Truth-table generation, limit handling, unknown values, CSV export | `test/features/truth_table/truth_table_test.dart` |
| Expression parsing, evaluation, precedence, simplification, comparison, circuit conversion | `test/features/boolean_tools/boolean_expression_test.dart` |
| **Minimisation cross-checked against an independent brute force for every three-variable function, plus randomised equivalence checks** | `test/features/boolean_tools/boolean_minimization_verification_test.dart` |
| Expression ↔ circuit equivalence and project format compatibility (legacy + unknown types) | `test/features/boolean_tools/expression_equivalence_test.dart` |
| Circuit statistics, depth and equivalence comparison | `test/features/analysis/circuit_analyzer_test.dart` |
| Project/circuit serialisation, versioning, malformed and incompatible files | `test/features/projects/project_serialization_test.dart` |
| **Import hardening: oversized, malformed, foreign, newer-version, dangling-wire, invalid-port and duplicate-identifier files are rejected** | `test/features/projects/import_export_test.dart` |
| Challenge validation against real circuit behaviour, template validity | `test/features/learn/challenge_validator_test.dart` |
| Theme, palette, custom accent and signal colour persistence, corrupt preference recovery | `test/features/settings/settings_persistence_test.dart` |
| Version metadata, application id and version formatting | `test/core/app_info_test.dart` |
| RTL shell, five destinations, empty state, navigation, project list, editor launch | `test/widget_test.dart` |

The shared reference implementations (gate tables, arithmetic, selection/coding) live in
`test/support/circuit_test_support.dart`. They are written independently from the component
specification, so the tests really cross-check the simulator instead of comparing it with itself.

## 13. Continuous integration and releases

The repository ships with a complete GitHub Actions pipeline, so nothing has to be built or
tested on a local machine:

| Workflow | Purpose |
|----------|---------|
| `.github/workflows/ci.yml` | Format check, `flutter analyze`, the full test suite and a real Android build on every push and pull request. Artifacts (APK/AAB + coverage) can be downloaded from the run. |
| `.github/workflows/release.yml` | A version tag (`git tag v1.1.0`) produces signed, per-ABI APKs and an App Bundle and publishes them as a GitHub release. |
| `.github/workflows/web-preview.yml` | Deploys the web build to GitHub Pages for a quick look at the interface. |

The required repository secrets (`ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`,
`ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`), the release flow and the troubleshooting notes
are documented in **`.github/CI.md`** (Persian).

Helper scripts: `tool/validate_ci.dart` (validates the workflows themselves) and
`tool/set_version.dart` (writes the version from the release tag into `pubspec.yaml`).

## 14. Release notes

### v1.1.0

**Fixed**

* **Sequential circuits captured the wrong value.** A flip-flop, register or counter whose data or
  clock came through a gate evaluated that gate *after* itself, so the input was read as UNKNOWN
  and the element stored a meaningless value. The engine now runs an explicit four-phase simulation
  step (validation → signals → state → settling) and always captures the settled value.
* **The 2-bit comparator reported "greater than" for equal numbers.** "Greater" is now derived from
  the borrow of `b − a` instead of from "not less than".
* **The Boolean simplifier discarded valid results.** A minimisation that removed an irrelevant
  variable (for example `A & B | A & !B` → `A`) was rejected and the tool showed no result at all.
* **The editor refused valid sequential feedback.** A connection that closes a loop through a
  flip-flop (`Q → NOT → D`) was blocked as if it were a combinational cycle.
* **Latches were evaluated one step behind** and a combinational loop around a latch was reported as
  an invalid circuit.
* **Sequential state could not represent "unknown".** Capturing a floating data line now yields an
  unknown output instead of a silent zero.
* **Import accepted broken files.** A project file with a dangling wire, an impossible port index
  or a duplicate identifier is now rejected with a readable message, and files above 4 MB are
  refused before they are parsed.
* **Layout problems on small screens.** The heading of the Boolean tool and the category titles of
  the component drawer were squeezed or repeated; both are fixed and covered by widget tests.

**Improved**

* The circuit is no longer re-simulated while a component is being dragged — the result is
  refreshed once when the component is dropped, which keeps large circuits responsive.
* Node lookup is now O(1) and the topological sort no longer shifts its queue, so large circuits
  are evaluated measurably faster (about 20 % less time for a 200-gate chain in a debug VM).
* High-impedance (`Z`) has its own symbol next to the output value, and the truth table explains
  that a circuit with sequential elements is computed from the initial state.
* Two new diagnostics: an unknown clock and an unstable feedback loop are reported instead of
  failing silently.

**Verified**

* The test suite grew from 149 to 233 tests, including exhaustive truth tables against
  independent reference implementations, sequential tests over several clock edges, an independent
  cross-check of the Boolean minimiser and a benchmark that guards against quadratic lookups.

## 15. Roadmap

The learning content, the component registry and the exercise system are all data-driven, so the
following can be added without touching the engine: an ALU, a ripple-carry adder, a seven-segment
decoder, a small RAM teaching module, a simple CPU datapath and further learning paths.

## License

The application source is provided as-is for this project. Bundled fonts keep their own licenses:
SIL Open Font License 1.1 (Vazirmatn, JetBrains Mono) — see `assets/fonts/`.
