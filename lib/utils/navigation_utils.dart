import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:animations/animations.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:move_young/utils/logger.dart';

class NavigationUtils {
  static Future<void> shareLocation(String name, String lat, String lon) async {
    final message =
        "${'meet_me'.tr()} $name! 📍 https://maps.google.com/?q=$lat,$lon";

    try {
      await Share.share(message);
      NumberedLogger.i('user_shared_location'.tr());
    } catch (e) {
      NumberedLogger.d('user_dismissed_sharing'.tr());
    }
  }

  static Future<void> openDirections(
      BuildContext context, String lat, String lon) async {
    final url =
        'https://www.google.com/maps/dir/?api=1&destination=$lat,$lon&travelmode=walking';
    final uri = Uri.parse(url);

    final canLaunch = await canLaunchUrl(uri);
    if (canLaunch) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      // Safe usage of context after async using a post-frame callback
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('could_not_open_maps'.tr())),
          );
        }
      });
    }
  }

  // Shared-axis route helper for create/edit flows
  static PageRoute<T> sharedAxisRoute<T>({
    required WidgetBuilder builder,
    SharedAxisTransitionType type = SharedAxisTransitionType.vertical,
    Duration duration = const Duration(milliseconds: 280),
    RouteSettings? settings,
  }) {
    return PageRouteBuilder<T>(
      settings: settings,
      transitionDuration: duration,
      reverseTransitionDuration: duration,
      pageBuilder: (context, animation, secondaryAnimation) => builder(context),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return SharedAxisTransition(
          animation: animation,
          secondaryAnimation: secondaryAnimation,
          transitionType: type,
          child: child,
        );
      },
    );
  }
}
