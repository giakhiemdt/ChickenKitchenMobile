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
  // Use the dark red primary used across Home
  static const Color kPrimary = Color(0xFFB71C1C);
  // Translucent tints for default and pressed backgrounds
  // Default: solid white background per user's request
  static const Color kPrimaryTint = Color(0xFFFFFFFF);
  // Pressed: light translucent gray to show press feedback
  static const Color kPrimaryTintPressed = Color(0x14E0E0E0); // ~8% opacity gray
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
            // muted/translucent primary tint by default; slightly stronger when pressed
            color: _pressed ? kPrimaryTintPressed : kPrimaryTint,
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: kPrimary, width: 1.5),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: const [
              // Centered label
              Text(
                'Build your dish',
                textAlign: TextAlign.center,
                style: TextStyle(color: kPrimary, fontWeight: FontWeight.w700),
              ),
              // Left icon without affecting label centering
              Positioned(
                left: 16,
                child: Icon(Icons.add, color: kPrimary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
