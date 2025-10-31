import 'package:flutter/material.dart';

class Category {
  final int id;
  final String name;
  final String description;

  const Category({
    required this.id,
    required this.name,
    required this.description,
  });
}

class CategoriesStrip extends StatelessWidget {
  final ValueChanged<Category>? onTap;
  final String? selectedName;
  final Set<String>? selectedNames; // allow multi-select
  const CategoriesStrip({
    super.key,
    this.onTap,
    this.selectedName,
    this.selectedNames,
  });

  static const fixed = <Category>[
    Category(id: 1, name: 'Carbohydrates', description: 'Base carb selection'),
    Category(id: 2, name: 'Proteins', description: 'Protein selection'),
    Category(id: 3, name: 'Vegetables', description: 'Vegetable selection'),
    Category(id: 4, name: 'Sauces', description: 'Sauce selection'),
    Category(id: 5, name: 'Dairy', description: 'Dairy selection'),
    Category(id: 6, name: 'Fruits', description: 'Fruit selection'),
  ];

  @override
  Widget build(BuildContext context) {
  const primary = Color(0xFFB71C1C);
    final width = MediaQuery.of(context).size.width;
    final itemsPerView = width >= 900
        ? 6
        : width >= 600
        ? 5
        : 4;
    const sep = 8.0;
    final itemWidth = (width - 32 - (itemsPerView - 1) * sep) / itemsPerView;

    String imageFor(String name) {
      switch (name) {
        case 'Carbohydrates':
          return 'https://images.unsplash.com/photo-1565958011703-44f9829ba187?w=400';
        case 'Proteins':
          return 'https://images.unsplash.com/photo-1553163147-622ab57be1c7?w=400';
        case 'Vegetables':
          return 'https://images.unsplash.com/photo-1540420773420-3366772f4999?w=400';
        case 'Sauces':
          return 'https://images.unsplash.com/photo-1505577058444-a3dab90d4253?w=400';
        case 'Dairy':
          return 'https://images.unsplash.com/photo-1541698444083-023c97d3f4b6?w=400';
        case 'Fruits':
          return 'https://images.unsplash.com/photo-1546554137-f86b9593a222?w=400';
        default:
          return 'https://images.unsplash.com/photo-1543353071-10c8ba85a904?w=400';
      }
    }

    return SizedBox(
      height: 92,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: fixed.length,
        separatorBuilder: (_, __) => const SizedBox(width: sep),
        itemBuilder: (context, i) {
          final c = fixed[i];
          final selected =
              (selectedNames?.contains(c.name) ?? false) ||
              selectedName == c.name;
          return SizedBox(
            width: itemWidth,
            child: Column(
              children: [
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: onTap == null ? null : () => onTap!(c),
                    child: SizedBox(
                      width: 72, // outer ring size
                      height: 72,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Outer ring draws OUTSIDE the image without shrinking it
                          Container(
                            width: selected ? 72 : 70,
                            height: selected ? 72 : 70,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: selected
                                    ? primary
                                    : primary.withOpacity(.5),
                                width: selected ? 3.0 : 1.0,
                              ),
                              color: Colors.transparent,
                            ),
                          ),
                          // Image circle keeps constant diameter
                          ClipOval(
                            child: SizedBox(
                              width: 64,
                              height: 64,
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  Image.network(
                                    imageFor(c.name),
                                    fit: BoxFit.cover,
                                  ),
                                  DecoratedBox(
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.06),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  c.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
