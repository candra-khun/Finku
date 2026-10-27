# Flutter Wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Suppress Play Core warnings (deferred components not used)
-dontwarn com.google.android.play.core.**

# AndroidX Biometric (Local Auth)
-keep class androidx.biometric.** { *; }

# Sqflite
-keep class com.tekartik.sqflite.** { *; }
