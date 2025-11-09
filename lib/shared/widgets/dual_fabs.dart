import 'package:flutter/material.dart';
import 'package:mobiletest/shared/widgets/floating_cart_button.dart';
import 'package:mobiletest/shared/widgets/floating_build_dish_pill.dart';
// no custom constants needed for placement

class DualFABs extends StatelessWidget {
  final VoidCallback? onAddDish;
  final VoidCallback? onCart;
  const DualFABs({super.key, this.onAddDish, this.onCart});

  @override
  Widget build(BuildContext context) {
    const leftPad = 16.0;
    const rightPad = 16.0;
    const interGap = 8.0; // gap between pill and cart
    const fabSize = 56.0; // default FAB diameter
    const pillHeight = 52.0;
    final double baseBottom =
        kBottomNavigationBarHeight - 50; // ~5px above system bottom bar
    final screenWidth = MediaQuery.of(context).size.width;

    return SizedBox.expand(
      child: Stack(
        children: [
          // Pill spans left to just before the cart with an 8px gap
          Positioned(
            left: leftPad,
            right: rightPad + fabSize + interGap,
            bottom: baseBottom,
            child: FloatingBuildDishPill(
              onPressed: onAddDish,
              height: pillHeight,
            ),
          ),
          // Cart button sits to the right, same baseline
          Positioned(
            right: rightPad,
            bottom: baseBottom,
            child: FloatingCartButton(onPressed: onCart),
          ),
        ],
      ),
    );
  }
}
