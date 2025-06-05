import 'package:flutter/material.dart';
import 'dart:async';
import '../services/performance_optimizer.dart';

/// 性能监控小部件 - 实时显示优化效果
class PerformanceMonitorWidget extends StatefulWidget {
  const PerformanceMonitorWidget({super.key});

  @override
  State<PerformanceMonitorWidget> createState() => _PerformanceMonitorWidgetState();
}

class _PerformanceMonitorWidgetState extends State<PerformanceMonitorWidget> {
  final PerformanceOptimizer _optimizer = PerformanceOptimizer();
  Timer? _updateTimer;
  PerformanceStats? _currentStats;
  bool _isVisible = false;

  @override
  void initState() {
    super.initState();
    _startMonitoring();
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    super.dispose();
  }

  void _startMonitoring() {
    _updateTimer = Timer.periodic(
      const Duration(seconds: 1),
      (timer) {
        if (mounted) {
          setState(() {
            _currentStats = _optimizer.getPerformanceStats();
            _optimizer.adaptPerformance();
          });
        }
      },
    );
  }

  void _toggleVisibility() {
    setState(() {
      _isVisible = !_isVisible;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 50,
      right: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // 切换按钮
          FloatingActionButton.small(
            onPressed: _toggleVisibility,
            backgroundColor: _isVisible ? Colors.red.shade400 : Colors.blue.shade400,
            child: Icon(
              _isVisible ? Icons.close : Icons.speed,
              color: Colors.white,
            ),
          ),
          
          if (_isVisible) ...[
            const SizedBox(height: 8),
            
            // 性能监控面板
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 标题
                  Row(
                    children: [
                      Icon(
                        Icons.speed,
                        color: Colors.green.shade400,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        '性能监控',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Divider(color: Colors.grey, height: 1),
                  const SizedBox(height: 8),
                  
                  // 性能指标
                  if (_currentStats != null) ...[
                    _buildMetricRow('平均延迟', '${_currentStats!.averageLatency.toStringAsFixed(1)}ms', _getLatencyColor(_currentStats!.averageLatency)),
                    _buildMetricRow('最大延迟', '${_currentStats!.maxLatency.toStringAsFixed(1)}ms', Colors.orange),
                    _buildMetricRow('最小延迟', '${_currentStats!.minLatency.toStringAsFixed(1)}ms', Colors.green),
                    _buildMetricRow('帧率', '${_currentStats!.frameRate.toStringAsFixed(1)}fps', _getFrameRateColor(_currentStats!.frameRate)),
                  ] else ...[
                    const Text(
                      '正在收集数据...',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMetricRow(String label, String value, Color valueColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 60,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 11,
              ),
            ),
          ),
          const Text(
            ': ',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 11,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: valueColor,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Color _getLatencyColor(double latency) {
    if (latency <= 50) return Colors.green;
    if (latency <= 100) return Colors.orange;
    return Colors.red;
  }

  Color _getFrameRateColor(double frameRate) {
    if (frameRate >= 45) return Colors.green;
    if (frameRate >= 30) return Colors.orange;
    return Colors.red;
  }
}