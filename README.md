# CoreMind

> Minimal, thoughtful macOS app for focus, reflection, and mental clarity.

[![Swift 5.10](https://img.shields.io/badge/Swift-5.10-FA7343?logo=swift&logoColor=white)](https://swift.org)
[![macOS 14+](https://img.shields.io/badge/macOS-14+-lightgrey?logo=apple&logoColor=white)](https://developer.apple.com/macos)
[![MIT License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![CI](https://github.com/aleksandrbashkalov-ai/CoreMind/actions/workflows/ci.yml/badge.svg)](https://github.com/aleksandrbashkalov-ai/CoreMind/actions/workflows/ci.yml)
[![Platform](https://img.shields.io/badge/Platform-Apple_Silicon_%7C_Intel-333333?logo=apple)](https://github.com/aleksandrbashkalov-ai/CoreMind)

---

## 📋 Зміст

- [Огляд (Overview)](#overview)
- [Які проблеми вирішує CoreMind](#core-problems-coremind-solves)
- [Можливості (Features)](#features)
- [Встановлення (Installation)](#installation)
- [Системні вимоги (System Requirements)](#system-requirements)
- [З чого зроблено (Built With)](#built-with)
- [Структура проєкту (Project Structure)](#project-structure)
- [Як допомогти (Contributing)](#contributing)
- [Ліцензія (License)](#license)

---

## Overview

CoreMind is a native macOS app designed to help you stay focused, build mindful habits, and reflect on your mental state throughout the day. It combines practical productivity tools — focus timers, mood check-ins, journaling — with Stoic wisdom and optional AI-powered coaching to create a complete mental wellness companion that lives in your menu bar.

Built with SwiftUI and GRDB, CoreMind stores **all data locally**. Nothing leaves your device unless you explicitly configure an AI provider.

## Core Problems CoreMind Solves

| Problem | How CoreMind Helps |
|---------|-------------------|
| **Digital burnout** | Focus sessions with Pomodoro-style timers, break reminders, and daily flow tracking |
| **Lost sense of progress** | Mood & energy check-ins with historical trends and weekly reports |
| **No outlet for reflection** | Journal with markdown, search, and optional AI-powered insights |
| **Mindlessness & stress** | Guided breathing exercises with multiple patterns |
| **Lack of structure** | Morning intention setting, evening reflection, daily Stoic wisdom |
| **No feedback loop** | AI Coaching (Anthropic/Ollama/OpenAI) analyzes your patterns and suggests improvements |

## Features

### Focus Sessions
- Configurable focus intervals (25–120 min)
- Break reminders with adjustable intervals
- Daily goal tracking (minutes focused)
- Session history with productivity heatmap

### Check-In
- Mood rating (1–5) with emoji picker
- Energy level tracking
- Optional notes per check-in
- Scheduled reminders
- Historical trends with charts

### Journal
- Markdown-supported entries
- Search and filter by date/mood
- 5 entries/month free, unlimited with Pro
- AI-powered reflection insights (optional, configurable provider)

### AI Coaching
- Choose your provider: **Ollama** (local), **Anthropic Claude**, **OpenAI GPT**, or **Custom endpoint**
- Session context is sent only to your chosen provider
- Patterns analysis, suggestions, and reflections

### Breathing Exercises
- 4 patterns: Box Breathing, 4-7-8, Deep Belly, Calm Counting
- Guided sessions with haptic feedback
- Session history

### Weekly Reports
- Mood trends chart
- Focus time distribution
- Journal activity overview
- Exportable summary

### Daily Stoic Wisdom
- Curated Stoic quotes and reflections
- Daily notifications
- Configurable schedule

### Privacy-First Design
- **Zero telemetry.** No analytics SDKs. No crash reporters.
- All data stored locally in SQLite via GRDB.
- AI features are opt-in with explicit provider choice.
- Full offline functionality.

## Installation

### Option 1: Download DMG
Download the latest `CoreMind_v*.dmg` from the [Releases page](https://github.com/aleksandrbashkalov-ai/CoreMind/releases).

### Option 2: Build from Source
```bash
git clone https://github.com/aleksandrbashkalov-ai/CoreMind.git
cd CoreMind
swift build -c release
```

The binary will be at `.build/apple/Products/Release/CoreMind`.

To create a standalone `.app` bundle:
```bash
chmod +x scripts/build-app.sh
./scripts/build-app.sh release
```

To build a distributable DMG:
```bash
chmod +x scripts/release-dmg.sh
./scripts/release-dmg.sh
```

### Option 3: Swift Package Manager (as a dependency)
```swift
dependencies: [
    .package(url: "https://github.com/aleksandrbashkalov-ai/CoreMind.git", from: "1.0.0")
]
```

## System Requirements

- **macOS 14.0** (Sonoma) or later
- **Apple Silicon** (arm64) or **Intel** (x86_64)
- ~50 MB disk space for the app
- No internet connection required for core functionality

## Built With

<p align="center">
  <img src="https://img.shields.io/badge/Swift-5.10-FA7343?style=flat-square&logo=swift" alt="Swift">
  <img src="https://img.shields.io/badge/SwiftUI-FA7343?style=flat-square&logo=swift&labelColor=FA7343" alt="SwiftUI">
  <img src="https://img.shields.io/badge/GRDB_(SQLite)-003B57?style=flat-square&logo=sqlite" alt="GRDB">
  <img src="https://img.shields.io/badge/MVVM-3178C6?style=flat-square" alt="MVVM">
  <img src="https://img.shields.io/badge/StoreKit_2-FF9500?style=flat-square&logo=apple" alt="StoreKit 2">
  <br>
  <img src="https://img.shields.io/badge/Ollama-000000?style=flat-square&logo=ollama" alt="Ollama">
  <img src="https://img.shields.io/badge/Anthropic-191919?style=flat-square&logo=anthropic" alt="Anthropic">
  <img src="https://img.shields.io/badge/OpenAI-412991?style=flat-square&logo=openai" alt="OpenAI">
  <img src="https://img.shields.io/badge/macOS_14+-lightgrey?style=flat-square&logo=apple" alt="macOS 14+">
</p>

| Категорія | Технологія |
|-----------|-----------|
| Мова | Swift 5.10 |
| UI | SwiftUI |
| База даних | GRDB (SQLite) |
| Архітектура | MVVM + Dependency Injection |
| AI-провайдери | Ollama / Anthropic / OpenAI (pluggable) |
| Монетизація | StoreKit 2 (опціональна Pro підписка) |
| Мінімальна версія | macOS 14.0 |

## Project Structure

```
CoreMind/
├── Sources/
│   └── CoreMind/
│       ├── App/                    # App lifecycle, AppDelegate
│       ├── Features/               # Feature modules (Focus, Journal, etc.)
│       ├── Services/               # AI, Storage, Notification services
│       ├── Models/                 # Core data models
│       ├── Utilities/              # Helpers, Constants, Logging
│       ├── DesignSystem/           # Colors, Typography, Components
│       └── Monetization/           # StoreKit integration
├── scripts/                        # Build & release scripts
├── Tests/                          # Unit & integration tests
├── .github/workflows/ci.yml        # CI pipeline
└── Package.swift                   # SwiftPM manifest
```

## Contributing

Contributions are welcome! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## License

CoreMind is released under the MIT License. See [LICENSE](LICENSE) for details.

---

*Made with ❤️ for a clearer mind.*
