# Flutter wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# SharedPreferences plugin
-keep class io.flutter.plugins.sharedpreferences.** { *; }
-dontwarn io.flutter.plugins.sharedpreferences.**

# SQFlite plugin
-keep class io.flutter.plugins.sqflite.** { *; }
-dontwarn io.flutter.plugins.sqflite.**

# Firebase
-dontwarn com.google.firebase.**
-keep class com.google.firebase.** { *; }

