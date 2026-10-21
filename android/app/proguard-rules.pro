# Flutter's default ProGuard rules are applied automatically. These extra rules
# keep the plugins used by Logic Lab working in release builds.

# sqflite
-keep class io.flutter.plugins.** { *; }

# share_plus / file_picker keep their platform implementations
-keep class dev.fluttercommunity.plus.share.** { *; }
-keep class com.mrflutter.antfilepicker.** { *; }
