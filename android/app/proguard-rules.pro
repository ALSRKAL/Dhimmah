# Release-build shrinking rules for Dhimmah.
#
# The Flutter engine and the plugin registrant are reached reflectively on some
# platforms, so they are kept explicitly. Everything else is safe to shrink.

-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# flutter_local_notifications schedules through AlarmManager and is started by
# the system, not by our code, so its receivers must survive shrinking.
-keep class com.dexterous.flutterlocalnotifications.** { *; }

# local_auth talks to the biometric prompt through the platform channel.
-keep class io.flutter.plugins.localauth.** { *; }

# flutter_secure_storage reaches the Android keystore reflectively.
-keep class com.it_nomads.fluttersecurestorage.** { *; }

# The Flutter engine's deferred-components class references Play Core, which is
# only on the classpath when an app actually ships deferred components. Dhimmah
# does not, so the reference is unresolvable and R8 stops without these.
-dontwarn com.google.android.play.core.**
-keep class io.flutter.embedding.engine.deferredcomponents.** { *; }

# Google Play's in-app update library.
#
# The AAR ships no consumer rules of its own and this build runs R8 with
# shrinking, so without these the update classes are renamed or removed and the
# first update check fails — in a release build only, which is the build that
# reaches users and the one nobody runs while developing. The library reaches
# its own internals reflectively and talks to the Play Store app across a binder,
# so the package is kept rather than guessed at.
-keep class com.google.android.play.core.appupdate.** { *; }
-keep class com.google.android.play.core.install.** { *; }
-keep class com.google.android.play.core.common.** { *; }
-dontwarn com.google.android.play.core.appupdate.**
-dontwarn com.google.android.play.core.install.**
-dontwarn com.google.android.play.core.common.**

# The Play library reports its results through GMS Tasks, which are resolved the
# same way.
-keep class com.google.android.gms.tasks.** { *; }
-dontwarn com.google.android.gms.tasks.**

# Optional crypto providers referenced by the TLS stack.
-dontwarn org.bouncycastle.**
-dontwarn org.conscrypt.**
-dontwarn org.openjsse.**
