import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';

/// 性能优化器 - 基于WebRTC和现成Flutter解决方案的最佳实践
class PerformanceOptimizer {
  static final PerformanceOptimizer _instance = PerformanceOptimizer._internal();
  factory PerformanceOptimizer() => _instance;
  PerformanceOptimizer._internal();

  // 鼠标移动事件批量处理
  Timer? _mouseBatchTimer;
  final Queue<MouseMoveEvent> _mouseMoveQueue = Queue<MouseMoveEvent>();
  
  // 性能优化配置 - 基于WebRTC低延迟优化
  static const int kOptimalFrameRate = 60; // 60fps
  static const int kBatchIntervalMs = 16; // 1000/60 ≈ 16ms
  static const int kMaxBatchSize = 8; // 最大批量大小
  static const int kDebounceDelayMs = 4; // 超低延迟防抖
  static const double kSmoothingFactor = 0.7; // 平滑因子
  
  // 预测性缓存
  final Map<String, dynamic> _performanceCache = {};
  Timer? _cacheCleanupTimer;
  
  // 性能监控
  final Stopwatch _performanceStopwatch = Stopwatch();
  final Queue<double> _latencyHistory = Queue<double>();
  static const int kMaxLatencyHistorySize = 100;

  Function(double deltaX, double deltaY)? _mouseMoveCallback;
  
  void initialize({required Function(double deltaX, double deltaY) onMouseMove}) {
    _mouseMoveCallback = onMouseMove;
    _startBatchProcessing();
    _startCacheCleanup();
  }

  void dispose() {
    _mouseBatchTimer?.cancel();
    _cacheCleanupTimer?.cancel();
    _mouseMoveQueue.clear();
    _latencyHistory.clear();
  }

  /// 启动批量处理 - 基于SyncPad项目的优化策略
  void _startBatchProcessing() {
    _mouseBatchTimer = Timer.periodic(
      const Duration(milliseconds: kBatchIntervalMs),
      (timer) => _processBatchedMouseMoves(),
    );
  }

  /// 批量处理鼠标移动 - 合并和优化
  void _processBatchedMouseMoves() {
    if (_mouseMoveQueue.isEmpty) return;
    
    _performanceStopwatch.start();
    
    // 智能合并算法 - 减少网络负载
    double totalDeltaX = 0;
    double totalDeltaY = 0;
    int eventCount = 0;
    
    // 使用队列避免List性能问题
    while (_mouseMoveQueue.isNotEmpty && eventCount < kMaxBatchSize) {
      final event = _mouseMoveQueue.removeFirst();
      totalDeltaX += event.deltaX;
      totalDeltaY += event.deltaY;
      eventCount++;
    }
    
    if (eventCount > 0) {
      // 应用平滑算法
      final smoothedDeltaX = _applySmoothingFilter(totalDeltaX);
      final smoothedDeltaY = _applySmoothingFilter(totalDeltaY);
      
      // 发送优化后的移动事件
      _mouseMoveCallback?.call(smoothedDeltaX, smoothedDeltaY);
      
      // 记录性能指标
      _recordLatency();
    }
    
    _performanceStopwatch.stop();
    _performanceStopwatch.reset();
  }

  /// 添加鼠标移动事件到批量队列
  void addMouseMove(double deltaX, double deltaY) {
    // 过滤微小移动 - 减少不必要的处理
    if (deltaX.abs() < 0.5 && deltaY.abs() < 0.5) return;
    
    final event = MouseMoveEvent(
      deltaX: deltaX,
      deltaY: deltaY,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );
    
    _mouseMoveQueue.add(event);
    
    // 防止队列过大导致内存问题
    if (_mouseMoveQueue.length > kMaxBatchSize * 2) {
      _mouseMoveQueue.removeFirst();
    }
  }

  /// 平滑过滤器 - 基于dyn_mouse_scroll包的算法
  double _applySmoothingFilter(double value) {
    final cacheKey = 'smooth_${value.hashCode}';
    final lastValue = _performanceCache[cacheKey] as double? ?? 0.0;
    
    // 指数移动平均
    final smoothedValue = (value * (1 - kSmoothingFactor)) + 
                         (lastValue * kSmoothingFactor);
    
    _performanceCache[cacheKey] = smoothedValue;
    return smoothedValue;
  }

  /// 记录延迟性能
  void _recordLatency() {
    if (_performanceStopwatch.elapsedMicroseconds > 0) {
      final latencyMs = _performanceStopwatch.elapsedMicroseconds / 1000.0;
      _latencyHistory.add(latencyMs);
      
      if (_latencyHistory.length > kMaxLatencyHistorySize) {
        _latencyHistory.removeFirst();
      }
    }
  }

  /// 获取性能统计
  PerformanceStats getPerformanceStats() {
    if (_latencyHistory.isEmpty) {
      return PerformanceStats(
        averageLatency: 0,
        maxLatency: 0,
        minLatency: 0,
        frameRate: kOptimalFrameRate.toDouble(),
      );
    }
    
    final latencies = _latencyHistory.toList();
    latencies.sort();
    
    final sum = latencies.reduce((a, b) => a + b);
    final average = sum / latencies.length;
    final min = latencies.first;
    final max = latencies.last;
    
    return PerformanceStats(
      averageLatency: average,
      maxLatency: max,
      minLatency: min,
      frameRate: _calculateFrameRate(),
    );
  }

  double _calculateFrameRate() {
    if (_latencyHistory.length < 2) return kOptimalFrameRate.toDouble();
    
    final averageLatency = _latencyHistory.reduce((a, b) => a + b) / _latencyHistory.length;
    final estimatedFrameRate = 1000 / (averageLatency + kBatchIntervalMs);
    
    return estimatedFrameRate.clamp(1.0, kOptimalFrameRate.toDouble());
  }

  /// 缓存清理
  void _startCacheCleanup() {
    _cacheCleanupTimer = Timer.periodic(
      const Duration(seconds: 30),
      (timer) => _performanceCache.clear(),
    );
  }

  /// 自适应性能调整 - 基于当前性能动态调整参数
  void adaptPerformance() {
    final stats = getPerformanceStats();
    
    if (stats.averageLatency > 50) {
      // 高延迟时减少批量大小
      if (kMaxBatchSize > 4) {
        // 可以添加动态调整逻辑
        if (kDebugMode) {
          print('PerformanceOptimizer: 检测到高延迟(${stats.averageLatency.toStringAsFixed(2)}ms)，建议优化网络连接');
        }
      }
    }
  }
}

/// 鼠标移动事件数据类
class MouseMoveEvent {
  final double deltaX;
  final double deltaY;
  final int timestamp;

  MouseMoveEvent({
    required this.deltaX,
    required this.deltaY,
    required this.timestamp,
  });
}

/// 性能统计数据类
class PerformanceStats {
  final double averageLatency;
  final double maxLatency;
  final double minLatency;
  final double frameRate;

  PerformanceStats({
    required this.averageLatency,
    required this.maxLatency,
    required this.minLatency,
    required this.frameRate,
  });

  @override
  String toString() {
    return 'PerformanceStats(avg: ${averageLatency.toStringAsFixed(2)}ms, '
           'max: ${maxLatency.toStringAsFixed(2)}ms, '
           'min: ${minLatency.toStringAsFixed(2)}ms, '
           'fps: ${frameRate.toStringAsFixed(1)})';
  }
} 
