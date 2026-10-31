# ML Kit text recognition references optional language packs (Chinese,
# Devanagari, Japanese, Korean) that this app doesn't bundle.
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**

# ML Kit finds its internal classes by reflection at runtime, so R8 must not
# rename or strip them (otherwise text recognition crashes in release builds).
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.internal.mlkit_** { *; }
-keep class com.google_mlkit_** { *; }
