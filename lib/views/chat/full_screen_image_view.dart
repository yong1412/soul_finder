import 'dart:convert';
import 'package:flutter/material.dart';

class FullScreenImageView extends StatelessWidget {
  const FullScreenImageView({
    super.key,
    required this.imageUrl,
    this.heroTag,
  });

  final String imageUrl;
  final String? heroTag;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white, size: 30),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SizedBox.expand(
        child: InteractiveViewer(
          minScale: 1.0,
          maxScale: 4.0,
          clipBehavior: Clip.none,
          child: heroTag != null
              ? Hero(
                  tag: heroTag!,
                  child: _buildImage(context),
                )
              : _buildImage(context),
        ),
      ),
    );
  }

  Widget _buildImage(BuildContext context) {
    final size = MediaQuery.of(context).size;
    
    if (imageUrl.startsWith('data:image') || !imageUrl.startsWith('http')) {
      try {
        final base64String = imageUrl.contains(',') 
            ? imageUrl.split(',').last 
            : imageUrl;
        return Image.memory(
          base64Decode(base64String),
          width: size.width,
          height: size.height,
          fit: BoxFit.contain,
        );
      } catch (e) {
        return const Icon(Icons.broken_image, color: Colors.white24, size: 100);
      }
    }

    return Image.network(
      imageUrl,
      width: size.width,
      height: size.height,
      fit: BoxFit.contain,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Center(
          child: CircularProgressIndicator(
            value: loadingProgress.expectedTotalBytes != null
                ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                : null,
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) =>
          const Icon(Icons.broken_image, color: Colors.white24, size: 100),
    );
  }
}
