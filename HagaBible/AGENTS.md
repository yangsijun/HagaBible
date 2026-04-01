<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-03-30 | Updated: 2026-03-30 -->

# HagaBible (Xcode Workspace)

## Purpose
Xcode project workspace containing the main iOS app target and the widget extension target.

## Subdirectories

| Directory | Purpose |
|-----------|---------|
| `HagaBible/` | Main app target source code — Clean Architecture layers (see `HagaBible/AGENTS.md`) |
| `HagaBibleWidget/` | iOS widget extension for home screen (see `HagaBibleWidget/AGENTS.md`) |
| `HagaBible.xcodeproj/` | Xcode project configuration (build settings, targets, schemes) |

## For AI Agents

### Working In This Directory
- `HagaBible.xcodeproj/` is auto-managed by Xcode — avoid manual edits to `project.pbxproj`
- When adding new Swift files, they must be added to the appropriate Xcode target
- The project supports iOS and macOS Catalyst

### Common Patterns
- Two targets: `HagaBible` (main app) and `HagaBibleWidget` (widget extension)
- Shared entities between targets where needed

<!-- MANUAL: Any manually added notes below this line are preserved on regeneration -->
