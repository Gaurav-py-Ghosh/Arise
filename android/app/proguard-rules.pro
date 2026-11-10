# WorkManager creates its Room database by reflection; R8 would otherwise
# strip the generated constructor and crash the app at startup.
-keep class * extends androidx.room.RoomDatabase { <init>(); }
-keep class androidx.work.impl.WorkDatabase_Impl { *; }
-keep class dev.gaurav.arise.WatchWorker { *; }
