
import 'package:flutter/foundation.dart';

import '../models/protection_target.dart';

class ProtectionService extends ChangeNotifier {
  final List<ProtectionTarget> _targets = [];

  List<ProtectionTarget> get targets =>
      List.unmodifiable(_targets);

  int get targetCount => _targets.length;

  int get activeCount => _targets
      .where((target) => target.status == ProtectionStatus.active)
      .length;

  /// Add an executable protection rule.
  /// Returns false if the rule already exists.
  bool addExecutable(String path) {
    final normalizedPath = _normalizePath(path);

    if (normalizedPath.isEmpty) {
      return false;
    }

    final id = 'exe:$normalizedPath';

    if (_targets.any((target) => target.id == id)) {
      return false;
    }

    _targets.add(
      ProtectionTarget.forExecutable(normalizedPath),
    );

    notifyListeners();
    return true;
  }

  /// Add an individual window.
  /// PID is included to reduce the risk of HWND reuse.
  bool addWindow({
    required int handle,
    required int processId,
    required String title,
    bool fromForeground = false,
  }) {
    if (handle == 0 || processId <= 0) {
      return false;
    }

    final id = 'hwnd:$processId:$handle';

    if (_targets.any((target) => target.id == id)) {
      return false;
    }

    _targets.add(
      ProtectionTarget.forWindow(
        handle: handle,
        processId: processId,
        title: title,
        fromForeground: fromForeground,
      ),
    );

    notifyListeners();
    return true;
  }

  /// Remove a protection target by its stable ID.
  bool removeTarget(String id) {
    final oldLength = _targets.length;

    _targets.removeWhere((target) => target.id == id);

    if (_targets.length == oldLength) {
      return false;
    }

    notifyListeners();
    return true;
  }

  /// Update the runtime status of a target.
  void updateStatus(
    String id,
    ProtectionStatus status,
  ) {
    final index = _targets.indexWhere(
      (target) => target.id == id,
    );

    if (index == -1) return;

    _targets[index] = _targets[index].copyWith(
      status: status,
    );

    notifyListeners();
  }

  /// Toggle the visual border independently of protection.
  void setBorderVisible(String id, bool visible) {
    final index = _targets.indexWhere(
      (target) => target.id == id,
    );

    if (index == -1) return;

    _targets[index] = _targets[index].copyWith(
      showBorder: visible,
    );

    notifyListeners();
  }

  /// Find a target by ID.
  ProtectionTarget? findTarget(String id) {
    for (final target in _targets) {
      if (target.id == id) {
        return target;
      }
    }

    return null;
  }

  String _normalizePath(String path) {
    return path
        .trim()
        .replaceAll('/', r'\')
        .toLowerCase();
  }
}
