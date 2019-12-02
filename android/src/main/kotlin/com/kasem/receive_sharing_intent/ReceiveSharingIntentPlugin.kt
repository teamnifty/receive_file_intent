package com.kasem.receive_sharing_intent

import android.content.Context
import android.content.Intent
import android.net.Uri
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry
import io.flutter.plugin.common.PluginRegistry.Registrar
import java.util.*

class ReceiveSharingIntentPlugin(val registrar: Registrar) :
        MethodCallHandler,
        EventChannel.StreamHandler,
        PluginRegistry.NewIntentListener {

    private var initialText: String? = null
    private var latestText: String? = null

    private var initialFile: ArrayList<String>? = null
    private var latestFile: ArrayList<String>? = null

    private var eventSinkText: EventChannel.EventSink? = null
    private var eventSinkFile: EventChannel.EventSink? = null

    init {
        handleIntent(registrar.context(), registrar.activity().intent, true)
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        when (arguments) {
            "text" -> eventSinkText = events
            "file" -> eventSinkFile = events
        }
    }

    override fun onCancel(arguments: Any?) {
        when (arguments) {
            "text" -> eventSinkText = null
            "file" -> eventSinkFile = null
        }
    }

    override fun onNewIntent(intent: Intent): Boolean {
        handleIntent(registrar.context(), intent, false)
        return false
    }

    companion object {
        private val MESSAGES_CHANNEL = "receive_sharing_intent/messages"
        private val EVENTS_CHANNEL_TEXT = "receive_sharing_intent/events-text"
        private val EVENTS_CHANNEL_FILE = "receive_sharing_intent/events-file"

        @JvmStatic
        fun registerWith(registrar: Registrar) {
            // Detect if we've been launched in background
            if (registrar.activity() == null) {
                return
            }

            val instance = ReceiveSharingIntentPlugin(registrar)

            val mChannel = MethodChannel(registrar.messenger(), MESSAGES_CHANNEL)
            mChannel.setMethodCallHandler(instance)

            val eChannelText = EventChannel(registrar.messenger(), EVENTS_CHANNEL_TEXT)
            eChannelText.setStreamHandler(instance)

            val eChannelFile = EventChannel(registrar.messenger(), EVENTS_CHANNEL_FILE)
            eChannelFile.setStreamHandler(instance)

            registrar.addNewIntentListener(instance)
        }
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when {
            call.method == "getInitialText" -> result.success(initialText)
            call.method == "getInitialFile" -> result.success(initialFile)
            call.method == "reset" -> {
                initialText = null
                latestText = null
                initialFile = null
                latestFile = null
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun handleIntent(context: Context, intent: Intent, initial: Boolean) {
        when {
            (intent.type == null || intent.type?.startsWith("text") == true)
                    && intent.action == Intent.ACTION_SEND -> { // Sharing text
                val value = intent.getStringExtra(Intent.EXTRA_TEXT)
                if (initial) initialText = value
                latestText = value
                eventSinkText?.success(latestText)
            }
            intent.action == Intent.ACTION_VIEW -> { // Opening URL
                val value = intent.dataString
                if (initial) initialText = value
                latestText = value
                eventSinkText?.success(latestText)
            }
            else -> { // File
                val value = getFileUris(context, intent)
                if (initial) initialFile = value
                latestFile = value
                eventSinkFile?.success(latestFile)
            }
        }
    }

    private fun getFileUris(context: Context, intent: Intent?): ArrayList<String>? {
        if (intent == null) return null

        return when {
            intent.action == Intent.ACTION_SEND -> {
                val uri = intent.getParcelableExtra<Uri>(Intent.EXTRA_STREAM)
                val absolute = FileDirectory.getAbsolutePath(context, uri)
                if (absolute != null) arrayListOf(absolute) else null
            }
            intent.action == Intent.ACTION_SEND_MULTIPLE -> {
                val uris = intent.getParcelableArrayListExtra<Uri>(Intent.EXTRA_STREAM)
                val value = uris?.mapNotNull { FileDirectory.getAbsolutePath(context, it) }?.toList()
                if (value != null) ArrayList(value) else null
            }
            else -> null
        }
    }
}
