import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mobiletest/components/app_bottom_nav.dart';
import 'package:mobiletest/components/home_header.dart';
import 'package:mobiletest/components/categories_strip.dart';
import 'package:mobiletest/components/restaurants_carousel.dart';
import 'package:mobiletest/components/todays_specials.dart';
import 'package:mobiletest/components/promotions_strip.dart';
import 'package:mobiletest/screen/ProfilePage.dart';
import 'package:mobiletest/screen/RestaurantsListPage.dart';
import 'package:mobiletest/screen/DailyMenuListPage.dart';
import 'package:mobiletest/components/dual_fabs.dart';
import 'package:mobiletest/screen/BuildDishWizardPage.dart';
import 'package:mobiletest/screen/CurrentOrderPage.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF86C144);
    final displayName = FirebaseAuth.instance.currentUser?.displayName ?? 'there';

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          SafeArea(
            bottom: false,
            child: SingleChildScrollView(
              child: Column(
                children: [
              HomeHeader(displayName: displayName, primary: primary),
              const SizedBox(height: 36),

              // Categories: tap to filter Today's Specials list
              CategoriesStrip(
                onTap: (c) {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => DailyMenuListPage(
                        initialSelectedCategoryName: c.name,
                      ),
                    ),
                  );
                },
              ),

              // Popular Restaurants
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Popular Restaurants',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                    IconButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const RestaurantsListPage()),
                        );
                      },
                      icon: const Icon(Icons.arrow_forward_ios, size: 16),
                    ),
                  ],
                ),
              ),
              RestaurantsCarousel(primary: primary),

              const SizedBox(height: 8),

              // Today's Specials
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Today's Specials",
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                    IconButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const DailyMenuListPage()),
                        );
                      },
                      icon: const Icon(Icons.arrow_forward_ios, size: 16),
                    ),
                  ],
                ),
              ),
              const TodaysSpecials(),

              // Active Promotions
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Active Promotions',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                    IconButton(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('View more promotions – coming soon')),
                        );
                      },
                      icon: const Icon(Icons.arrow_forward_ios, size: 16),
                    ),
                  ],
                ),
              ),
              const PromotionsStrip(),
                ],
              ),
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
            case 2:
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const RestaurantsListPage()),
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
