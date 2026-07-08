# Privacy Policy

**Last updated: July 2026**

## Your Data Is Yours

CoreMind is designed with privacy at its core. We believe your thoughts, journal entries, mood data, and personal reflections belong to you — and only you.

## Data Collection

**CoreMind does not collect, store, or transmit any personal data to external servers by default.**

All data — including journal entries, mood logs, focus session history, and breathing exercise usage — is stored **locally on your device** using SQLite via GRDB.

## What We Store Locally

- Journal entries and reflections
- Mood and energy check-in records
- Focus session statistics
- Breathing exercise preferences
- App configuration and preferences

This data is stored in your app's sandboxed `Application Support` directory and is never automatically sent anywhere.

## Internet Access

CoreMind is designed to work fully offline. Internet access is used only if you explicitly opt in to:

- **AI Coaching Insights**: You may choose to configure a local LLM (e.g., Ollama) or a remote API key. If you use a remote API, your selected session content is sent to the provider you chose (Anthropic, OpenAI, etc.) according to their privacy policy.
- **StoreKit**: Purchase transactions are processed by Apple via StoreKit. We do not receive or store your payment information.

## Third-Party Services

The only external service CoreMind may communicate with is the AI provider you explicitly configure. We do not use any analytics SDKs, telemetry frameworks, or crash reporting tools.

## Changes

If this policy changes, we will update the date above and notify users via the app's release notes.

## Contact

For privacy questions, open an issue on GitHub or contact the maintainer at the repository's discussion page.
