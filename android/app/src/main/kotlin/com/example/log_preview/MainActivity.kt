package com.example.log_preview

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.log_preview/intent"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method == "getInitialFile") {
                    val path = handleIntent(intent)
                    if (path != null) {
                        result.success(path)
                    } else {
                        result.success(null)
                    }
                } else {
                    result.notImplemented()
                }
            }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        // 通知 Flutter 层有新文件
        val path = handleIntent(intent)
        if (path != null) {
            MethodChannel(
                flutterEngine!!.dartExecutor.binaryMessenger,
                CHANNEL
            ).invokeMethod("onNewFile", path)
        }
    }

    private fun handleIntent(intent: Intent?): String? {
        if (intent?.action != Intent.ACTION_VIEW) return null
        val uri = intent?.data ?: return null
        return copyToCache(uri)
    }

    private fun copyToCache(uri: Uri): String? {
        return try {
            val fileName = uri.lastPathSegment ?: "shared_log.log"
            val cacheFile = File(cacheDir, fileName)
            contentResolver.openInputStream(uri)?.use { input ->
                FileOutputStream(cacheFile).use { output ->
                    input.copyTo(output)
                }
            }
            cacheFile.absolutePath
        } catch (e: Exception) {
            null
        }
    }
}
