# Contributing to Anthropic Swift SDK

Thank you for your interest in contributing! This guide will help you get started.

## Getting Started

1. Fork the repository
2. Clone your fork:
   ```bash
   git clone https://github.com/<your-username>/anthropic-swift.git
   ```
3. Create a feature branch:
   ```bash
   git checkout -b feature/your-feature-name
   ```
4. Make your changes and commit them
5. Push to your fork and open a pull request

## Development Setup

### Requirements

- Swift 5.9+
- Xcode 15+
- macOS 13+

### Building

```bash
swift build
```

### Running Tests

```bash
# Unit + service tests (no network required)
swift test

# Integration tests (requires live API key)
ANTHROPIC_API_KEY=sk-ant-... swift test --filter Integration
```

All unit and service tests must pass without network access. Integration tests skip
automatically when `ANTHROPIC_API_KEY` is not set.

## Adding a New API Endpoint

Follow the 9-step checklist in [CLAUDE.md](CLAUDE.md#checklist-for-adding-a-new-public-api-endpoint):

1. Create request/response types in `Sources/Anthropic/Types/<Group>/`
2. Add a JSON round-trip unit test
3. Add a canned JSON fixture in `MockResponses.swift`
4. Implement the service method in `Sources/Anthropic/Services/`
5. Add a service test using `MockHTTPClient`
6. Add an integration test guarded by `ANTHROPIC_API_KEY`
7. Update or add an example in `Examples/`
8. Add `///` doc comments to all public types and methods
9. Add an ADR in `Docs/ADR/` if the feature introduces a new architectural decision

## Conventions

- **Zero external dependencies** in the `Anthropic` target. Only `Foundation` and `URLSession` are allowed.
- **All HTTP calls** go through the `HTTPClient` protocol -- never call `URLSession` directly.
- **Request and Response** are always separate types.
- **All public types** must conform to `Sendable`.
- **Use `JSONCoding.encoder` / `JSONCoding.decoder`** -- never instantiate standalone JSON coders.
- Follow existing naming patterns and code style.

## Pull Request Guidelines

- Keep PRs focused on a single change
- Include tests for new functionality
- Ensure all existing tests pass (`swift test`)
- Update documentation if behavior changes
- Reference any related issues in the PR description

## Reporting Issues

- Use [GitHub Issues](https://github.com/taumatix/anthropic-swift/issues) to report bugs
- Include the Swift version, platform, and minimal reproduction steps
- Check existing issues before creating a new one

## Code of Conduct

This project follows the [Contributor Covenant Code of Conduct](CODE_OF_CONDUCT.md).
By participating, you are expected to uphold this code.

## License

By contributing, you agree that your contributions will be licensed under the [MIT License](LICENSE).
