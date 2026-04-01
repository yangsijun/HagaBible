<!-- Generated: 2026-03-30 | Updated: 2026-03-30 -->

# HagaBible

## Purpose
A native iOS Bible reading application built with Swift and SwiftUI, featuring multi-version Bible text, Text-to-Speech (TTS) playback, audio recording, and search functionality. The app follows Clean Architecture with MVVM for the presentation layer.

## Key Files

| File | Description |
|------|-------------|
| `README.md` | Project overview |
| `LICENSE` | License file |
| `.gitignore` | Git ignore rules |

## Subdirectories

| Directory | Purpose |
|-----------|---------|
| `HagaBible/` | Xcode workspace containing the main app target and widget extension (see `HagaBible/AGENTS.md`) |

## For AI Agents

### Working In This Directory
- This is the repository root; the actual Xcode project lives in `HagaBible/`
- The project uses Korean (한국어) for comments and some user-facing strings
- Clean Architecture layers: Application → Presentation → Domain ← Data
- Custom DI container (no third-party DI framework)

### Testing Requirements
- Build the project via Xcode or `xcodebuild`
- No automated test suite currently exists

### Common Patterns
- Protocol-based abstractions in Domain, concrete implementations in Data
- `@Observable` for state management (Swift Observation framework)
- GRDB for SQLite database access
- SwiftData for recordings and search history persistence
- AVFoundation for TTS and audio recording

## Dependencies

### External
- **GRDB** — SQLite database framework for Bible text storage
- **SwiftData** — Apple's persistence framework for recordings/search history
- **AVFoundation** — Audio playback and speech synthesis
- **OSLog** — Structured logging

<!-- MANUAL: Any manually added notes below this line are preserved on regeneration -->
