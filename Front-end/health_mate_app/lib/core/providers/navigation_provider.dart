import 'package:flutter_riverpod/flutter_riverpod.dart';

class NavigationController extends StateNotifier<int> {
  NavigationController() : super(0);

  void setIndex(int index) {
    state = index;
  }

  void goHome() {
    state = 0;
  }
}

final navigationProvider = StateNotifierProvider<NavigationController, int>((ref) {
  return NavigationController();
});
