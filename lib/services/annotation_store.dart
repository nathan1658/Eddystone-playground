import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/beacon_annotation.dart';

abstract class BeaconAnnotationStore extends ChangeNotifier {
  Map<String, BeaconAnnotation> get annotations;

  BeaconAnnotation? annotationFor(String beaconId) => annotations[beaconId];

  Future<void> load();

  Future<void> save(BeaconAnnotation annotation);

  Future<void> delete(String beaconId);
}

class SharedPreferencesAnnotationStore extends BeaconAnnotationStore {
  static const String _storageKey = 'beacon_annotations_v1';

  final Map<String, BeaconAnnotation> _annotations = {};
  SharedPreferences? _preferences;

  @override
  Map<String, BeaconAnnotation> get annotations =>
      Map.unmodifiable(_annotations);

  @override
  Future<void> load() async {
    _preferences = await SharedPreferences.getInstance();
    final raw = _preferences?.getString(_storageKey);
    if (raw == null || raw.isEmpty) {
      return;
    }
    final decoded = jsonDecode(raw) as Map<String, Object?>;
    _annotations
      ..clear()
      ..addEntries(
        decoded.entries.map((entry) {
          return MapEntry(
            entry.key,
            BeaconAnnotation.fromJson(entry.value! as Map<String, Object?>),
          );
        }),
      );
    notifyListeners();
  }

  @override
  Future<void> save(BeaconAnnotation annotation) async {
    _annotations[annotation.beaconId] = annotation;
    await _persist();
    notifyListeners();
  }

  @override
  Future<void> delete(String beaconId) async {
    _annotations.remove(beaconId);
    await _persist();
    notifyListeners();
  }

  Future<void> _persist() async {
    final prefs = _preferences ??= await SharedPreferences.getInstance();
    final payload = _annotations.map(
      (key, value) => MapEntry(key, value.toJson()),
    );
    await prefs.setString(_storageKey, jsonEncode(payload));
  }
}

class MemoryAnnotationStore extends BeaconAnnotationStore {
  MemoryAnnotationStore([Map<String, BeaconAnnotation>? seed]) {
    _annotations.addAll(seed ?? const {});
  }

  final Map<String, BeaconAnnotation> _annotations = {};

  @override
  Map<String, BeaconAnnotation> get annotations =>
      Map.unmodifiable(_annotations);

  @override
  Future<void> load() async {}

  @override
  Future<void> save(BeaconAnnotation annotation) async {
    _annotations[annotation.beaconId] = annotation;
    notifyListeners();
  }

  @override
  Future<void> delete(String beaconId) async {
    _annotations.remove(beaconId);
    notifyListeners();
  }
}
