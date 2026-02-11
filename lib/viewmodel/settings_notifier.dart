import 'package:flutter_riverpod/flutter_riverpod.dart';

// 💡 전역적으로 속도 설정을 관리하는 Notifier
final settingsProvider = NotifierProvider<SettingsNotifier, double>(
      () => SettingsNotifier(),
);

class SettingsNotifier extends Notifier<double> {
  @override
  double build() {
    return 9.0;
  }

  // 💡 기준 속도 변경 기능
  void updateTargetSpeed(double newSpeed) {
    state = newSpeed;
  }
}