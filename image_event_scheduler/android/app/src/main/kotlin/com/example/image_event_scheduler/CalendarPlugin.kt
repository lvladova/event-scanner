package com.example.image_event_scheduler

import android.content.Context
import android.content.Intent
import android.provider.CalendarContract
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.*

class CalendarPlugin(private val context: Context) : MethodChannel.MethodCallHandler {
    companion object {
        private const val CHANNEL = "com.example.image_event_scheduler/calendar"

        fun registerWith(flutterEngine: FlutterEngine, context: Context) {
            val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            channel.setMethodCallHandler(CalendarPlugin(context))
        }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "openCalendarAtDate" -> {
                val timestamp = call.argument<Long>("timestamp") ?: System.currentTimeMillis()
                val success = openCalendarAtDate(timestamp)
                result.success(success)
            }
            "openDefaultCalendar" -> {
                val success = openDefaultCalendar()
                result.success(success)
            }
            else -> {
                result.notImplemented()
            }
        }
    }

    private fun openCalendarAtDate(timestamp: Long): Boolean {
        return try {
            val builder = CalendarContract.CONTENT_URI.buildUpon()
            builder.appendPath("time")
            builder.appendPath(timestamp.toString())

            val intent = Intent(Intent.ACTION_VIEW)
                .setData(builder.build())
                .setFlags(Intent.FLAG_ACTIVITY_NEW_TASK)

            context.startActivity(intent)
            true
        } catch (e: Exception) {
            e.printStackTrace()
            // Try fallback to general calendar
            openDefaultCalendar()
        }
    }

    private fun openDefaultCalendar(): Boolean {
        return try {
            val intent = Intent(Intent.ACTION_MAIN)
                .addCategory(Intent.CATEGORY_APP_CALENDAR)
                .setFlags(Intent.FLAG_ACTIVITY_NEW_TASK)

            context.startActivity(intent)
            true
        } catch (e: Exception) {
            e.printStackTrace()
            false
        }
    }
}