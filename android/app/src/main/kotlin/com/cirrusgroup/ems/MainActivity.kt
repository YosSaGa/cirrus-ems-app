package com.cirrusgroup.ems

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.cirrusgroup.ems/downloader"
    private val TIMER_CHANNEL = "com.cirrusgroup.ems/work_timer"
    private val TIMER_CHANNEL_ID = "cirrus_work_timer"
    private val TIMER_NOTIFICATION_ID = 4101
    private val JOB_ALERT_CHANNEL_ID = "cirrus_new_jobs"
    private val JOB_ALERT_NOTIFICATION_ID = 4103
    private val REQ_POST_NOTIFICATIONS = 4102

    private var pendingTimer: Triple<String, String, Long>? = null
    private var pendingJobAlert: Triple<String, String, Boolean>? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "saveToDownloads") {
                val bytes = call.argument<ByteArray>("bytes")
                val filename = call.argument<String>("filename")
                if (bytes == null || filename == null) {
                    result.error("INVALID_ARGS", "bytes or filename is null", null)
                    return@setMethodCallHandler
                }
                try {
                    val savedPath = saveFileToDownloads(filename, bytes)
                    result.success(savedPath)
                } catch (e: Exception) {
                    result.error("SAVE_FAILED", e.message, null)
                }
            } else {
                result.notImplemented()
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, TIMER_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "showWorkTimer" -> {
                    val title = call.argument<String>("title") ?: "ON SITE"
                    val body = call.argument<String>("body") ?: ""
                    val startMillis = call.argument<Number>("startEpochMillis")?.toLong()
                        ?: System.currentTimeMillis()
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
                        checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED
                    ) {
                        pendingTimer = Triple(title, body, startMillis)
                        requestPermissions(
                            arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                            REQ_POST_NOTIFICATIONS
                        )
                        result.success(false)
                        return@setMethodCallHandler
                    }
                    postWorkTimerNotification(title, body, startMillis)
                    result.success(true)
                }
                "cancelWorkTimer" -> {
                    pendingTimer = null
                    val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                    nm.cancel(TIMER_NOTIFICATION_ID)
                    result.success(true)
                }
                "showNewJobAlert" -> {
                    val title = call.argument<String>("title") ?: "New Job Code"
                    val body = call.argument<String>("body") ?: ""
                    val vibrate = call.argument<Boolean>("vibrate") ?: true
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
                        checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED
                    ) {
                        pendingJobAlert = Triple(title, body, vibrate)
                        requestPermissions(
                            arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                            REQ_POST_NOTIFICATIONS
                        )
                        result.success(false)
                        return@setMethodCallHandler
                    }
                    postNewJobAlertNotification(title, body, vibrate)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == REQ_POST_NOTIFICATIONS &&
            grantResults.isNotEmpty() &&
            grantResults[0] == PackageManager.PERMISSION_GRANTED
        ) {
            val pending = pendingTimer
            pendingTimer = null
            if (pending != null) {
                postWorkTimerNotification(pending.first, pending.second, pending.third)
            }
            val pendingAlert = pendingJobAlert
            pendingJobAlert = null
            if (pendingAlert != null) {
                postNewJobAlertNotification(pendingAlert.first, pendingAlert.second, pendingAlert.third)
            }
        }
    }

    private fun postNewJobAlertNotification(title: String, body: String, vibrate: Boolean) {
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                JOB_ALERT_CHANNEL_ID,
                "New Job Assignments",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Alerts when a new Job Code is assigned to you"
                enableVibration(true)
                vibrationPattern = longArrayOf(0, 280, 140, 280)
                setShowBadge(true)
            }
            nm.createNotificationChannel(channel)
        }

        val launchIntent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val piFlags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }
        val contentIntent = PendingIntent.getActivity(this, 1, launchIntent, piFlags)

        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, JOB_ALERT_CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }

        builder
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(Notification.BigTextStyle().bigText(body))
            .setAutoCancel(true)
            .setCategory(Notification.CATEGORY_MESSAGE)
            .setContentIntent(contentIntent)

        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            @Suppress("DEPRECATION")
            builder.setPriority(Notification.PRIORITY_HIGH)
            @Suppress("DEPRECATION")
            builder.setDefaults(if (vibrate) Notification.DEFAULT_ALL else Notification.DEFAULT_SOUND)
        }

        nm.notify(JOB_ALERT_NOTIFICATION_ID, builder.build())
    }

    private fun postWorkTimerNotification(title: String, body: String, startEpochMillis: Long) {
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                TIMER_CHANNEL_ID,
                "Active Job Timer",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Shows live elapsed time while working on a job"
                setShowBadge(false)
            }
            nm.createNotificationChannel(channel)
        }

        val launchIntent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val piFlags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }
        val contentIntent = PendingIntent.getActivity(this, 0, launchIntent, piFlags)

        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, TIMER_CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }

        builder
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(title)
            .setContentText(body)
            .setWhen(startEpochMillis)
            .setShowWhen(true)
            .setUsesChronometer(true)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setCategory(Notification.CATEGORY_PROGRESS)
            .setContentIntent(contentIntent)

        nm.notify(TIMER_NOTIFICATION_ID, builder.build())
    }

    private fun saveFileToDownloads(filename: String, bytes: ByteArray): String {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val values = ContentValues().apply {
                put(MediaStore.Downloads.DISPLAY_NAME, filename)
                put(MediaStore.Downloads.MIME_TYPE, "application/pdf")
                put(MediaStore.Downloads.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS)
            }
            val uri = contentResolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values)
                ?: throw IllegalStateException("Could not create MediaStore entry")
            contentResolver.openOutputStream(uri)?.use { stream ->
                stream.write(bytes)
            } ?: throw IllegalStateException("Could not open output stream")
            "Downloads/$filename"
        } else {
            val dir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)
            if (!dir.exists()) dir.mkdirs()
            val file = File(dir, filename)
            FileOutputStream(file).use { stream ->
                stream.write(bytes)
            }
            file.absolutePath
        }
    }
}
