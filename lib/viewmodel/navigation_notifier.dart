import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

final pendingNotificationCourseIdProvider = StateProvider<String?>((ref) => null);
final navigationProvider = NotifierProvider<NavigationNotifier, int>(() => NavigationNotifier());

class NavigationNotifier extends Notifier<int> {
  @override
  int build() => 0; // 초기값은 0 (지도)

  void setTab(int index) {
    state = index;
  }
}

