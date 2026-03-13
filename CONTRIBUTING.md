# Contributing to Tiercel

Thanks for your interest in improving Tiercel. Bug fixes, documentation updates, tests, performance improvements, and well-scoped feature proposals are all welcome.

## Before You Start

- Read [README.md](README.md) for project context, supported platforms, and integration options.
- Read [SECURITY.md](SECURITY.md) before reporting anything that may have security impact.
- Search existing issues and pull requests before starting work on a larger change.
- Open an issue first if you want to discuss a new feature, behavior change, or public API adjustment.

## Ways to Contribute

### Bug Reports

Please include:

- the Tiercel version you are using
- your integration method, such as CocoaPods, Swift Package Manager, or manual integration
- iOS, Swift, and Xcode versions
- clear reproduction steps
- expected behavior and actual behavior
- logs, screenshots, or a small sample project if they help

### Feature Requests

Feature requests are most helpful when they explain:

- the problem you are trying to solve
- why the current API is not enough
- the expected API or behavior
- any compatibility or migration concerns

### Documentation Improvements

Small documentation fixes are always welcome. If you notice unclear wording, outdated examples, or missing guidance, feel free to open a pull request directly.

## Development Notes

The main repository layout is:

- `Sources/`: framework source code
- `TiercelTests/`: Xcode test target
- `Demo/`: sample app for manual validation

For local work:

- Open `Tiercel.xcodeproj` to work on the library and `TiercelTests`.
- Open `Demo/Tiercel-Demo.xcodeproj` if your change affects runtime behavior and you want to validate it in the sample app.
- Prefer Xcode-based validation for this repository. `Package.swift` currently does not define a SwiftPM test target, so `swift test` is not the default verification path here.

## Pull Request Expectations

Before opening a pull request:

- keep the change focused on one problem
- add or update tests when practical
- describe the motivation and the approach clearly
- list the validation you performed, such as running `TiercelTests` or checking the demo app flow
- update documentation if the public behavior or API changes

When possible, avoid mixing unrelated refactors with the main fix or feature.

## Style and Review Notes

- Keep changes compatible with the current project baseline: iOS 12.0+ and Swift 5.0+.
- Prefer simple, maintainable fixes over large rewrites.
- Be careful with changes around task lifecycle, persistence, resume data, and thread safety, since those areas are central to Tiercel.
- Keep discussion respectful, constructive, and focused on the code and user impact.

## Security Issues

If you believe you found a security vulnerability, please do not open a public issue. Follow the private reporting guidance in [SECURITY.md](SECURITY.md).
