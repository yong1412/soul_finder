import 'package:flutter/material.dart';

/// 可复用的跑马灯/自动滚动文本组件 (Marquee Text)
/// 当文本长度超出父容器时，会自动向右平滑滚动展示完整文字，并支持手势微拉滑动。
class MarqueeText extends StatefulWidget {
  const MarqueeText({
    super.key,
    required this.text,
    required this.style,
    this.velocity = 28.0, // 滚动速度 (像素/秒)
  });

  final String text;
  final TextStyle style;
  final double velocity;

  @override
  State<MarqueeText> createState() => _MarqueeTextState();
}

class _MarqueeTextState extends State<MarqueeText> {
  final ScrollController _scrollController = ScrollController();
  bool _isLoopRunning = false;

  @override
  void initState() {
    super.initState();
    _triggerScroll();
  }

  @override
  void didUpdateWidget(MarqueeText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _triggerScroll();
    }
  }

  void _triggerScroll() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startScrollingLoop();
    });
  }

  void _startScrollingLoop() async {
    if (!mounted || _isLoopRunning) return;
    _isLoopRunning = true;

    // 给予父容器 (如 AnimatedContainer) 充足的时间完成动画展开与布局测量
    await Future.delayed(const Duration(milliseconds: 600));

    while (mounted) {
      if (!_scrollController.hasClients) break;

      var maxScroll = _scrollController.position.maxScrollExtent;
      
      // 如果初次测量为 0，再稍微等待以防止动态容器尚未排版完成
      if (maxScroll <= 0) {
        await Future.delayed(const Duration(milliseconds: 800));
        if (!mounted || !_scrollController.hasClients) break;
        maxScroll = _scrollController.position.maxScrollExtent;
        if (maxScroll <= 0) {
          break; // 文字完全适配在容器内，无需滚动
        }
      }

      final durationMs = (maxScroll / widget.velocity * 1000).toInt().clamp(1000, 20000);

      // 向末尾平滑滚动
      if (_scrollController.hasClients) {
        await _scrollController.animateTo(
          maxScroll,
          duration: Duration(milliseconds: durationMs),
          curve: Curves.linear,
        );
      }

      if (!mounted) break;
      await Future.delayed(const Duration(milliseconds: 1200));

      if (!mounted || !_scrollController.hasClients) break;
      // 快速平滑复位到起点
      await _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOut,
      );

      if (!mounted) break;
      await Future.delayed(const Duration(milliseconds: 1500));
    }

    _isLoopRunning = false;
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: _scrollController,
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(), // 支持平滑跑马灯 + 手势微滑
      child: Padding(
        padding: const EdgeInsets.only(right: 12.0),
        child: Text(
          widget.text,
          style: widget.style,
          maxLines: 1,
        ),
      ),
    );
  }
}
