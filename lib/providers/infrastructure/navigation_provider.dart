import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Global navigator key provider
final navigatorKeyProvider = Provider<GlobalKey<NavigatorState>>((ref) {
  return GlobalKey<NavigatorState>();
});

// Navigation actions provider
final navigationActionsProvider = Provider<NavigationActions>((ref) {
  final navigatorKey = ref.watch(navigatorKeyProvider);
  return NavigationActions(navigatorKey);
});

class NavigationActions {
  final GlobalKey<NavigatorState> _navigatorKey;

  NavigationActions(this._navigatorKey);

  // Navigate to a named route
  Future<T?> pushNamed<T extends Object?>(String routeName,
      {Object? arguments}) {
    return _navigatorKey.currentState
            ?.pushNamed<T>(routeName, arguments: arguments) ??
        Future.value(null);
  }

  // Navigate to a named route and clear the stack
  Future<T?> pushNamedAndRemoveUntil<T extends Object?>(
    String routeName,
    RoutePredicate predicate, {
    Object? arguments,
  }) {
    return _navigatorKey.currentState?.pushNamedAndRemoveUntil<T>(
          routeName,
          predicate,
          arguments: arguments,
        ) ??
        Future.value(null);
  }

  // Navigate back
  void pop<T extends Object?>([T? result]) {
    _navigatorKey.currentState?.pop<T>(result);
  }

  // Check if can pop
  bool canPop() {
    return _navigatorKey.currentState?.canPop() ?? false;
  }

  // Pop until a condition is met
  void popUntil(RoutePredicate predicate) {
    _navigatorKey.currentState?.popUntil(predicate);
  }

  // Replace current route
  Future<T?> pushReplacementNamed<T extends Object?, TO extends Object?>(
    String routeName, {
    Object? arguments,
    TO? result,
  }) {
    return _navigatorKey.currentState?.pushReplacementNamed<T, TO>(
          routeName,
          arguments: arguments,
          result: result,
        ) ??
        Future.value(null);
  }
}
