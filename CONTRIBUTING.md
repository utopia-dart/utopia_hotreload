# Contributing to Utopia Hot Reload

Thank you for your interest in contributing to Utopia Hot Reload! This document provides guidelines and information for contributors.

## 🚀 Getting Started

### Prerequisites

- Dart SDK 3.0.0 or higher
- Git
- A GitHub account

### Development Setup

1. **Fork the repository** on GitHub
2. **Clone your fork** locally:
   ```bash
   git clone https://github.com/YOUR_USERNAME/utopia_hotreload.git
   cd utopia_hotreload
   ```
3. **Install dependencies**:
   ```bash
   dart pub get
   ```
4. **Create a branch** for your feature:
   ```bash
   git checkout -b feature/your-feature-name
   ```

## 🏗️ Project Structure

```
lib/
├── utopia_hotreload.dart          # Main library entry point
└── src/
    ├── developer_tools.dart       # Core DeveloperTools class
    ├── file_watcher.dart          # File system watching
    ├── file_pattern_matcher.dart  # Advanced pattern matching
    ├── keyboard_input_handler.dart # Keyboard input handling
    ├── lifecycle_hooks.dart       # Lifecycle hook callbacks
    ├── multi_service_manager.dart # Multi-service coordination
    ├── reload_config.dart         # Reload configuration
    ├── reload_config_file.dart    # YAML config file support
    ├── service_config.dart        # Service configuration
    └── dashboard/
        ├── dashboard_service.dart # Web dashboard server
        ├── metrics_collector.dart # Performance metrics
        └── reload_history.dart    # Reload event tracking
bin/
└── utopia_hotreload.dart          # CLI executable
```

## 💡 Contributing Guidelines

### Code Style

- Follow [Dart's official style guide](https://dart.dev/guides/language/effective-dart/style)
- Use `dart format` to format your code
- Use `dart analyze` to check for issues
- Add doc comments for public APIs

### Commit Messages

Use conventional commit format:
- `feat: add new feature`
- `fix: resolve bug`
- `docs: update documentation`
- `test: add or update tests`
- `refactor: code improvements`
- `chore: maintenance tasks`

Example:
```bash
git commit -m "feat: add support for watching custom file extensions"
```

### Pull Requests

1. **Create an issue first** for significant changes
2. **Write descriptive PR titles** and descriptions
3. **Include tests** for new functionality
4. **Update documentation** as needed
5. **Ensure CI passes** (tests, formatting, analysis)

## 🧪 Testing

### Running Tests

```bash
# Run all tests
dart test

# Run tests with coverage
dart test --coverage=coverage
genhtml coverage/lcov.info -o coverage/html
```

### Writing Tests

- Add tests for new features in `test/`
- Test both success and error cases
- Mock external dependencies when needed
- Include integration tests for complex features

Example test structure:
```dart
import 'package:test/test.dart';
import 'package:utopia_hotreload/utopia_hotreload.dart';

void main() {
  group('DeveloperTools', () {
    test('should start with default configuration', () async {
      // Test implementation
    });

    test('should handle file changes correctly', () async {
      // Test implementation
    });
  });
}
```

## 🐛 Reporting Issues

### Bug Reports

When reporting bugs, include:

1. **Clear description** of the issue
2. **Steps to reproduce** the problem
3. **Expected vs actual behavior**
4. **System information** (OS, Dart version)
5. **Code samples** if applicable
6. **Error messages** or logs

Use this template:

```markdown
## Bug Description
Brief description of the issue.

## Steps to Reproduce
1. Step one
2. Step two
3. Step three

## Expected Behavior
What you expected to happen.

## Actual Behavior
What actually happened.

## Environment
- OS: [e.g., Windows 11, macOS 12.0, Ubuntu 20.04]
- Dart version: [e.g., 2.19.0]
- Package version: [e.g., 1.0.0]

## Additional Context
Any other relevant information.
```

### Feature Requests

For new features:

1. **Describe the use case** clearly
2. **Explain the benefits** 
3. **Provide examples** of how it would work
4. **Consider backwards compatibility**

## 🔧 Development Workflow

### Local Development

1. **Make your changes** in a feature branch
2. **Test your changes**:
   ```bash
   dart analyze
   dart format --set-exit-if-changed .
   dart test
   ```
3. **Test with the example**:
   ```bash
   cd example
   dart run example.dart
   ```
4. **Update documentation** if needed

### Integration Testing

Test your changes with real applications:

1. **HTTP servers** - Ensure hot reload preserves connections
2. **CLI applications** - Test console output and input handling
3. **Different file types** - Verify watching works for various extensions
4. **Cross-platform** - Test on different operating systems if possible

## 📖 Documentation

### API Documentation

- Add comprehensive doc comments for public APIs
- Include usage examples in doc comments
- Document parameters, return values, and exceptions
- Use markdown formatting in doc comments

Example:
```dart
/// Starts a development server with hot reload capabilities.
///
/// This method sets up file watching, process management, and interactive
/// commands to provide a seamless development experience similar to Flutter.
///
/// ## Parameters
///
/// - [script]: The main function of your application
/// - [watchPaths]: List of directory paths to monitor for changes
/// - [verbose]: Enable detailed logging for debugging
///
/// ## Example
///
/// ```dart
/// await DeveloperTools.start(
///   script: () async {
///     print('Hello, hot reload!');
///   },
///   watchPaths: ['lib', 'bin'],
///   verbose: true,
/// );
/// ```
static Future<void> start({...}) async {
  // Implementation
}
```

### README Updates

When adding features:
- Update the features list
- Add usage examples
- Update configuration tables
- Include troubleshooting info if needed

## 🚀 Release Process

For maintainers:

1. **Update version** in `pubspec.yaml`
2. **Update CHANGELOG.md** with changes
3. **Create a release tag**:
   ```bash
   git tag v1.0.1
   git push origin v1.0.1
   ```
4. **Publish to pub.dev**:
   ```bash
   dart pub publish
   ```

## 💬 Community

- **Discussions**: Use GitHub Discussions for questions and ideas
- **Issues**: Report bugs and request features via GitHub Issues
- **Pull Requests**: Submit code changes via GitHub PRs

## 📄 License

By contributing to this project, you agree that your contributions will be licensed under the MIT License.

## ❓ Questions?

If you have questions about contributing, feel free to:

1. **Open a discussion** on GitHub
2. **Create an issue** with the question label
3. **Check existing issues** for similar questions

Thank you for contributing to Utopia Hot Reload! 🔥
