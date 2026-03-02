import 'package:childsafe_package/src/model/swipe_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // for rootBundle
import 'dart:math';

class SwipePathTracker {
  final int pointerId;
  final List<Offset> points = [];
  DateTime? startTime;

  SwipePathTracker(this.pointerId);

  void addPoint(Offset point) {
    if (points.isEmpty) {
      startTime = DateTime.now();
    }
    points.add(point);
  }

  SwipeData? finish() {
    if (points.length < 2 || startTime == null) return null;

    final endTime = DateTime.now();
    final time = endTime.difference(startTime!);

    if (time.inMilliseconds == 0) return null;

    double totalDistance = 0.0;
    for (int i = 0; i < points.length - 1; i++) {
      totalDistance += (points[i + 1] - points[i]).distance;
    }

    final straightLineDistance = (points.last - points.first).distance;
    final speed = totalDistance / (time.inMilliseconds / 1000.0);

    double erraticness = 0.0;
    if (totalDistance > 0) {
      erraticness = (totalDistance - straightLineDistance) / totalDistance;
      erraticness = max(0.0, min(1.0, erraticness));
    }

    return SwipeData(
      distance: totalDistance,
      time: time,
      speed: speed,
      erraticness: erraticness,
    );
  }
}

class BiometricsController extends ChangeNotifier {
  final TextEditingController textController = TextEditingController();

  final List<int> _keyTimestamps = [];
  int _backspaceCount = 0;
  int _totalKeys = 0;
  String _lastValue = '';

  double _ikiMean = 0;
  double _ikiStd = 0;
  double _backspaceRate = 0;
  double _typoRate = 0;
  double _avgWordLen = 0;
  double _shortWordRatio = 0;

  Set<String> _dictionary = {};
  bool _isLoading = true;

  double get ikiMean => _ikiMean;
  double get ikiStd => _ikiStd;
  double get backspaceRate => _backspaceRate;
  double get typosPer100 => _typoRate;
  double get avgWordLen => _avgWordLen;
  double get shortWordRatio => _shortWordRatio;
  bool get isLoading => _isLoading;
  int get totalKeystrokes => _totalKeys;
  int get backspaceCount => _backspaceCount;

  final Map<int, SwipePathTracker> _activeSwipes = {};
  final List<SwipeData> _completedSwipes = [];

  List<SwipeData> get completedSwipes => List.unmodifiable(_completedSwipes);

  double get swipeSpeedMean {
    if (_completedSwipes.isEmpty) return 0.0;
    final totalSpeed = _completedSwipes.fold<double>(
      0.0,
      (sum, item) => sum + item.speed,
    );
    return totalSpeed / _completedSwipes.length;
  }

  double get swipeSpeedStd {
    if (_completedSwipes.isEmpty) return 0.0;
    final mean = swipeSpeedMean;
    double sumSquaredDiffs = 0.0;
    for (final swipe in _completedSwipes) {
      final diff = swipe.speed - mean;
      sumSquaredDiffs += diff * diff;
    }
    return sqrt(sumSquaredDiffs / _completedSwipes.length);
  }

  double get pathErraticness {
    if (_completedSwipes.isEmpty) return 0.0;
    final totalErraticness = _completedSwipes.fold<double>(
      0.0,
      (sum, item) => sum + item.erraticness,
    );
    return totalErraticness / _completedSwipes.length;
  }

  BiometricsController() {
    _loadDictionary();
  }

  Future<void> _loadDictionary() async {
    try {
      // NOTE THE PACKAGE PREFIX HERE!
      final content = await rootBundle.loadString(
        'packages/childsafe_package/assets/vocab.txt',
      );
      _dictionary = content
          .split('\n')
          .map((word) => word.trim().toLowerCase())
          .where((word) => word.isNotEmpty)
          .toSet();
    } catch (e) {
      debugPrint("Error loading vocab.txt: $e");
    }

    _isLoading = false;
    notifyListeners();
  }

  void clearData({bool clearText = true}) {
    if (clearText) {
      textController.clear();
      _lastValue = '';
    }
    _keyTimestamps.clear();
    _backspaceCount = 0;
    _totalKeys = 0;
    _ikiMean = 0;
    _ikiStd = 0;
    _backspaceRate = 0;
    _typoRate = 0;
    _avgWordLen = 0;
    _shortWordRatio = 0;
    _completedSwipes.clear();
    _activeSwipes.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    textController.dispose();
    super.dispose();
  }

  void onTextChanged(String value) {
    if (_isLoading) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    if (value.length < _lastValue.length) {
      _backspaceCount++;
    }

    _keyTimestamps.add(now);
    _totalKeys = (_totalKeys + 1).clamp(0, 99999);
    _lastValue = value;

    _calculateMetrics(value);
  }

  void _calculateMetrics(String text) {
    if (_keyTimestamps.length > 1) {
      List<int> intervals = [];
      for (int i = 1; i < _keyTimestamps.length; i++) {
        int diff = _keyTimestamps[i] - _keyTimestamps[i - 1];
        if (diff < 2000) {
          intervals.add(diff);
        }
      }

      if (intervals.isNotEmpty) {
        _ikiMean = intervals.reduce((a, b) => a + b) / intervals.length;
        final mean = _ikiMean;
        _ikiStd = sqrt(
          intervals.map((x) => pow(x - mean, 2)).reduce((a, b) => a + b) /
              intervals.length,
        );
      }
    }

    _backspaceRate = _totalKeys > 0 ? _backspaceCount / _totalKeys : 0;
    List<String> words = text.trim().toLowerCase().split(RegExp(r'\s+'));
    int typos = 0;
    int validWordCount = 0;
    int totalWordLen = 0;
    int shortWordCount = 0;

    for (var w in words) {
      if (w.isNotEmpty) {
        validWordCount++;
        totalWordLen += w.length;
        if (w.length <= 4) {
          shortWordCount++;
        }
        if (!_dictionary.contains(w)) {
          typos++;
        }
      }
    }

    _typoRate = validWordCount > 0 ? (typos / validWordCount) * 100 : 0;
    _avgWordLen = validWordCount > 0 ? (totalWordLen / validWordCount) : 0;
    _shortWordRatio = validWordCount > 0
        ? (shortWordCount / validWordCount)
        : 0;

    notifyListeners();
  }

  void onFocusOut(String text) => _calculateMetrics(text);
  void onEditingComplete() => notifyListeners();

  void handlePointerDown(PointerDownEvent event) {
    _activeSwipes[event.pointer] = SwipePathTracker(event.pointer)
      ..addPoint(event.position);
  }

  void handlePointerMove(PointerMoveEvent event) {
    if (_activeSwipes.containsKey(event.pointer)) {
      _activeSwipes[event.pointer]!.addPoint(event.position);
    }
  }

  void handlePointerUp(PointerUpEvent event) {
    if (_activeSwipes.containsKey(event.pointer)) {
      _activeSwipes[event.pointer]!.addPoint(event.position);
      final swipeData = _activeSwipes[event.pointer]!.finish();
      if (swipeData != null) {
        _completedSwipes.add(swipeData);
        notifyListeners();
      }
      _activeSwipes.remove(event.pointer);
    }
  }

  void handlePointerCancel(PointerCancelEvent event) {
    _activeSwipes.remove(event.pointer);
  }
}
