# Flutter wrapper & plugins
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class com.cirrusgroup.ems.** { *; }

# Keep CameraX / Geolocator / Printing plugin entrypoints
-keep class androidx.camera.** { *; }
-keep class com.baseflow.geolocator.** { *; }
-keep class net.nfet.flutter.printing.** { *; }
-dontwarn io.flutter.embedding.**
