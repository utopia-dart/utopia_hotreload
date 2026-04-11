import 'dart:io';

import 'package:yaml/yaml.dart';

import 'reload_config.dart';

/// Loads hot reload configuration from a YAML file.
///
/// Looks for `hotreload.yaml` in the project root by default.
class ReloadConfigFile {
  static const String defaultFileName = 'hotreload.yaml';

  /// Loads configuration from a YAML file.
  ///
  /// Returns null if the file doesn't exist.
  /// Throws [FormatException] if the file exists but has invalid format.
  static ReloadConfig? load([String? filePath]) {
    final path = filePath ?? defaultFileName;
    final file = File(path);

    if (!file.existsSync()) return null;

    final content = file.readAsStringSync();
    if (content.trim().isEmpty) return null;

    final yaml = loadYaml(content);
    if (yaml == null) return null;
    if (yaml is! YamlMap) {
      throw FormatException(
        'Invalid hotreload.yaml: expected a YAML map at the root',
      );
    }

    return _parseConfig(yaml);
  }

  /// Merges file config with programmatic config.
  /// Programmatic values take precedence over file values.
  static ReloadConfig merge(
    ReloadConfig fileConfig, {
    ReloadMode? mode,
    List<String>? watchPaths,
    List<String>? watchExtensions,
    List<String>? ignorePatterns,
    Duration? debounceDelay,
    bool? verbose,
    int? childVmServicePort,
    bool? enableDashboard,
    int? dashboardPort,
  }) {
    return ReloadConfig(
      mode: mode ?? fileConfig.mode,
      watchPaths: watchPaths ?? fileConfig.watchPaths,
      watchExtensions: watchExtensions ?? fileConfig.watchExtensions,
      ignorePatterns: ignorePatterns ?? fileConfig.ignorePatterns,
      debounceDelay: debounceDelay ?? fileConfig.debounceDelay,
      verbose: verbose ?? fileConfig.verbose,
      childVmServicePort: childVmServicePort ?? fileConfig.childVmServicePort,
      enableDashboard: enableDashboard ?? fileConfig.enableDashboard,
      dashboardPort: dashboardPort ?? fileConfig.dashboardPort,
    );
  }

  static ReloadConfig _parseConfig(YamlMap yaml) {
    final watchPaths =
        _parseStringList(yaml['watch_paths'] ?? yaml['watchPaths']) ?? ['lib'];

    final watchExtensions =
        _parseStringList(
          yaml['watch_extensions'] ?? yaml['watchExtensions'],
        ) ??
        ['.dart'];

    final ignorePatterns =
        _parseStringList(
          yaml['ignore_patterns'] ?? yaml['ignorePatterns'],
        ) ??
        ['.git/', '.dart_tool/', 'build/', 'pubspec.lock'];

    final debounceMs = yaml['debounce_ms'] ?? yaml['debounceMs'] ?? 500;

    final modeStr = yaml['mode'] as String? ?? 'auto';
    final mode = ReloadMode.values.firstWhere(
      (m) => m.name == modeStr,
      orElse: () => ReloadMode.auto,
    );

    final verbose = yaml['verbose'] as bool? ?? false;

    final enableDashboard =
        yaml['dashboard'] is YamlMap
            ? (yaml['dashboard']['enabled'] as bool? ?? false)
            : (yaml['enable_dashboard'] as bool? ?? false);
    final dashboardPort =
        yaml['dashboard'] is YamlMap
            ? (yaml['dashboard']['port'] as int? ?? 9000)
            : (yaml['dashboard_port'] as int? ?? 9000);

    final vmServicePort =
        (yaml['vm_service_port'] ?? yaml['vmServicePort']) as int?;

    final usePolling =
        (yaml['use_polling'] ?? yaml['usePolling']) as bool?;

    final pollingDelayMs =
        (yaml['polling_delay_ms'] ?? yaml['pollingDelayMs']) as int?;

    return ReloadConfig(
      mode: mode,
      watchPaths: watchPaths,
      watchExtensions: watchExtensions,
      ignorePatterns: ignorePatterns,
      debounceDelay: Duration(milliseconds: debounceMs as int),
      verbose: verbose,
      childVmServicePort: vmServicePort,
      enableDashboard: enableDashboard,
      dashboardPort: dashboardPort,
      usePolling: usePolling,
      pollingDelay: pollingDelayMs != null
          ? Duration(milliseconds: pollingDelayMs)
          : const Duration(seconds: 1),
    );
  }

  static List<String>? _parseStringList(dynamic value) {
    if (value == null) return null;
    if (value is YamlList) return value.cast<String>().toList();
    if (value is List) return value.cast<String>().toList();
    if (value is String) return [value];
    return null;
  }
}
