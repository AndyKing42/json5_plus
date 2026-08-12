# See You There Workspace Instructions

These are the custom instructions for generating, modifying, formatting, and auditing code in the See You There workspace. Adhere strictly to these preferences.

### AI Agent Execution Guidelines:
1. **When Writing or Modifying Code**: AI agents MUST follow **ALL** coding rules defined in this document without exception.
2. **When Checking or Auditing Existing Code**: AI agents MUST **NOT** check, flag, or report violations for any rules or sections annotated with `*(Auto-applied by apply_coding_rules.sh)*`. These annotated formatting rules are automatically handled by the repository cleanup script and should be ignored during existing code reviews.

## 0. Architecture Reference
- **Git Repositories Location**: Note that there is a separate git repo for each project underneath its project directory (`syt_lib`, `syt_server`, and `syt_client`).
- **CRITICAL COMPLIANCE**: You must strictly adhere to all architectural boundaries, data synchronization patterns, and SQLite/Postgres rules defined in `syt_lib/doc/architecture.md`.
- Do not suggest or implement state management, network, or storage logic that deviates from this architecture specification. If a user request conflicts with the architecture document, flag the conflict to the user before writing any code.
## 1. Antigravity Execution Limits
- Do not spawn parallel subagents for minor tasks.
- Require explicit user confirmation before executing multi-file analysis or background test terminal loops.
- **DO NOT** run full test suites (`flutter test` across all files) on every minor code change. Prioritize running `flutter analyze` first to verify static type and lint correctness, and only run targeted test files directly related to the changed code (e.g., `flutter test test/widget_tests/some_panel_test.dart`). Run the full test suite only on major feature completion or major refactoring milestones.

## 2. General Dart Conventions
- Always use **Dart** or **bash** instead of Python for writing scripts or automation tasks.
- Variable and field names for collections must end with their specific collection type word:
  - Maps should end with `Map` (e.g., `userMap`).
  - Lists should end with `List` (e.g., `userList`).
  - Sets should end with `Set` (e.g., `userSet`).

- **CRITICAL LOOP ENFORCEMENT**: Strictly prefer standard, structural `for` loops over functional collection iterations. 
  - **DO NOT USE**: `.map()`, `.toList()`, `.where()`, `.forEach()`, `.any()`, or `.every()` chained method blocks for collection manipulation or transformation.
  - **DO USE**: Standard `for (final item in collectionList)` statements to build, filter, or transform data structures.
  *Example Exception: Simple, single-line inline mappings inside declarative UI widget hierarchies are permitted only when a structural loop breaks widget tree formatting.*

- Sort parameters and instance fields alphabetically (ignoring underscores).
- Sort parameters alphabetically both in declarations and calls, except the "child" or "children" parameters, which should always come last.
- In general, prefer named parameters over positional parameters, especially when there are more than 2 parameters or when the parameter types are not easily distinguishable.
- For the increment (++) and decrement (--) operators, prefer the prefix form (e.g., `++i`) over the postfix form (e.g., `i++`). *(Auto-applied by apply_coding_rules.sh)*
- Use the `safeSetState` extension method instead of `setState`. (This is a custom extension method defined in `syt_client_util.dart` that checks if the widget is still mounted before calling `setState`). *(Auto-applied by apply_coding_rules.sh)*
- Use the constructor initializer list instead of initializing fields in the field declaration, except in classes that extend `State`.
- Prefer non-nullable fields and parameters, and use default values or required named parameters to avoid nullability when the cost of initialization is not too high.
- Use underscores in numeric literals as a thousands separator (e.g., `int asdf = 123_456_789`). *(Auto-applied by apply_coding_rules.sh)*
- All `enum` class names must be prefixed with a capital `E` (e.g., `EThemeMode`, `EAccessLevel`, `ETable`). *(Auto-applied by apply_coding_rules.sh)*
- Do not abbreviate "String" to "Str" as part of a variable, field, or parameter name (e.g., use `dateString` instead of `dateStr`). *(Auto-applied by apply_coding_rules.sh)*
- Abbreviations should generally not be used for variable/field names (e.g., prefer `for (final EventSchedule eventSchedule in eventScheduleList)` over `for (final EventSchedule es in eventScheduleList)`). This is a strong recommendation to be followed whenever feasible, rather than an absolute rule.
- Prefer `switch` statements or expressions over `if...else if` chains.
- Use enum shorthand pattern matching (e.g., `case .weekly` instead of `case EScheduleFrequency.weekly`) in `switch` statements and expressions. *(Auto-applied by apply_coding_rules.sh)*
- Widget event (callback) parameters (such as `onPressed`, `onChanged`, `onTap`) should only use inline code if the block is 5 or fewer lines. If the logic exceeds 5 lines, it must be extracted into a separate, private method in the class. The method must be named following the pattern `_<widgetDescription>On<eventName>`, where `<widgetDescription>` is a descriptive name for the widget and `<eventName>` is the capitalized event name (e.g., `_languageDropdownOnChanged` for the `onChanged` parameter of a language `DropdownButton`).
- **STRICT JSON CONVENTION**: Do not use `jsonEncode` or `jsonDecode` from `dart:convert`. The `Json5` class (`package:json5_plus/json5_plus.dart`) MUST be used for all JSON encoding, decoding, manipulation, and serialization tasks. *(Auto-applied by apply_coding_rules.sh)*
- **STRICT LOCALIZATION CONVENTION**: Hardcoded user-facing string literals in UI widgets, dialogs, buttons, tooltips, and labels are STRICTLY PROHIBITED. All user-visible UI text MUST be extracted to the localization `.arb` files (`app_en.arb`, `app_es.arb`, etc.) and accessed strictly via `sytUtil.appLocalizations`. *(Auto-applied by apply_coding_rules.sh)*

## 3. Class Structure & Ordering *(Auto-applied by apply_coding_rules.sh)*
Strictly follow this order for entries inside a Dart class or Flutter widget:
1. Static fields (sorted alphabetically, ignoring underscores)
2. Class (instance) fields (sorted alphabetically, ignoring underscores)
3. Static methods (sorted alphabetically, ignoring underscores)
4. Factory methods (sorted alphabetically)
5. Named constructors (sorted alphabetically)
6. Constructors
7. Operator overloads (sorted by ASCII value of operator symbol(s))
8. Methods (sorted alphabetically, ignoring underscores)
   *Note: Getters and setters should be sorted alphabetically based upon "get" or "set" concatenated with the field name (e.g., `getLevel`, `setLevel`).*

## 4. Method Separators & Formatting
- **Top-Level Separators**: In files containing more than one class, enum, mixin, or extension, precede top-level declarations (like classes, enums, extensions, mixins, or global variables) with a comment line starting with `//` followed by exactly 98 equals signs. Do not use top-level separators in files containing only one class, enum, mixin, or extension. *(Auto-applied by apply_coding_rules.sh)*
- **Method/Member Separators**: Inside a class or extension, the class/extension header itself must be followed immediately by a comment line starting with `//` followed by exactly 96 hyphens. Every method and constructor must be followed by a blank line and then a comment line starting with `//` followed by exactly 96 hyphens. This does not apply to tiny classes or extensions (i.e., classes with fewer than three methods), which do not need separators. *(Auto-applied by apply_coding_rules.sh)*
- **Enum Separators**: Simple enums that only list values (and do not contain constructors or methods) do not require the inner hyphen separator line right after their header. Do not add separators ("//" followed by 96 hyphens) to enums if there are no separators already used in the enum. *(Auto-applied by apply_coding_rules.sh)*
- **NEVER** add extra blank lines within methods. *(Auto-applied by apply_coding_rules.sh)*
- Methods that grow beyond about 100 lines of code should generally be split into smaller, more manageable helper methods. When splitting a method, prefix the helper method names with the parent method's name (e.g. prefixing helpers split from `_buildLeagueForm` with `_buildLeagueForm`, resulting in `_buildLeagueFormName`, `_buildLeagueFormGroup`, etc.) so that they remain grouped together when sorted alphabetically. *(Auto-applied by apply_coding_rules.sh)*
- Use double quotes for strings, except when the string contains a double quote character, in which case use single quotes to avoid the need for escaping. Also, use single quotes for the "import" paths. (Note: Since standard linter rules like `prefer_single_quotes` or `prefer_double_quotes` are disabled in the `analysis_options.yaml` file, manually verify this hybrid quoting convention).
- **Import Ordering & Grouping**: Group imports in this order: *(Auto-applied by apply_coding_rules.sh)*
  1. `dart:` core library imports
  2. `package:` third-party imports
  3. Relative project imports (with parent directory `../` imports placed before sibling folder imports)
  Sort imports alphabetically within each group, and separate each group with exactly one blank line.

## 5. SQL Formatting
- Use strictly **lowercase** for all SQL keywords. (If writing raw SQL rather than using the application's query builder class). *(Auto-applied by apply_coding_rules.sh)*
- Table and column names should never be embedded in string literals. Always reference them using the schema enums (e.g., `ETable.events.tableName`, `EEvents.eventName.columnName`) to prevent errors when schemas are modified.

## 6. UI Design Guidelines & Material 3 Compliance
- Adhere strictly to **Material 3 (M3)** guidelines for all UI components, spacing, layout choices, and interactive elements.
- Ensure the root `ThemeData` configuration explicitly enforces `useMaterial3: true`.
- **Typography & Type Scale**: 
  - **NEVER** use hardcoded numeric values (magic numbers) for text sizes or font weights (e.g., explicit `fontSize: 12`) inside layouts, buttons, text views, fields, or chips.
  - Always bind text styling exclusively to relative, semantic tokens from `Theme.of(context).textTheme`. 
  - Match common design metadata precisely to these scaling categories:
    - Use `labelSmall` or `labelMedium` for timestamps, tags, item counts, metadata labels, and chip text.
    - Use `bodyMedium` or `bodyLarge` for main descriptive paragraphs or user chat message bubble content.
    - Use `titleMedium` or `titleLarge` for list headers, panel titles, and modal headers.
- **Context-Appropriate Overlays & Dialogs**:
  - Do not use `AlertDialog` for content-heavy, multi-row selection, list browsing, or interactive search workflows. Restrict `AlertDialog` usage strictly to high-disruption system tasks, destructive actions (e.g., deletions), or critical error confirmations.
  - For interactive user data selection, profile picking, filter matrices, or content listings (like choosing contacts or searching groups), always display the interface using `showModalBottomSheet`. 
  - Ensure modal sheets feature rounded top borders matching standard M3 sheet shapes natively.
- **Surface & Component Styling**:
  - Utilize modern Material 3 semantic tonal tokens from `Theme.of(context).colorScheme` for structural layouts rather than hardcoding arbitrary color shades or generic grey filters.
  - Prefer `surfaceContainer`, `surfaceContainerHigh`, and `surfaceContainerHighest` for structural card divisions, backgrounds, and message bubble panels. Use `outlineVariant` for clean divider rules.
  - For category selectors or contextual filter segments inside screens and sheets, replace traditional inline `TabBar` layouts with the specialized M3 `SegmentedButton<T>` framework.

## 7. Scope & Backlog Control
- The todo list is located here: C:\Flutter\SeeYouThere\syt_lib\doc\todo_list.md
- NEVER suggest, plan, or implement any items listed under any section containing "Futures" in `todo_list.md` unless the USER explicitly requests you to do so. This backlog is strictly a parking lot for post-v1 features.

## 8. Absolute Compliance Enforcement
- Prior to outputting ANY generated or refactored Dart code snippet, you must cross-reference your internal text against the rules listed above. If your output contains a functional chain method (like `.map()`), an un-sorted parameter array, or a missing `//----------------------------------------------------------------------------` separator line, you must rewrite it internally to comply with these formatting blocks before displaying it to the user.
- **Auditing Distinction**: When performing code checks/audits on existing code files, do NOT check or report violations for any rule marked with `*(Auto-applied by apply_coding_rules.sh)*`.
- DO NOT run `dart run syt_lib/bin/apply_coding_rules.sh` as an automated cleanup tool until explicitly instructed by the user. Ensure all formatting and structure guidelines are applied manually during code generation.