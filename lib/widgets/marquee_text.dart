import 'package:flutter/material.dart';

class MarqueeText extends StatefulWidget {
  const MarqueeText({
    super.key,
    required this.text,
    required this.style,
    this.velocity = 28.0,
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

    await Future.delayed(const Duration(milliseconds: 600));

    while (mounted) {
      if (!_scrollController.hasClients) break;

      var maxScroll = _scrollController.position.maxScrollExtent;
      
      if (maxScroll <= 0) {
        await Future.delayed(const Duration(milliseconds: 800));
        if (!mounted || !_scrollController.hasClients) break;
        maxScroll = _scrollController.position.maxScrollExtent;
        if (maxScroll <= 0) {
          break;
        }
      }

      final durationMs = (maxScroll / widget.velocity * 1000).toInt().clamp(1000, 20000);

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
      physics: const BouncingScrollPhysics(),
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
