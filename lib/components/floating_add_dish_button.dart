import 'package:flutter/material.dart';

class FloatingAddDishButton extends StatelessWidget {
  final VoidCallback? onPressed;
  const FloatingAddDishButton({super.key, this.onPressed});

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF86C144);
    return FloatingActionButton(
      heroTag: 'add_dish_fab',
      backgroundColor: Colors.white,
      foregroundColor: primary,
      onPressed: onPressed,
      child: const Icon(Icons.add),
    );
  }
}

