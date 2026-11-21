
enum ProtectionTargetType {
  executable,
  windowHandle,
}

enum ProtectionSource {
  executableRule,
  selectedWindow,
  foregroundWindow,
}

enum ProtectionStatus {
  waiting,
  active,
  unavailable,
  failed,
}

class ProtectionTarget {
  const ProtectionTarget({
    required this.id,
    required this.type,
    required this.source,
    required this.createdAt,
    this.executablePath,
    this.handle,
    this.processId,
    this.windowTitle,
    this.showBorder = true,
    this.status = ProtectionStatus.waiting,
  });

  /// Stable identity within the protection list.
  final String id;

  final ProtectionTargetType type;
  final ProtectionSource source;
  final DateTime createdAt;

  /// Used by executable rules.
  final String? executablePath;

  /// Used by individual window targets.
  final int? handle;
  final int? processId;
  final String? windowTitle;

  final bool showBorder;
  final ProtectionStatus status;

  factory ProtectionTarget.forExecutable(String path) {
    final normalizedPath = path.trim();

    return ProtectionTarget(
      id: 'exe:${normalizedPath.toLowerCase()}',
      type: ProtectionTargetType.executable,
      source: ProtectionSource.executableRule,
      executablePath: normalizedPath,
      createdAt: DateTime.now(),
    );
  }

  factory ProtectionTarget.forWindow({
    required int handle,
    required int processId,
    required String title,
    bool fromForeground = false,
  }) {
    return ProtectionTarget(
      id: 'hwnd:$processId:$handle',
      type: ProtectionTargetType.windowHandle,
      source: fromForeground
          ? ProtectionSource.foregroundWindow
          : ProtectionSource.selectedWindow,
      handle: handle,
      processId: processId,
      windowTitle: title,
      createdAt: DateTime.now(),
      status: ProtectionStatus.waiting,
    );
  }

  ProtectionTarget copyWith({
    bool? showBorder,
    ProtectionStatus? status,
    String? windowTitle,
  }) {
    return ProtectionTarget(
      id: id,
      type: type,
      source: source,
      createdAt: createdAt,
      executablePath: executablePath,
      handle: handle,
      processId: processId,
      windowTitle: windowTitle ?? this.windowTitle,
      showBorder: showBorder ?? this.showBorder,
      status: status ?? this.status,
    );
  }
}
