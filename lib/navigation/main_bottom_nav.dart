import 'package:flutter/material.dart';
import '../features/home/presentation/home_discovery_screen.dart';
import '../features/explore/presentation/explore_screen.dart';
import '../features/matching/presentation/likes_screen.dart';
import '../features/global_chat/presentation/global_chat_screen.dart';
import '../features/profile/presentation/profile_screen.dart';
import '../core/theme/app_colors.dart';

class MainBottomNav extends StatefulWidget {
  const MainBottomNav({super.key});

  @override
  State<MainBottomNav> createState() => _MainBottomNavState();
}

class _MainBottomNavState extends State<MainBottomNav> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    HomeDiscoveryScreen(),
    ExploreScreen(),
    LikesScreen(),
    GlobalChatScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() => _currentIndex = index);
        },
        indicatorColor: AppColors.primary.withOpacity(0.15),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.local_fire_department_outlined),
            selectedIcon: Icon(Icons.local_fire_department, color: AppColors.primary),
            label: 'Discover',
          ),
          NavigationDestination(
            icon: Icon(Icons.explore_outlined),
            selectedIcon: Icon(Icons.explore, color: AppColors.primary),
            label: 'Explore',
          ),
          NavigationDestination(
            icon: Icon(Icons.favorite_border),
            selectedIcon: Icon(Icons.favorite, color: AppColors.secondary),
            label: 'Likes',
          ),
          NavigationDestination(
            icon: Icon(Icons.forum_outlined),
            selectedIcon: Icon(Icons.forum, color: AppColors.primary),
            label: 'Global Chat',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person, color: AppColors.primary),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
