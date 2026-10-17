# Release shrinking (R8 full mode) rules for plugins that use reflection.

# flutter_local_notifications persists scheduled notifications with Gson. Gson needs the
# generic signatures of its TypeToken subclasses, which R8 full mode strips otherwise
# ("java.lang.RuntimeException: Missing type parameter" at launch).
-keepattributes Signature, *Annotation*, InnerClasses, EnclosingMethod
-keep class com.dexterous.flutterlocalnotifications.** { *; }
-keep class com.google.gson.reflect.TypeToken { *; }
-keep class * extends com.google.gson.reflect.TypeToken
-keep,allowobfuscation,allowshrinking class com.google.gson.reflect.TypeToken
-keep,allowobfuscation,allowshrinking class * extends com.google.gson.reflect.TypeToken

# Flutter references Play Core only for deferred components, which this app doesn't use.
-dontwarn com.google.android.play.core.**

# WorkManager (pulled in by the ads / notification plugins) instantiates its Room database
# by reflection; R8 renames the generated WorkDatabase_Impl otherwise and the app crashes at
# launch with "Failed to create an instance of androidx.work.impl.WorkDatabase".
-keep class androidx.work.** { *; }
-keep class * extends androidx.room.RoomDatabase { <init>(); }
-keep class androidx.room.** { *; }
-dontwarn androidx.room.paging.**
