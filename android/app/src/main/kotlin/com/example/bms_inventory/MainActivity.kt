package com.example.bms_inventory

import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel

class MainActivity : FlutterActivity() {

    private val GNSS_CHANNEL = "bms/gnss"
    private var locationManager: LocationManager? = null
    private var eventSink: EventChannel.EventSink? = null
    private var listener: LocationListener? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        locationManager = getSystemService(LOCATION_SERVICE) as LocationManager

        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            GNSS_CHANNEL
        ).setStreamHandler(object : EventChannel.StreamHandler {

            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                eventSink = events
                startGnss()
            }

            override fun onCancel(arguments: Any?) {
                stopGnss()
                eventSink = null
            }
        })
    }

    private fun startGnss() {
        try {
            listener = object : LocationListener {
                override fun onLocationChanged(loc: Location) {
                    val data = mapOf(
                        "lat" to loc.latitude,
                        "lng" to loc.longitude,
                        "accuracy" to loc.accuracy.toDouble(),
                        "bearing" to loc.bearing.toDouble(),
                        "speed" to loc.speed.toDouble(),
                        "altitude" to loc.altitude
                    )
                    eventSink?.success(data)
                }
            }

            locationManager?.requestLocationUpdates(
                LocationManager.GPS_PROVIDER,
                500L,
                0f,
                listener!!
            )

        } catch (e: SecurityException) {
            eventSink?.error("PERMISSION", "Location permission denied", null)
        }
    }

    private fun stopGnss() {
        try {
            listener?.let {
                locationManager?.removeUpdates(it)
            }
            listener = null
        } catch (_: Exception) {
        }
    }
}
