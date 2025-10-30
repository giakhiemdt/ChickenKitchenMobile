package com.example.mobiletest

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val methodsChannel = "com.example.mobiletest/deep_links/methods"
    private val eventsChannel = "com.example.mobiletest/deep_links/events"

    private var initialLink: String? = null
    private var eventsSink: EventChannel.EventSink? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Capture initial link if activity launched via intent
        handleIntent(intent)?.let {
            initialLink = it
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, methodsChannel)
            .setMethodCallHandler { call: MethodCall, result: MethodChannel.Result ->
                when (call.method) {
                    "getInitialLink" -> result.success(initialLink)
                    else -> result.notImplemented()
                }
            }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, eventsChannel)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventsSink = events
                }

                override fun onCancel(arguments: Any?) {
                    eventsSink = null
                }
            })
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        val link = handleIntent(intent)
        if (link != null) {
            eventsSink?.success(link)
        }
    }

    private fun handleIntent(intent: Intent?): String? {
        if (intent == null) return null
        if (Intent.ACTION_VIEW != intent.action) return null
        val data: Uri? = intent.data
        return data?.toString()
    }
}
