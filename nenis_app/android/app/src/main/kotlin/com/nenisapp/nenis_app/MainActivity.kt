package com.nenisapp.nenis_app

import android.content.pm.PackageManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val googleMapsChannel = "nenis_app/google_maps"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, googleMapsChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "hasAndroidApiKey" -> result.success(hasGoogleMapsApiKey())
                    else -> result.notImplemented()
                }
            }
    }

    @Suppress("DEPRECATION")
    private fun hasGoogleMapsApiKey(): Boolean {
        val info = packageManager.getApplicationInfo(packageName, PackageManager.GET_META_DATA)
        val value = info.metaData
            ?.getString("com.google.android.geo.API_KEY")
            ?.trim()
            .orEmpty()

        return value.isNotEmpty() &&
            !value.equals("YOUR_API_KEY", ignoreCase = true) &&
            !value.contains("GOOGLE_MAPS_API_KEY")
    }
}
