import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../main.dart';
import '../viewmodel/auth_notifier.dart';
import '../viewmodel/navigation_notifier.dart';
import 'course/around/around_course_screen.dart';
import 'course/mine/my_course_detail_screen.dart';
import 'course/mine/my_course_list_screen.dart';
import 'map/map_screen.dart';

class MainScreen extends ConsumerWidget {
  const MainScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {

    final selectedIndex = ref.watch(navigationProvider);
    final authState = ref.watch(authProvider);
    final user = authState.value;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '함께,이길',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,

        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: GestureDetector(
              onTap: () => _showProfileOptions(context, ref),
              child: CircleAvatar(
                radius: 18,
                backgroundColor: Colors.blueAccent.withOpacity(0.1),
                backgroundImage: (user?.photoURL != null)
                    ? NetworkImage(user!.photoURL!)
                    : null,
                child: (user?.photoURL == null)
                    ? const Icon(
                        Icons.person,
                        size: 20,
                        color: Colors.blueAccent,
                      )
                    : null,
              ),
            ),
          ),
        ],
      ),

      body: IndexedStack(
        index: selectedIndex,
        children: const [MapScreen(), AroundCourseScreen(), MyCourseListScreen(),],
      ),

      bottomNavigationBar: BottomNavigationBar(
        currentIndex: selectedIndex,
        onTap: (index) => ref.read(navigationProvider.notifier).setTab(index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.map_outlined),
            activeIcon: Icon(Icons.map),
            label: '지도',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.explore_outlined),
            label: '주변 코스',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history_outlined),
            activeIcon: Icon(Icons.history),
            label: '내 코스',
          ),
        ],
        selectedItemColor: Colors.blueAccent,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }

  void _showProfileOptions(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        // ✅ 여기서도 .value로 꺼내줍니다.
        final user = ref.watch(authProvider).value;

        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.person_outline),
                title: Text(user?.displayName ?? '사용자님'),
                subtitle: const Text('반가워요! 오늘도 함께 걸어요.'),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.redAccent),
                title: const Text(
                  '로그아웃',
                  style: TextStyle(color: Colors.redAccent),
                ),
                onTap: () {
                  Navigator.pop(context);
                  ref.read(authProvider.notifier).logout();
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
