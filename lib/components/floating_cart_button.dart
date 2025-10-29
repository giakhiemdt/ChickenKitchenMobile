import 'package:flutter/material.dart';

class FloatingCartButton extends StatelessWidget {
  final VoidCallback? onPressed;
  const FloatingCartButton({super.key, this.onPressed});

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF86C144);
    return FloatingActionButton(
      backgroundColor: primary,
      foregroundColor: Colors.white,
      onPressed: onPressed ?? () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cart will be available soon.')),
        );
      },
      child: const Icon(Icons.shopping_cart),
    );
  }
}

