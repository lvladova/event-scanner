package com.example.image_event_scheduler

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity: FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Register the calendar plugin with the Flutter engine
        CalendarPlugin.registerWith(flutterEngine, context)
    }
}