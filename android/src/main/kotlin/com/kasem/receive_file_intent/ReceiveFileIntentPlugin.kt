package com.teamnifty.receive_file_intent

import android.content.Context
import android.content.Intent
import android.database.Cursor
import android.net.Uri
import android.os.Build
import android.provider.DocumentsContract
import android.provider.OpenableColumns
import android.webkit.MimeTypeMap
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry
import io.flutter.plugin.common.PluginRegistry.Registrar
import java.io.*
import java.util.*


class ReceiveFileIntentPlugin(val registrar: Registrar) :
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
        private val MESSAGES_CHANNEL = "receive_file_intent/messages"
        private val EVENTS_CHANNEL_TEXT = "receive_file_intent/events-text"
        private val EVENTS_CHANNEL_FILE = "receive_file_intent/events-file"

        @JvmStatic
        fun registerWith(registrar: Registrar) {
            // Detect if we've been launched in background
            if (registrar.activity() == null) {
                return
            }

            val instance = ReceiveFileIntentPlugin(registrar)

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
                val newPath = processUri(context, uri)
                if (newPath != null) arrayListOf(newPath) else null
            }
            intent.action == Intent.ACTION_SEND_MULTIPLE -> {
                val uris = intent.getParcelableArrayListExtra<Uri>(Intent.EXTRA_STREAM)
                val value = uris?.mapNotNull { processUri(context, it) }?.toList()
                if (value != null) ArrayList(value) else null
            }
            else -> null
        }
    }

    fun processUri(context: Context, uri: Uri): String? {
        val target = context.cacheDir.path
        val filename = getFileName(uri, context)
        val hasError = saveFile(context, filename, uri, target, filename)
        return target + "/" + filename
    }

    fun getFileName(uri: Uri, context: Context): String? {
        var result: String? = null
        if (uri.scheme == "content") {
            val cursor: Cursor = context.contentResolver.query(uri, null, null, null, null)
            try {
                if (cursor != null && cursor.moveToFirst()) {
                    result = cursor.getString(cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME))
                }
            } finally {
                cursor.close()
            }
        }
        if (result == null) {
            result = uri.path
            val cut = result.lastIndexOf('/')
            if (cut != -1) {
                result = result.substring(cut + 1)
            }
        }
        return result
    }

    private fun isVirtualFile(context: Context, uri: Uri): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT) {
            if (!DocumentsContract.isDocumentUri(context, uri)) {
                return false
            }
            val cursor: Cursor = context.contentResolver.query(
                    uri, arrayOf(DocumentsContract.Document.COLUMN_FLAGS),
                    null, null, null)
            var flags = 0
            if (cursor.moveToFirst()) {
                flags = cursor.getInt(0)
            }
            cursor.close()
            flags and DocumentsContract.Document.FLAG_VIRTUAL_DOCUMENT != 0
        } else {
            false
        }
    }

    @Throws(IOException::class)
    private fun getInputStreamForVirtualFile(context: Context, uri: Uri, mimeTypeFilter: String?): InputStream? {
        val resolver = context.contentResolver
        val openableMimeTypes = resolver.getStreamTypes(uri, mimeTypeFilter)
        if (openableMimeTypes == null || openableMimeTypes.size < 1) {
            throw FileNotFoundException()
        }
        return resolver
                .openTypedAssetFileDescriptor(uri, openableMimeTypes[0], null)
                .createInputStream()
    }

    private fun getMimeType(url: String?): String? {
        var type: String? = null
        val extension = MimeTypeMap.getFileExtensionFromUrl(url)
        if (extension != null) {
            type = MimeTypeMap.getSingleton().getMimeTypeFromExtension(extension)
        }
        return type
    }

    fun saveFile(context: Context, name: String?, sourceuri: Uri, destinationDir: String, destFileName: String?): Boolean {
        var bis: BufferedInputStream? = null
        var bos: BufferedOutputStream? = null
        var input: InputStream? = null
        var hasError = false
        try {
            if (isVirtualFile(context, sourceuri)) {
                input = getInputStreamForVirtualFile(context, sourceuri, getMimeType(name))
            } else {
                input = context.contentResolver.openInputStream(sourceuri)
            }
            val directorySetupResult: Boolean
            val destDir = File(destinationDir)
            directorySetupResult = if (!destDir.exists()) {
                destDir.mkdirs()
            } else if (!destDir.isDirectory) {
                replaceFileWithDir(destinationDir)
            } else {
                true
            }
            if (!directorySetupResult) {
                hasError = true
            } else {
                val destination = destinationDir + File.separator + destFileName
                val originalsize: Int = input!!.available()
                bis = BufferedInputStream(input)
                bos = BufferedOutputStream(FileOutputStream(destination))
                val buf = ByteArray(originalsize)
                bis.read(buf)
                do {
                    bos.write(buf)
                } while (bis.read(buf) !== -1)
            }
        } catch (e: Exception) {
            e.printStackTrace()
            hasError = true
        } finally {
            try {
                if (bos != null) {
                    bos.flush()
                    bos.close()
                }
            } catch (ignored: Exception) {
            }
        }
        return !hasError
    }

    private fun replaceFileWithDir(path: String): Boolean {
        val file = File(path)
        if (!file.exists()) {
            if (file.mkdirs()) {
                return true
            }
        } else if (file.delete()) {
            val folder = File(path)
            if (folder.mkdirs()) {
                return true
            }
        }
        return false
    }
}
