package com.imchic.stockhub

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationManagerCompat
import com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
	private fun clearScheduledNotificationCache() {
		val preferenceNames = listOf(
			"scheduled_notifications",
			"flutter_local_notifications_plugin"
		)

		preferenceNames.forEach { preferenceName ->
			applicationContext
				.getSharedPreferences(preferenceName, MODE_PRIVATE)
				.edit()
				.clear()
				.commit()

			if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
				applicationContext.deleteSharedPreferences(preferenceName)
			}
		}
	}

	private fun cancelScheduledNotification(id: Int) {
		val intent = Intent(applicationContext, ScheduledNotificationReceiver::class.java)
		var flags = PendingIntent.FLAG_UPDATE_CURRENT
		if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
			flags = flags or PendingIntent.FLAG_IMMUTABLE
		}

		val pendingIntent = PendingIntent.getBroadcast(applicationContext, id, intent, flags)
		val alarmManager = applicationContext.getSystemService(Context.ALARM_SERVICE) as AlarmManager
		alarmManager.cancel(pendingIntent)
		NotificationManagerCompat.from(applicationContext).cancel(id)
	}

	override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
		super.configureFlutterEngine(flutterEngine)

		MethodChannel(
			flutterEngine.dartExecutor.binaryMessenger,
			"com.imchic.stockhub/notification_cache"
		).setMethodCallHandler { call, result ->
			when (call.method) {
				"clearScheduledNotificationsCache" -> {
					clearScheduledNotificationCache()
					result.success(null)
				}

				"cancelScheduledNotificationIds" -> {
					val ids = call.argument<List<Int>>("ids") ?: emptyList()
					ids.forEach(::cancelScheduledNotification)
					result.success(null)
				}

				else -> result.notImplemented()
			}
		}
	}
}