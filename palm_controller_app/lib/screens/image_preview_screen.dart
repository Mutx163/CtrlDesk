import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/file_service.dart';
import '../services/log_service.dart';

class ImagePreviewScreen extends ConsumerStatefulWidget {
  final String imagePath;
  final String fileName;

  const ImagePreviewScreen({
    super.key,
    required this.imagePath,
    required this.fileName,
  });

  @override
  ConsumerState<ImagePreviewScreen> createState() => _ImagePreviewScreenState();
}

class _ImagePreviewScreenState extends ConsumerState<ImagePreviewScreen> 
    with SingleTickerProviderStateMixin {
  final FileService _fileService = FileService.instance;
  final LogService _logService = LogService.instance;
  
  String? _imageData;
  bool _isLoading = true;
  String? _error;
  
  late TransformationController _transformationController;
  late AnimationController _animationController;
  Animation<Matrix4>? _animation;

  @override
  void initState() {
    super.initState();
    _transformationController = TransformationController();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _loadImage();
  }

  @override
  void dispose() {
    _transformationController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadImage() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      _logService.info('开始加载图片预览: ${widget.imagePath}', category: 'ImagePreview');
      
      final imageData = await _fileService.getImagePreview(widget.imagePath);
      
      if (mounted) {
        if (imageData != null && imageData.isNotEmpty) {
          setState(() {
            _imageData = imageData;
            _isLoading = false;
          });
          _logService.info('图片预览加载成功', category: 'ImagePreview');
        } else {
          setState(() {
            _error = '无法获取图片数据';
            _isLoading = false;
          });
          _logService.warning('图片预览数据为空', category: 'ImagePreview');
        }
      }
    } catch (e) {
      _logService.error('图片预览加载失败: $e', category: 'ImagePreview');
      if (mounted) {
        setState(() {
          _error = '加载失败: $e';
          _isLoading = false;
        });
      }
    }
  }

  void _resetZoom() {
    final Matrix4 resetMatrix = Matrix4.identity();
    _animation = Matrix4Tween(
      begin: _transformationController.value,
      end: resetMatrix,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    
    _animationController.reset();
    _animationController.forward();
    
    _animation!.addListener(() {
      _transformationController.value = _animation!.value;
    });
  }

  Widget _buildImageWidget() {
    if (_imageData == null) return const SizedBox.shrink();

    try {
      // 解码Base64图片数据
      final Uint8List imageBytes = base64Decode(_imageData!);
      
      return InteractiveViewer(
        transformationController: _transformationController,
        minScale: 0.5,
        maxScale: 5.0,
        child: Image.memory(
          imageBytes,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            _logService.error('图片解码失败: $error', category: 'ImagePreview');
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.broken_image,
                    size: 64,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '图片格式不支持',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ],
              ),
            );
          },
        ),
      );
    } catch (e) {
      _logService.error('Base64解码失败: $e', category: 'ImagePreview');
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              '图片数据格式错误',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          widget.fileName,
          style: const TextStyle(fontSize: 16),
        ),
        actions: [
          if (!_isLoading && _imageData != null)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadImage,
              tooltip: '重新加载',
            ),
          if (!_isLoading && _imageData != null)
            IconButton(
              icon: const Icon(Icons.zoom_out_map),
              onPressed: _resetZoom,
              tooltip: '重置缩放',
            ),
        ],
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        color: Colors.black,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
            SizedBox(height: 16),
            Text(
              '正在加载图片...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.white,
            ),
            const SizedBox(height: 16),
            Text(
              _error!,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadImage,
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }

    return _buildImageWidget();
  }
} 