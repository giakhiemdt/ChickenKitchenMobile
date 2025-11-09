import 'dart:async';

import 'package:flutter/material.dart';

/// In-app notification overlay that slides down from the top, stays briefly,
/// then closes with a slower animation.
class InAppNotification {
  static OverlayEntry? _entry;
  static bool _showing = false;

  /// Show an in-app notification.
  ///
  /// - [context]: use a root context (e.g., from a navigatorKey).
  /// - [title], [body]: content to display.
  /// - [visibleDuration]: how long to stay before auto-close.
  static void show(
    BuildContext context, {
    String? title,
    String? body,
    Duration visibleDuration = const Duration(seconds: 1),
  }) {
    // If another one is showing, remove it first.
    if (_showing) {
      _entry?.remove();
      _entry = null;
      _showing = false;
    }

  final overlay = Overlay.of(context, rootOverlay: true);

    _entry = OverlayEntry(
      builder: (_) => _InAppNotificationBanner(
        title: title,
        body: body,
        visibleDuration: visibleDuration,
        onClosed: () {
          _entry?.remove();
          _entry = null;
          _showing = false;
        },
      ),
    );

    overlay.insert(_entry!);
    _showing = true;
  }
}

class _InAppNotificationBanner extends StatefulWidget {
  final String? title;
  final String? body;
  final Duration visibleDuration;
  final VoidCallback onClosed;

  const _InAppNotificationBanner({
    required this.title,
    required this.body,
    required this.visibleDuration,
    required this.onClosed,
  });

  @override
  State<_InAppNotificationBanner> createState() => _InAppNotificationBannerState();
}

class _InAppNotificationBannerState extends State<_InAppNotificationBanner>
    with TickerProviderStateMixin {
  late final AnimationController _inController;
  late final AnimationController _outController;
  late final Animation<Offset> _inSlide;
  late final Animation<Offset> _outSlide;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // Fast slide-in
    _inController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _inSlide = Tween<Offset>(begin: const Offset(0, -1.0), end: Offset.zero)
        .animate(CurvedAnimation(parent: _inController, curve: Curves.easeOutCubic));

    // Slow slide-out ("slow motion")
    _outController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _outSlide = Tween<Offset>(begin: Offset.zero, end: const Offset(0, -1.0))
        .animate(CurvedAnimation(parent: _outController, curve: Curves.easeInOutCubic));

    // Start entrance
    _inController.forward();

    // Schedule auto close
    _timer = Timer(widget.visibleDuration, _close);
  }

  void _close() async {
    if (!mounted) return;
    try {
      await _outController.forward();
    } catch (_) {}
    if (mounted) widget.onClosed();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _inController.dispose();
    _outController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final width = media.size.width;

    // Place banner at the very top using Positioned.fill with alignment.
    return IgnorePointer(
      ignoring: true, // allow interactions to pass through except on close button
      child: Stack(
        children: [
          // Slide in
          SlideTransition(
            position: _outController.isAnimating ? _outSlide : _inSlide,
            child: SafeArea(
              bottom: false,
              child: Align(
                alignment: Alignment.topCenter,
                child: _NotificationCard(
                  width: width,
                  title: widget.title,
                  body: widget.body,
                  onCloseTap: () {
                    // Allow manual dismiss
                    _timer?.cancel();
                    _close();
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  final double width;
  final String? title;
  final String? body;
  final VoidCallback onCloseTap;

  const _NotificationCard({
    required this.width,
    required this.title,
    required this.body,
    required this.onCloseTap,
  });

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF86C144);
    return Container(
      width: width,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(color: Colors.black12),
      ),
      child: Material(
        color: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.notifications_active, color: primary),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title?.isNotEmpty == true ? title! : 'Thông báo',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      body?.isNotEmpty == true ? body! : 'Bạn có thông báo mới.',
                      style: const TextStyle(fontSize: 13, color: Colors.black87),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onCloseTap,
                child: const Padding(
                  padding: EdgeInsets.all(6.0),
                  child: Icon(Icons.close, size: 18, color: Colors.black54),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
