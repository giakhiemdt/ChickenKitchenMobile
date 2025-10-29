import 'package:flutter/material.dart';

class FloatingBuildDishPill extends StatefulWidget {
  final VoidCallback? onPressed;
  final double? width;
  final double? height;
  const FloatingBuildDishPill({super.key, this.onPressed, this.width, this.height});

  @override
  State<FloatingBuildDishPill> createState() => _FloatingBuildDishPillState();
}

class _FloatingBuildDishPillState extends State<FloatingBuildDishPill> {
  static const Color kGreen = Color(0xFF7AC94A);
  static const Color kGreenPressed = Color(0xFF6AB43E);
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final h = widget.height ?? 52.0;
    final radius = 30.0; // large rounded corners as requested
    return Material(
      color: Colors.transparent,
      elevation: 3,
      borderRadius: BorderRadius.circular(radius),
      child: InkWell(
        onTap: widget.onPressed,
        onHighlightChanged: (v) => setState(() => _pressed = v),
        borderRadius: BorderRadius.circular(radius),
        child: Container(
          width: widget.width,
          height: h,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: _pressed ? const Color(0x146AB43E) : Colors.white, // slight green tint when pressed
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: kGreen, width: 1.5),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: const [
              // Centered label
              Text(
                'Build your dish',
                textAlign: TextAlign.center,
                style: TextStyle(color: kGreen, fontWeight: FontWeight.w700),
              ),
              // Left icon without affecting label centering
              Positioned(
                left: 16,
                child: Icon(Icons.add, color: kGreen),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
