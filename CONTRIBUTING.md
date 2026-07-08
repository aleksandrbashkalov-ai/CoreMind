# Contributing to CoreMind

Thank you for your interest in contributing! Here's how to get started.

## Code Style

- Follow Swift API Design Guidelines
- Run `swiftlint` before submitting (config in `.swiftlint.yml`)
- Use meaningful names and prefer clarity over brevity

## Pull Request Process

1. Fork the repository
2. Create a feature branch (`git checkout -b feat/amazing-feature`)
3. Commit your changes with conventional commits
4. Ensure tests pass: `swift test --parallel`
5. Open a PR against the `main` branch

## Conventional Commits

We use [Conventional Commits](https://www.conventionalcommits.org/):

- `feat:` — new feature
- `fix:` — bug fix
- `refactor:` — code change without behavior change
- `perf:` — performance improvement
- `docs:` — documentation only
- `test:` — test addition or fix
- `chore:` — tooling, CI, dependencies

## Testing

- Write tests for all new functionality
- Aim for 80%+ coverage
- Run the full suite before submitting

## Questions?

Open a [Discussion](https://github.com/aleksandrbashkalov-ai/CoreMind/discussions) or an Issue for bugs.
