import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mobiletest/shared/widgets/app_bottom_nav.dart';
import 'package:mobiletest/features/home/presentation/widgets/home_header.dart';
// import 'package:mobiletest/features/menu/presentation/widgets/categories_strip.dart';
import 'package:mobiletest/features/home/presentation/widgets/restaurants_carousel.dart';
import 'package:mobiletest/features/home/presentation/widgets/todays_specials.dart';
import 'package:mobiletest/features/home/presentation/widgets/promotions_strip.dart';
import 'package:mobiletest/features/profile/presentation/ProfilePage.dart';
import 'package:mobiletest/features/restaurants/presentation/RestaurantsListPage.dart';
import 'package:mobiletest/features/ai/presentation/AiChatPage.dart';
// import 'package:mobiletest/features/menu/presentation/DailyMenuListPage.dart';
import 'package:mobiletest/features/search/presentation/SearchPage.dart';
import 'package:mobiletest/shared/widgets/dual_fabs.dart';
import 'package:mobiletest/features/menu/presentation/BuildDishWizardPage.dart';
import 'package:mobiletest/features/orders/presentation/CurrentOrderPage.dart';
import 'package:mobiletest/features/orders/presentation/OrderHistoryPage.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
  const primary = Color(0xFFB71C1C);
    final displayName = FirebaseAuth.instance.currentUser?.displayName ?? 'there';

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          SafeArea(
            bottom: false,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final orientation = MediaQuery.of(context).orientation;
                final isWide = constraints.maxWidth >= 900 ||
                    (orientation == Orientation.landscape && constraints.maxWidth >= 700);

                Widget specialsSection = Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: const [
                          Text(
                            "Today's Specials",
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                          ),
                          SizedBox.shrink(),
                        ],
                      ),
                    ),
                    const TodaysSpecials(),
                  ],
                );

                Widget restaurantsSection = Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Popular Restaurants',
                              style:
                                  TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                          IconButton(
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                    builder: (_) => const RestaurantsListPage()),
                              );
                            },
                            icon: const Icon(Icons.arrow_forward_ios, size: 16),
                          ),
                        ],
                      ),
                    ),
                    RestaurantsCarousel(primary: primary),
                  ],
                );

                Widget promotionsSection = Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Active Promotions',
                              style:
                                  TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                          IconButton(
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content:
                                        Text('View more promotions – coming soon')),
                              );
                            },
                            icon: const Icon(Icons.arrow_forward_ios, size: 16),
                          ),
                        ],
                      ),
                    ),
                    const PromotionsStrip(),
                  ],
                );

                if (!isWide) {
                  // Phone / narrow: single-column scroll
                  return SingleChildScrollView(
                    child: Column(
                      children: [
                        HomeHeader(displayName: displayName, primary: primary),
                        const SizedBox(height: 36),
                        specialsSection,
                        const SizedBox(height: 8),
                        restaurantsSection,
                        promotionsSection,
                        SizedBox(height: MediaQuery.of(context).padding.bottom + 96),
                      ],
                    ),
                  );
                } else {
                  // Tablet landscape / wide: two-column layout
                  return SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        HomeHeader(displayName: displayName, primary: primary),
                        const SizedBox(height: 24),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Left column: specials + promotions
                              Expanded(
                                flex: 5,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    specialsSection,
                                    const SizedBox(height: 16),
                                    promotionsSection,
                                  ],
                                ),
                              ),
                              const SizedBox(width: 16),
                              // Right column: restaurants
                              Expanded(
                                flex: 5,
                                child: restaurantsSection,
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: MediaQuery.of(context).padding.bottom + 96),
                      ],
                    ),
                  );
                }
              },
            ),
          ),
          DualFABs(
            onAddDish: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const BuildDishWizardPage()),
              );
            },
            onCart: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const CurrentOrderPage()),
              );
            },
          ),
        ],
      ),
      bottomNavigationBar: AppBottomNav(
        currentIndex: 0,
        onTap: (i) {
          switch (i) {
            case 0:
              break;
            case 1:
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SearchPage()),
              );
              break;
            case 2:
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AiChatPage()),
              );
              break;
            case 3:
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const OrderHistoryPage()),
              );
              break;
            case 4:
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ProfilePage()),
              );
              break;
            default:
              ScaffoldMessenger.of(context)
                  .showSnackBar(const SnackBar(content: Text('Tab này sẽ sớm có.')));
          }
        },
      ),
    );
  }
}
