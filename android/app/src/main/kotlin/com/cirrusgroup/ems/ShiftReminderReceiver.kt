package com.cirrusgroup.ems

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build

class ShiftReminderReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val id = intent.getIntExtra("id", 4201)
        val title = intent.getStringExtra("title") ?: "Cirrus EMS"
        val body = intent.getStringExtra("body") ?: "Time to scan attendance"

        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val channelId = "cirrus_shift_reminders"
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
            nm.getNotificationChannel(channelId) == null
        ) {
            val channel = NotificationChannel(
                channelId,
                "Shift Scan Reminders",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Daily reminders for attendance scan windows"
            }
            nm.createNotificationChannel(channel)
        }

        val launchIntent = context.packageManager
            .getLaunchIntentForPackage(context.packageName)
            ?.apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
            }
        val contentIntent = launchIntent?.let {
            PendingIntent.getActivity(
                context,
                id,
                it,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
        }

        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(context, channelId)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(context)
        }
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(title)
            .setContentText(body)
            .setAutoCancel(true)
            .setOnlyAlertOnce(true)

        if (contentIntent != null) {
            builder.setContentIntent(contentIntent)
        }

        nm.notify(id, builder.build())
    }
}
