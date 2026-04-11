class LifecycleHooks {
  final Future<bool> Function()? onBeforeReload;
  final Future<void> Function()? onAfterReload;
  final Future<void> Function()? onBeforeRestart;
  final Future<void> Function()? onAfterRestart;
  final Future<void> Function(String filePath)? onFileChanged;
  final Future<void> Function(String error)? onError;

  const LifecycleHooks({
    this.onBeforeReload,
    this.onAfterReload,
    this.onBeforeRestart,
    this.onAfterRestart,
    this.onFileChanged,
    this.onError,
  });

  static const LifecycleHooks none = LifecycleHooks();
}
