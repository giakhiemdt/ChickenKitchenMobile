import 'package:flutter/material.dart';
import 'package:mobiletest/services/store_service.dart';
import 'package:mobiletest/screen/StorePickerPage.dart';

class HomeHeader extends StatelessWidget {
  final String displayName;
  final Color primary;

  const HomeHeader({super.key, required this.displayName, required this.primary});

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          height: 200,
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(20),
              bottomRight: Radius.circular(20),
            ),
            image: const DecorationImage(
              image: NetworkImage(
                'https://i.pinimg.com/1200x/93/05/49/9305497643b9b18fec3c7fbe5c266ff1.jpg',
              ),
              fit: BoxFit.cover,
              colorFilter: ColorFilter.mode(
                Colors.black54,
                BlendMode.darken,
              ),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _HeaderIconButton(
                      icon: Icons.store_mall_directory,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const StorePickerPage()),
                        );
                      },
                    ),
                    const _SelectedStoreInfo(topLayout: true),
                    const _RoundTranslucentIcon(icon: Icons.notifications_none),
                  ],
                ),
                const Spacer(),
                // Bottom row: promo spanning left
                const _PromoCopy(),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
        // Floating search bar
        Positioned(
          left: 16,
          right: 16,
          bottom: -26,
          child: Material(
            elevation: 3,
            borderRadius: BorderRadius.circular(28),
            child: Container(
              height: 46,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
              ),
              child: Row(
                children: [
                  const Icon(Icons.search, color: Colors.grey),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Search by name & category',
                      style: TextStyle(color: Colors.black54),
                    ),
                  ),
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      // use a dark red color for the tune button
                      color: const Color(0xFFB71C1C),
                      borderRadius: BorderRadius.circular(19),
                    ),
                    child: const Icon(Icons.tune, color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _RoundTranslucentIcon extends StatelessWidget {
  final IconData icon;
  const _RoundTranslucentIcon({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: Colors.white),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _HeaderIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.white),
        ),
      ),
    );
  }
}

class _WelcomeText extends StatelessWidget {
  final String displayName;
  const _WelcomeText({required this.displayName});

  @override
  Widget build(BuildContext context) {
    final name = displayName.isEmpty ? 'there' : displayName;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Welcome back',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          name,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _PromoCopy extends StatelessWidget {
  const _PromoCopy();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: const TextSpan(
            children: [
              TextSpan(
                text: '15%',
                style: TextStyle(
                  color: Color(0xFFFF7648),
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                ),
              ),
              TextSpan(
                text: '  EXTRA',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        const Text(
          'DISCOUNT',
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
        const Text(
          'Get your first order delivery free!',
          style: TextStyle(color: Colors.white70),
        ),
      ],
    );
  }
}

class _SelectedStoreInfo extends StatelessWidget {
  final bool topLayout;
  const _SelectedStoreInfo({this.topLayout = false});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<StoreInfo?>(
      future: StoreService.loadSelectedStore(),
      builder: (context, snap) {
        final store = snap.data;
        if (store == null) return const SizedBox(width: 180);
        return SizedBox(
          width: 200,
          child: Column(
            crossAxisAlignment: topLayout ? CrossAxisAlignment.center : CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                store.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                store.address,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: topLayout ? TextAlign.center : TextAlign.right,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
