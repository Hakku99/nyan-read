package com.example.nyan_read

import android.app.SearchManager
import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.DocumentsContract
import android.view.WindowManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream
import java.util.UUID
import java.util.concurrent.Executors

// FlutterFragmentActivity (not FlutterActivity): local_auth's BiometricPrompt
// needs a FragmentActivity, otherwise authenticate() throws no_fragment_activity
// and the private-shelf fingerprint key silently does nothing. The picker
// request codes below must stay within 16 bits (FragmentActivity restriction).
class MainActivity : FlutterFragmentActivity() {
    companion object {
        private const val CHANNEL = "com.example.nyan_read/book_source"
        private const val PRIVACY_CHANNEL = "com.example.nyan_read/privacy"
        private const val SYSTEM_CHANNEL = "com.example.nyan_read/system"
        // readUriBytes loads the whole file into a ByteArray; guard against
        // OOM on unusually large files (>100 MB). Callers that need to handle
        // larger files should use copyUriToTempFile + stream-read instead.
        private const val MAX_MEMORY_READ_BYTES = 100L * 1024L * 1024L

        private const val REQUEST_PICK_LIBRARY_FOLDER = 0x4E59
        private const val REQUEST_PICK_MANY_FILES = 0x4E5A

        // Library-folder scan guards: a pathological tree should truncate,
        // not hang (docs/DESIGN_LIBRARY_FOLDERS.md §3).
        private const val MAX_TREE_DOCUMENTS = 2000
        private const val MAX_TREE_DEPTH = 10
    }

    // One in-flight picker at a time; the Result is parked here until
    // onActivityResult delivers. A second call while parked errors out.
    private var pendingActivityResult: MethodChannel.Result? = null

    // MethodChannel handlers run on the platform main thread, but every call
    // on this channel does SAF/provider I/O — copyUriToTempFile streams the
    // whole book, which froze rendering (ANR risk) on 100MB+ files. All work
    // is dispatched here; Result callbacks must still fire on the main
    // thread, hence mainHandler.
    // ponytail: one shared I/O thread serializes SAF calls; pool it if
    // parallel imports ever matter.
    private val ioExecutor = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun onDestroy() {
        ioExecutor.shutdown()
        super.onDestroy()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // FLAG_SECURE toggle for private-shelf screens: blanks screenshots,
        // screen recording and the recents thumbnail. Visibility gate only.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, PRIVACY_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "setSecure" -> {
                        if (call.argument<Boolean>("secure") == true) {
                            window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
                        } else {
                            window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                        }
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }

        // Selection "Search": defer to the user's default search app rather
        // than a hard-coded engine (google.com is blocked in mainland China).
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SYSTEM_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "webSearch" -> {
                        val intent = Intent(Intent.ACTION_WEB_SEARCH)
                            .putExtra(SearchManager.QUERY, call.argument<String>("query"))
                        val opened = try {
                            startActivity(intent)
                            true
                        } catch (e: ActivityNotFoundException) {
                            false
                        }
                        result.success(opened)
                    }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                val uriString = call.argument<String>("uri")

                // Computes [compute] on the I/O thread and posts the result
                // (or a domain error) back to the platform thread.
                fun respond(compute: () -> Any?) {
                    ioExecutor.execute {
                        try {
                            val value = compute()
                            mainHandler.post { result.success(value) }
                        } catch (e: Exception) {
                            mainHandler.post {
                                result.error("book_source_error", e.message, null)
                            }
                        }
                    }
                }

                when (call.method) {
                    "persistReadPermission" -> respond {
                        require(!uriString.isNullOrBlank()) { "uri is required" }
                        persistReadPermission(uriString)
                    }

                    "isUriReadable" -> respond {
                        require(!uriString.isNullOrBlank()) { "uri is required" }
                        isUriReadable(uriString)
                    }

                    "readUriBytes" -> respond {
                        require(!uriString.isNullOrBlank()) { "uri is required" }
                        readUriBytes(uriString)
                    }

                    "copyUriToTempFile" -> respond {
                        require(!uriString.isNullOrBlank()) { "uri is required" }
                        copyUriToTempFile(uriString, call.argument<String>("extension"))
                    }

                    // Import fingerprinting needs only the size plus the first
                    // and last `sampleBytes`; reading just those avoids
                    // copying (or loading) the whole book.
                    "sampleUri" -> respond {
                        require(!uriString.isNullOrBlank()) { "uri is required" }
                        val sampleBytes = call.argument<Int>("sampleBytes")
                        require(sampleBytes != null && sampleBytes > 0) {
                            "sampleBytes is required"
                        }
                        sampleUri(uriString, sampleBytes)
                    }

                    "deletePersistedUriDocument" -> respond {
                        require(!uriString.isNullOrBlank()) { "uri is required" }
                        deletePersistedUriDocument(uriString)
                    }

                    // ── Library folders (docs/DESIGN_LIBRARY_FOLDERS.md) ──

                    // Picker launches must stay on the platform thread and
                    // resolve via onActivityResult, so they bypass respond().
                    "pickLibraryFolder" -> launchPicker(result,
                        Intent(Intent.ACTION_OPEN_DOCUMENT_TREE),
                        REQUEST_PICK_LIBRARY_FOLDER)

                    // Quota probe: multi-select ACTION_OPEN_DOCUMENT, then
                    // persist every returned uri to observe limit behavior.
                    "pickAndPersistManyFiles" -> launchPicker(result,
                        Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                            type = "*/*"
                            addCategory(Intent.CATEGORY_OPENABLE)
                            putExtra(Intent.EXTRA_ALLOW_MULTIPLE, true)
                        },
                        REQUEST_PICK_MANY_FILES)

                    "listTreeDocuments" -> respond {
                        require(!uriString.isNullOrBlank()) { "uri is required" }
                        listTreeDocuments(uriString)
                    }

                    "listPersistedPermissions" -> respond {
                        listPersistedPermissions()
                    }

                    "releasePersistedPermission" -> respond {
                        require(!uriString.isNullOrBlank()) { "uri is required" }
                        releasePersistedPermission(uriString)
                    }

                    // SAF-probe cleanup only: hand back every persisted
                    // grant. Returns the number released.
                    "releaseAllPersistedPermissions" -> respond {
                        var released = 0
                        for (g in contentResolver.persistedUriPermissions) {
                            if (releasePersistedPermission(g.uri.toString())) {
                                released++
                            }
                        }
                        released
                    }

                    else -> result.notImplemented()
                }
            }
    }

    private fun launchPicker(
        result: MethodChannel.Result,
        intent: Intent,
        requestCode: Int,
    ) {
        if (pendingActivityResult != null) {
            result.error("book_source_error", "picker already in progress", null)
            return
        }
        pendingActivityResult = result
        try {
            startActivityForResult(intent, requestCode)
        } catch (e: Exception) {
            pendingActivityResult = null
            result.error("book_source_error", e.message, null)
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        when (requestCode) {
            REQUEST_PICK_LIBRARY_FOLDER -> {
                val res = pendingActivityResult ?: return
                pendingActivityResult = null
                val uri = data?.data
                if (resultCode != RESULT_OK || uri == null) {
                    res.success(null) // user cancelled
                    return
                }
                try {
                    contentResolver.takePersistableUriPermission(
                        uri, Intent.FLAG_GRANT_READ_URI_PERMISSION)
                    res.success(mapOf(
                        "uri" to uri.toString(),
                        "name" to treeDisplayName(uri),
                    ))
                } catch (e: Exception) {
                    res.error("book_source_error", e.message, null)
                }
            }

            REQUEST_PICK_MANY_FILES -> {
                val res = pendingActivityResult ?: return
                pendingActivityResult = null
                if (resultCode != RESULT_OK || data == null) {
                    res.success(null)
                    return
                }
                val uris = ArrayList<Uri>()
                data.data?.let { uris.add(it) }
                data.clipData?.let { clip ->
                    for (i in 0 until clip.itemCount) uris.add(clip.getItemAt(i).uri)
                }
                ioExecutor.execute {
                    var persisted = 0
                    var failed = 0
                    var firstError: String? = null
                    for (u in uris) {
                        try {
                            contentResolver.takePersistableUriPermission(
                                u, Intent.FLAG_GRANT_READ_URI_PERMISSION)
                            persisted++
                        } catch (e: Exception) {
                            failed++
                            if (firstError == null) firstError = e.toString()
                        }
                    }
                    val countAfter = contentResolver.persistedUriPermissions.size
                    mainHandler.post {
                        res.success(mapOf(
                            "attempted" to uris.size,
                            "persisted" to persisted,
                            "failed" to failed,
                            "firstError" to firstError,
                            "grantCountAfter" to countAfter,
                        ))
                    }
                }
            }

            else -> super.onActivityResult(requestCode, resultCode, data)
        }
    }

    private fun treeDisplayName(treeUri: Uri): String? {
        return try {
            val docUri = DocumentsContract.buildDocumentUriUsingTree(
                treeUri, DocumentsContract.getTreeDocumentId(treeUri))
            contentResolver.query(
                docUri,
                arrayOf(DocumentsContract.Document.COLUMN_DISPLAY_NAME),
                null, null, null,
            )?.use { if (it.moveToFirst()) it.getString(0) else null }
        } catch (_: Exception) {
            null
        }
    }

    /// BFS over the tree via buildChildDocumentsUriUsingTree; returns book
    /// files only (txt/epub/pdf by extension OR mime — some providers report
    /// octet-stream). Bounded by MAX_TREE_DOCUMENTS/MAX_TREE_DEPTH.
    private fun listTreeDocuments(treeUriString: String): Map<String, Any?> {
        val startedAt = System.currentTimeMillis()
        val treeUri = Uri.parse(treeUriString)
        val documents = ArrayList<Map<String, Any?>>()
        var truncated = false

        val queue = java.util.ArrayDeque<Pair<String, Int>>()
        queue.add(DocumentsContract.getTreeDocumentId(treeUri) to 0)
        while (queue.isNotEmpty()) {
            if (documents.size >= MAX_TREE_DOCUMENTS) {
                truncated = true
                break
            }
            val (docId, depth) = queue.removeFirst()
            if (depth > MAX_TREE_DEPTH) {
                truncated = true
                continue
            }
            val childrenUri =
                DocumentsContract.buildChildDocumentsUriUsingTree(treeUri, docId)
            contentResolver.query(
                childrenUri,
                arrayOf(
                    DocumentsContract.Document.COLUMN_DOCUMENT_ID,
                    DocumentsContract.Document.COLUMN_DISPLAY_NAME,
                    DocumentsContract.Document.COLUMN_MIME_TYPE,
                    DocumentsContract.Document.COLUMN_SIZE,
                    DocumentsContract.Document.COLUMN_LAST_MODIFIED,
                ),
                null, null, null,
            )?.use { cursor ->
                while (cursor.moveToNext()) {
                    if (documents.size >= MAX_TREE_DOCUMENTS) {
                        truncated = true
                        break
                    }
                    val childId = cursor.getString(0) ?: continue
                    val name = cursor.getString(1) ?: continue
                    val mime = cursor.getString(2) ?: ""
                    if (mime == DocumentsContract.Document.MIME_TYPE_DIR) {
                        queue.add(childId to depth + 1)
                    } else if (isBookFile(name, mime)) {
                        documents.add(mapOf(
                            "uri" to DocumentsContract
                                .buildDocumentUriUsingTree(treeUri, childId)
                                .toString(),
                            "name" to name,
                            "size" to cursor.getLong(3),
                            "lastModified" to cursor.getLong(4),
                        ))
                    }
                }
            }
        }
        return mapOf(
            "documents" to documents,
            "truncated" to truncated,
            "elapsedMs" to (System.currentTimeMillis() - startedAt),
        )
    }

    private fun isBookFile(name: String, mime: String): Boolean {
        val lower = name.lowercase()
        if (lower.endsWith(".txt") || lower.endsWith(".epub") ||
            lower.endsWith(".pdf")) {
            return true
        }
        return mime == "text/plain" || mime == "application/epub+zip" ||
            mime == "application/pdf"
    }

    private fun listPersistedPermissions(): Map<String, Any?> {
        val grants = contentResolver.persistedUriPermissions
        val trees = ArrayList<Map<String, Any?>>()
        for (g in grants) {
            if (!g.isReadPermission) continue
            if (g.uri.pathSegments.firstOrNull() != "tree") continue
            trees.add(mapOf(
                "uri" to g.uri.toString(),
                "name" to treeDisplayName(g.uri),
            ))
        }
        return mapOf("totalCount" to grants.size, "trees" to trees)
    }

    private fun releasePersistedPermission(uriString: String): Boolean {
        val uri = Uri.parse(uriString)
        val before = contentResolver.persistedUriPermissions
        // The grant can be recorded under a different URI form than the one
        // the picker returned (observed: Downloads provider hands out
        // `msf:<id>` but the system stores `raw:<path>`), so an exact match is
        // only used to pick the flags; the release is attempted regardless and
        // judged by whether the persisted count actually dropped.
        val grant = before.firstOrNull { it.uri == uri }
        var flags = Intent.FLAG_GRANT_READ_URI_PERMISSION or
            Intent.FLAG_GRANT_WRITE_URI_PERMISSION
        if (grant != null) {
            flags = 0
            if (grant.isReadPermission) flags = flags or Intent.FLAG_GRANT_READ_URI_PERMISSION
            if (grant.isWritePermission) flags = flags or Intent.FLAG_GRANT_WRITE_URI_PERMISSION
        }
        return try {
            contentResolver.releasePersistableUriPermission(uri, flags)
            contentResolver.persistedUriPermissions.size < before.size
        } catch (_: Exception) {
            false
        }
    }

    private fun persistReadPermission(uriString: String): Boolean {
        val uri = Uri.parse(uriString)
        // Prefer read+write persistence so SAF deletes can succeed when the
        // provider allows it; fall back to read-only if the picker grant lacks write.
        val readWriteFlags =
            Intent.FLAG_GRANT_READ_URI_PERMISSION or
                Intent.FLAG_GRANT_WRITE_URI_PERMISSION
        return try {
            contentResolver.takePersistableUriPermission(uri, readWriteFlags)
            true
        } catch (_: SecurityException) {
            try {
                contentResolver.takePersistableUriPermission(
                    uri,
                    Intent.FLAG_GRANT_READ_URI_PERMISSION,
                )
                true
            } catch (_: SecurityException) {
                false
            } catch (_: UnsupportedOperationException) {
                false
            }
        } catch (_: UnsupportedOperationException) {
            false
        }
    }

    private fun isUriReadable(uriString: String): Boolean {
        val uri = Uri.parse(uriString)
        return try {
            contentResolver.openInputStream(uri)?.use { true } ?: false
        } catch (_: Exception) {
            false
        }
    }

    private fun readUriBytes(uriString: String): ByteArray {
        val uri = Uri.parse(uriString)
        // Check file size before allocating — avoids OOM on very large files.
        contentResolver.openFileDescriptor(uri, "r")?.use { pfd ->
            val sizeBytes = pfd.statSize
            if (sizeBytes > MAX_MEMORY_READ_BYTES) {
                val sizeMb = sizeBytes / (1024L * 1024L)
                throw IllegalStateException(
                    "File too large to load into memory (${sizeMb} MB). " +
                    "Maximum supported size for in-memory reading is " +
                    "${MAX_MEMORY_READ_BYTES / (1024L * 1024L)} MB."
                )
            }
        }
        contentResolver.openInputStream(uri)?.use { input ->
            return input.readBytes()
        }
        throw IllegalStateException("Unable to open Uri: $uriString")
    }

    private fun copyUriToTempFile(uriString: String, extension: String?): String {
        val uri = Uri.parse(uriString)
        val tempDir = File(cacheDir, "book_sources").apply {
            mkdirs()
        }
        val safeExtension = sanitizeExtension(extension)
        val tempFile = File(tempDir, "${UUID.randomUUID()}$safeExtension")

        contentResolver.openInputStream(uri)?.use { input ->
            FileOutputStream(tempFile).use { output ->
                input.copyTo(output)
            }
        } ?: throw IllegalStateException("Unable to open Uri: $uriString")

        return tempFile.absolutePath
    }

    /// Reads through the file descriptor's channel (positional reads), NOT a
    /// path: scoped storage forbids reopening the underlying path. Returns
    /// size, the first min(size, n) bytes, and the last n bytes when size > n
    /// (empty otherwise) — the exact layout BookImportFingerprint hashes.
    /// Throws for providers without a known size or without random access
    /// (pipes, some cloud providers) so Dart falls back to the copy path.
    private fun sampleUri(uriString: String, n: Int): Map<String, Any> {
        val uri = Uri.parse(uriString)
        val pfd = contentResolver.openFileDescriptor(uri, "r")
            ?: throw IllegalStateException("Unable to open Uri: $uriString")
        pfd.use {
            val size = it.statSize
            if (size < 0) {
                throw IllegalStateException("Unknown size for Uri: $uriString")
            }
            // The whole-file path hashes the stream length, so a provider whose
            // descriptor size disagrees with its advertised size (stale cloud
            // metadata, still syncing) would yield a different signature with
            // no error. Disagreement => let Dart take the copy path.
            val declared = declaredSize(uri)
            if (declared != null && declared != size) {
                throw IllegalStateException("Size mismatch for Uri: $uriString")
            }
            java.io.FileInputStream(it.fileDescriptor).channel.use { channel ->
                fun readAt(position: Long, length: Int): ByteArray {
                    val buffer = java.nio.ByteBuffer.allocate(length)
                    var at = position
                    while (buffer.hasRemaining()) {
                        val read = channel.read(buffer, at)
                        if (read < 0) {
                            throw IllegalStateException("Short read for Uri: $uriString")
                        }
                        at += read
                    }
                    return buffer.array()
                }

                val headLength = minOf(size, n.toLong()).toInt()
                val head = readAt(0L, headLength)
                val tail =
                    if (size > n) readAt(size - n, n) else ByteArray(0)
                return mapOf("size" to size, "head" to head, "tail" to tail)
            }
        }
    }

    /// OpenableColumns.SIZE for [uri], or null when the provider does not
    /// report one (or reports an unknown size).
    private fun declaredSize(uri: Uri): Long? {
        return try {
            contentResolver.query(
                uri, arrayOf(android.provider.OpenableColumns.SIZE), null, null, null
            )?.use { cursor ->
                if (!cursor.moveToFirst() || cursor.isNull(0)) null
                else cursor.getLong(0).takeIf { it >= 0 }
            }
        } catch (_: Exception) {
            null
        }
    }

    private fun sanitizeExtension(extension: String?): String {
        val normalized = extension?.trim()?.lowercase().orEmpty()
        if (normalized.isEmpty()) return ".tmp"
        return if (normalized.startsWith('.')) normalized else ".$normalized"
    }

    private fun deletePersistedUriDocument(uriString: String): Boolean {
        val uri = Uri.parse(uriString)
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.KITKAT) {
            return false
        }
        return try {
            DocumentsContract.deleteDocument(contentResolver, uri)
        } catch (_: SecurityException) {
            false
        } catch (_: UnsupportedOperationException) {
            false
        } catch (_: IllegalArgumentException) {
            false
        }
    }
}

