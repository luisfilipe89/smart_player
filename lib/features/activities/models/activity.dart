import 'package:flutter/widgets.dart';

class Activity {
  final String key; // i18n + route key, e.g. 'soccer'
  final String image; // asset path
  final int kcalPerHour; // numeric
  final Alignment? align;

  const Activity({
    required this.key,
    required this.image,
    required this.kcalPerHour,
    this.align,
  });
}
