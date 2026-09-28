package com.dhimmah.dhimmah

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.provider.DocumentsContract
import android.provider.OpenableColumns
import android.provider.DocumentsContract.Document
import androidx.activity.result.ActivityResultLauncher
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.FileNotFoundException
import java.io.IOException
import java.util.concurrent.Executors

/**
 * Saving a backup to a file the user owns, through Android's own document flow.
 *
 * The app used to hand a snapshot to the system *share sheet*, which is a
 * different thing entirely: a share asks another application to receive a copy,
 * and on the phone this was tested on the sheet offered no file destination at
 * all — no Files, no Drive, nothing that stores a file — so a user could not end
 * up with a `.dhimmah` they owned. `share_plus` also cannot report where the copy
 * went, so the app could never verify one.
 *
 * This channel is `ACTION_CREATE_DOCUMENT`, the Android mechanism for
 * "let the user choose where this new document should live". It returns a
 * `content://` URI, which is *not* a filesystem path — nothing in Dart can open
 * it — so the bytes are written and read back here, through the
 * [ContentResolver], and only the facts cross back over the channel.
 *
 * Four narrow calls, no policy:
 *
 * * `createDocument` — asks the user where to put it, and answers with what they
 *   chose, or with null if they changed their mind;
 * * `write` — writes the bytes and answers with how many were written;
 * * `read` — reads the document back, so the copy can be verified rather than
 *   assumed;
 * * `metadata` — the name and size the provider reports for the document.
 *
 * I/O runs on a worker thread: a backup is megabytes, and `ContentResolver`
 * calls that size are not something to do on the thread drawing frames. Results
 * are posted back to the main thread, which is where Flutter expects them.
 *
 * The MIME type is `application/octet-stream`, deliberately. `.dhimmah` has no
 * registered type anywhere, and inventing one (`application/vnd.dhimmah`) makes
 * providers that do not know it refuse the document — which is how the restore
 * picker came to look empty. A generic binary type is what every provider
 * accepts, and the file's *content* is what makes it a backup; the app validates
 * it after reading, whatever it is called.
 */
class BackupFileChannel(
    private val activity: Activity,
    private val launcher: ActivityResultLauncher<String>,
    private val folderLauncher: ActivityResultLauncher<Uri?>,
) : MethodChannel.MethodCallHandler {

    companion object {
        const val METHOD_CHANNEL = "dhimmah/backup_file"

        /**
         * The type every provider accepts for an unregistered format.
         *
         * Asserted equal on the Dart side by `test/platform/android_setup_test.dart`,
         * and pinned there as the reason a fictional type must not come back.
         */
        const val MIME_TYPE = "application/octet-stream"

        private const val METHOD_CREATE = "createDocument"
        private const val METHOD_WRITE = "write"
        private const val METHOD_READ = "read"
        private const val METHOD_METADATA = "metadata"

        private const val METHOD_CHOOSE_FOLDER = "chooseFolder"
        private const val METHOD_CREATE_FOLDER = "createFolder"
        private const val METHOD_WRITE_DOCUMENT = "writeDocument"
        private const val METHOD_READ_DOCUMENT = "readDocument"
        private const val METHOD_LIST_DOCUMENTS = "listDocuments"
        private const val METHOD_DELETE_DOCUMENT = "deleteDocument"
        private const val METHOD_VERIFY_WRITABLE = "verifyWritable"
        private const val METHOD_DESCRIBE_FOLDER = "describeFolder"
        private const val METHOD_RELEASE_FOLDER = "releaseFolder"

        private const val ERROR_CANCELLED = "cancelled"
        private const val ERROR_IO = "io_error"
        private const val ERROR_EMPTY = "empty_bytes"
        private const val ERROR_URI = "bad_uri"
        private const val ERROR_FORBIDDEN = "forbidden"

        /** The subfolder this app keeps its portable backups in. */
        const val BACKUP_FOLDER_NAME = "Dhimmah Backups"

        /** A file written only to prove a folder can be written to, then removed. */
        private const val PROBE_NAME = ".dhimmah-write-test"

        /**
         * The two segments a document-provider URI can carry.
         *
         * `tree` alone is the grant the user gave; `tree` *and* `document` is a
         * document inside that grant, and it is the one that names the folder.
         */
        private const val TREE_SEGMENT = "tree"
        private const val DOCUMENT_SEGMENT = "document"
    }

    /** The `createDocument` call waiting for the user to choose a place. */
    private var pending: MethodChannel.Result? = null

    /** The `chooseFolder` call waiting for the user to choose a directory. */
    private var pendingFolder: MethodChannel.Result? = null

    private val io = Executors.newSingleThreadExecutor { runnable ->
        Thread(runnable, "dhimmah-backup-file").apply { isDaemon = true }
    }
    private val main = Handler(Looper.getMainLooper())

    /** Called by the activity when the user has chosen, or backed out. */
    fun onDocumentCreated(uri: Uri?) {
        val result = pending ?: return
        pending = null
        if (uri == null) {
            // Backing out is not a failure, and the Dart side learns nothing
            // happened rather than receiving an error to explain.
            result.success(null)
            return
        }
        onWorker(result) { describe(uri) }
    }

    /** Called by the activity when the user has chosen a folder, or backed out. */
    fun onFolderChosen(uri: Uri?) {
        val result = pendingFolder ?: return
        pendingFolder = null
        if (uri == null) {
            result.success(null)
            return
        }
        onWorker(result) {
            // The grant from `OpenDocumentTree` is persistable, and taking it is
            // what makes the folder still ours after the process dies: without
            // this, "remember the folder" would be a claim the next launch could
            // not keep.
            activity.contentResolver.takePersistableUriPermission(
                uri,
                Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION,
            )
            describeFolderRoot(uri)
        }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            METHOD_CREATE -> createDocument(call, result)
            METHOD_WRITE -> withUri(call, result) { uri, bytes ->
                write(uri, bytes).let { written -> mapOf("bytes" to written) }
            }

            METHOD_READ -> withUri(call, result) { uri, _ -> read(uri) }
            METHOD_METADATA -> withUri(call, result) { uri, _ -> describe(uri) }

            METHOD_CHOOSE_FOLDER -> chooseFolder(result)
            METHOD_CREATE_FOLDER -> withTree(call, result) { tree, _ ->
                createFolder(tree, call.argument<String>("name") ?: BACKUP_FOLDER_NAME)
            }

            METHOD_WRITE_DOCUMENT -> withTree(call, result) { tree, bytes ->
                writeIntoFolder(
                    tree,
                    call.argument<String>("name") ?: throw IllegalArgumentException("no name"),
                    bytes,
                )
            }

            METHOD_READ_DOCUMENT -> withUri(call, result) { uri, _ -> read(uri) }
            METHOD_LIST_DOCUMENTS -> withTree(call, result) { tree, _ -> listChildren(tree) }
            METHOD_DELETE_DOCUMENT -> withUri(call, result) { uri, _ ->
                if (DocumentsContract.deleteDocument(activity.contentResolver, uri)) {
                    mapOf("deleted" to true)
                } else {
                    throw IOException("the provider would not delete the document")
                }
            }

            METHOD_VERIFY_WRITABLE -> withTree(call, result) { tree, _ -> verifyWritable(tree) }
            METHOD_DESCRIBE_FOLDER -> withTree(call, result) { tree, _ -> describeFolderRoot(tree) }
            METHOD_RELEASE_FOLDER -> withUri(call, result) { uri, _ ->
                releaseFolder(uri).let { mapOf("released" to it) }
            }

            else -> result.notImplemented()
        }
    }

    /**
     * Opens Android's directory picker.
     *
     * `ACTION_OPEN_DOCUMENT_TREE` is the one mechanism that grants an app
     * standing access to a directory the user chose, without a storage
     * permission: the grant belongs to the user's choice, is persistable, and is
     * revocable by them.
     */
    private fun chooseFolder(result: MethodChannel.Result) {
        if (pendingFolder != null) {
            result.error(ERROR_IO, "a folder choice is already open", null)
            return
        }
        try {
            pendingFolder = result
            folderLauncher.launch(null)
        } catch (error: Exception) {
            pendingFolder = null
            result.error(ERROR_IO, error.message ?: "could not open the folder picker", null)
        }
    }

    /**
     * Makes `Dhimmah Backups` inside the folder the user chose — or adopts the
     * one that is already there.
     *
     * The lookup comes first, and that is not an optimisation. Android's own
     * storage provider does not refuse a duplicate directory name: asked to
     * create `Dhimmah Backups` in a folder that already has one, it creates
     * `Dhimmah Backups (1)` and returns it. So a user who reinstalls the app and
     * re-picks the same folder — the one moment they most need their backups
     * back — was handed an empty new folder, told "no backups in this folder",
     * and left writing beside the six real copies they could still see in their
     * own file manager. Nothing errored; the app simply looked somewhere else.
     *
     * Creating is still what happens when the name is free, and a provider that
     * refuses directory creation is still reported rather than worked around:
     * the app does not silently treat an arbitrary folder as its own.
     */
    @Throws(IOException::class)
    private fun createFolder(tree: Uri, name: String): Map<String, Any?> {
        val parent = folderDocumentUri(tree)
        val folderId = folderDocumentId(tree)
        findChildByName(tree, folderId, name, directory = true)?.let { existing ->
            return describeDocument(existing)
        }
        val created = DocumentsContract.createDocument(
            activity.contentResolver,
            parent,
            DocumentsContract.Document.MIME_TYPE_DIR,
            name,
        ) ?: throw IOException("the provider would not create a folder")
        return describeDocument(created)
    }

    /**
     * The folder a folder identifier names, as one document.
     *
     * Every folder operation in this class speaks **document** semantics, and the
     * reason is a bug this class shipped: `createFolder` hands back the new
     * folder as a *document* URI, while the operations below read it with
     * `getTreeDocumentId` — which on a document URI resolves to the **tree it
     * was built from**, silently retargeting every write and every listing to
     * the folder's *parent*. On the device this was tested on, the app reported
     * a folder called `Dhimmah Backups` while writing its backups into the
     * folder above it, and left the subfolder it had created empty.
     *
     * A document URI carries its own full document id, so `getDocumentId` on it
     * is the folder itself — the same kind of identifier in, the same kind out,
     * and no scope to silently widen.
     */
    private fun folderDocumentUri(uri: Uri): Uri =
        DocumentsContract.buildDocumentUriUsingTree(uri, folderDocumentId(uri))

    /**
     * The folder's own document id, from either kind of URI it may arrive as.
     *
     * The test is for the **document** segment, not the tree segment, and that
     * distinction is the whole of the bug above — which survived one attempt to
     * fix it, because the wrong segment was tested for. A URI built under a tree
     * carries both: the identifier stored after creating `Dhimmah Backups` reads
     * `…/tree/primary%3ADocuments/document/primary%3ADocuments%2FDhimmah%20Backups`.
     * Asking whether it *contains* `tree` answers yes, so `getTreeDocumentId`
     * was reached and returned `primary:Documents` — the folder's **parent**.
     * Writes and listings were retargeted one level up while the app reported a
     * verified save into `Dhimmah Backups`; the file appeared beside it, in
     * `Documents`, and the subfolder the user was shown stayed empty.
     *
     * A URI with a document segment names a document, so `getDocumentId` is the
     * folder itself. Only a bare tree URI has to be asked for its tree id.
     */
    private fun folderDocumentId(uri: Uri): String {
        val segments = uri.pathSegments
        return when {
            DOCUMENT_SEGMENT in segments -> DocumentsContract.getDocumentId(uri)
            TREE_SEGMENT in segments -> DocumentsContract.getTreeDocumentId(uri)
            else -> DocumentsContract.getDocumentId(uri)
        }
    }

    /**
     * Writes a document into the folder, creating it or replacing one of the
     * same name.
     *
     * The lookup is by name within *this* folder, because a backup's name is how
     * the user knows which one it is: writing `dhimmah-manual-…` twice should
     * replace the first, not litter the folder with ` (1)` copies that the
     * history then cannot tell apart.
     */
    @Throws(IOException::class)
    private fun writeIntoFolder(tree: Uri, name: String, bytes: ByteArray): Map<String, Any?> {
        if (bytes.isEmpty()) throw EmptyPayload("refusing to write an empty document")
        val folderId = folderDocumentId(tree)
        val folderUri = DocumentsContract.buildDocumentUriUsingTree(tree, folderId)

        val existing = findChildByName(tree, folderId, name)
        val target = existing
            ?: DocumentsContract.createDocument(
                activity.contentResolver,
                folderUri,
                MIME_TYPE,
                name,
            ) ?: throw IOException("the provider would not create the document")

        val written = write(target, bytes)
        return describe(target) + mapOf("bytes" to written, "replaced" to (existing != null))
    }

    /** Every child of the folder, as the provider describes it. */
    @Throws(IOException::class)
    private fun listChildren(tree: Uri): List<Map<String, Any?>> {
        val folderId = folderDocumentId(tree)
        val childrenUri = DocumentsContract.buildChildDocumentsUriUsingTree(tree, folderId)
        val projection = arrayOf(
            DocumentsContract.Document.COLUMN_DOCUMENT_ID,
            DocumentsContract.Document.COLUMN_DISPLAY_NAME,
            DocumentsContract.Document.COLUMN_SIZE,
            DocumentsContract.Document.COLUMN_LAST_MODIFIED,
            DocumentsContract.Document.COLUMN_MIME_TYPE,
        )
        val out = mutableListOf<Map<String, Any?>>()
        activity.contentResolver
            .query(childrenUri, projection, null, null, null)
            ?.use { cursor ->
                while (cursor.moveToNext()) {
                    val documentId =
                        cursor.getString(cursor.getColumnIndexOrThrow(DocumentsContract.Document.COLUMN_DOCUMENT_ID))
                    out.add(
                        mapOf(
                            "uri" to DocumentsContract.buildDocumentUriUsingTree(tree, documentId)
                                .toString(),
                            "displayName" to cursor.getString(
                                cursor.getColumnIndexOrThrow(DocumentsContract.Document.COLUMN_DISPLAY_NAME),
                            ),
                            "size" to (cursor.getLong(
                                cursor.getColumnIndexOrThrow(DocumentsContract.Document.COLUMN_SIZE),
                            )),
                            "lastModified" to cursor.getLong(
                                cursor.getColumnIndexOrThrow(DocumentsContract.Document.COLUMN_LAST_MODIFIED),
                            ),
                            "mimeType" to cursor.getString(
                                cursor.getColumnIndexOrThrow(DocumentsContract.Document.COLUMN_MIME_TYPE),
                            ),
                        ),
                    )
                }
            } ?: throw IOException("the folder could not be listed")
        return out
    }

    /**
     * The child of [tree] named [name], if the provider lists one.
     *
     * [directory] narrows it to a folder. It is what keeps "adopt the folder that
     * is already there" from adopting a *file* that happens to carry the same
     * name — the app would then treat a document as its backup location, and
     * every write into it would fail in a way that reads like a corrupt folder.
     */
    private fun findChildByName(
        tree: Uri,
        folderId: String,
        name: String,
        directory: Boolean = false,
    ): Uri? {
        for (child in listChildren(tree)) {
            if (child["displayName"] != name) continue
            if (directory &&
                child["mimeType"] != DocumentsContract.Document.MIME_TYPE_DIR
            ) {
                continue
            }
            return Uri.parse(child["uri"] as String)
        }
        // A folder that cannot be listed has no children to find; the caller's
        // own query would have thrown already.
        DocumentsContract.buildChildDocumentsUriUsingTree(tree, folderId)
        return null
    }

    /**
     * Proves the folder can be written to, by writing to it.
     *
     * A folder that lists fine but refuses writes is common — read-only views of
     * cloud folders, a provider whose grant has lapsed — and the only way to know
     * is to write something, read it back and take it away again.
     */
    @Throws(IOException::class)
    private fun verifyWritable(tree: Uri): Map<String, Any?> {
        val payload = "dhimmah".toByteArray(Charsets.UTF_8)
        val probe = writeIntoFolder(tree, PROBE_NAME, payload)
        val documentUri = Uri.parse(probe["uri"] as String)
        val readBack = read(documentUri)
        try {
            DocumentsContract.deleteDocument(activity.contentResolver, documentUri)
        } catch (error: Exception) {
            // A probe that cannot be removed is still evidence the folder is
            // writable; the app names the leftover rather than pretending the
            // test passed cleanly.
            throw IOException("the probe file could not be removed", error)
        }
        if (!readBack.contentEquals(payload)) {
            throw IOException("the probe file did not read back as what was written")
        }
        return mapOf("writable" to true)
    }

    /** Whether the app still holds a standing grant for this folder. */
    private fun hasPersistedPermission(uri: Uri): Boolean {
        val treeId = try {
            DocumentsContract.getTreeDocumentId(uri)
        } catch (error: IllegalArgumentException) {
            return false
        }
        for (permission in activity.contentResolver.persistedUriPermissions) {
            if (permission.uri.toString() == uri.toString() && permission.isReadPermission) {
                return true
            }
            if (DocumentsContract.getTreeDocumentId(permission.uri) == treeId &&
                permission.isReadPermission
            ) {
                return true
            }
        }
        return false
    }

    /** Gives the folder back: the user asked for a different one. */
    private fun releaseFolder(uri: Uri): Boolean {
        try {
            activity.contentResolver.releasePersistableUriPermission(
                uri,
                Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION,
            )
        } catch (error: SecurityException) {
            // Nothing held to release, or the provider already took it back.
            return false
        }
        return true
    }

    /** The folder the user picked, as one document, with the grant's state. */
    @Throws(IOException::class)
    private fun describeFolderRoot(tree: Uri): Map<String, Any?> {
        val documentUri = folderDocumentUri(tree)
        val described = describe(documentUri)
        return described + mapOf(
            "uri" to documentUri.toString(),
            "persisted" to hasPersistedPermission(tree),
        )
    }

    /** What the provider says about one document. */
    @Throws(IOException::class)
    private fun describeDocument(documentUri: Uri): Map<String, Any?> = describe(documentUri)

    private fun withTree(
        call: MethodCall,
        result: MethodChannel.Result,
        body: (Uri, ByteArray) -> Any?,
    ) {
        val raw = call.argument<String>("uri")
        if (raw.isNullOrBlank()) {
            result.error(ERROR_URI, "no folder was named", null)
            return
        }
        val tree = try {
            Uri.parse(raw)
        } catch (error: IllegalArgumentException) {
            result.error(ERROR_URI, error.message, null)
            return
        }
        val bytes = call.argument<ByteArray>("bytes") ?: ByteArray(0)
        onWorker(result) {
            try {
                body(tree, bytes)
            } catch (error: SecurityException) {
                // The standing grant is gone: the user revoked it, or the
                // provider withdrew it. That is a different situation from an
                // ordinary I/O error and the app offers to re-authorize.
                // Thrown on rather than answered here, because a `catch` block
                // that calls `result.error` *is* the body's value in Kotlin —
                // `Unit` — and `onWorker` would then post `Unit` to Flutter,
                // where the standard codec cannot encode it. That is not a
                // failed call, it is a dead process: found on the phone, where
                // moving the backup folder aside while the app was open killed
                // it instead of showing that the folder was unreachable.
                throw FolderForbidden(error.message)
            } catch (error: IllegalArgumentException) {
                throw FolderUnusable(error.message)
            }
        }
    }

    /** The grant on the folder is gone. Answered as [ERROR_FORBIDDEN]. */
    private class FolderForbidden(message: String?) : Exception(message)

    /** The folder or document the app was given cannot be used. [ERROR_URI]. */
    private class FolderUnusable(message: String?) : Exception(message)


    private fun createDocument(call: MethodCall, result: MethodChannel.Result) {
        if (pending != null) {
            result.error(ERROR_IO, "a document choice is already open", null)
            return
        }
        val name = call.argument<String>("name")
        if (name.isNullOrBlank()) {
            result.error(ERROR_IO, "a suggested name is required", null)
            return
        }
        try {
            pending = result
            launcher.launch(name)
        } catch (error: Exception) {
            pending = null
            result.error(ERROR_IO, error.message ?: "could not open the chooser", null)
        }
    }

    /** Runs a body off the main thread and answers on it. */
    private fun withUri(
        call: MethodCall,
        result: MethodChannel.Result,
        body: (Uri, ByteArray) -> Any?,
    ) {
        val raw = call.argument<String>("uri")
        if (raw.isNullOrBlank()) {
            result.error(ERROR_URI, "no document was named", null)
            return
        }
        val bytes = call.argument<ByteArray>("bytes") ?: ByteArray(0)
        onWorker(result) { body(Uri.parse(raw), bytes) }
    }

    private fun onWorker(result: MethodChannel.Result, body: () -> Any?) {
        io.execute {
            try {
                val value = body()
                main.post { result.success(value) }
            } catch (error: EmptyPayload) {
                main.post { result.error(ERROR_EMPTY, error.message, null) }
            } catch (error: IOException) {
                main.post { result.error(ERROR_IO, error.message, null) }
            } catch (error: SecurityException) {
                main.post { result.error(ERROR_IO, error.message, null) }
            } catch (error: IllegalArgumentException) {
                main.post { result.error(ERROR_URI, error.message, null) }
            } catch (error: FolderForbidden) {
                main.post { result.error(ERROR_FORBIDDEN, error.message, null) }
            } catch (error: FolderUnusable) {
                main.post { result.error(ERROR_URI, error.message, null) }
            }
        }
    }

    /**
     * Writes the whole document, then flushes and closes it.
     *
     * `"wt"` because a document the user picked may already exist: without the
     * truncation flag the new bytes would be written over the old ones and a
     * shorter backup would leave the tail of the previous file behind — a file
     * that is neither the old backup nor the new one. An empty payload is refused
     * outright rather than written, because a zero-byte document that reports
     * success is the one outcome this whole class exists to prevent.
     */
    @Throws(IOException::class)
    private fun write(uri: Uri, bytes: ByteArray): Int {
        if (bytes.isEmpty()) {
            throw EmptyPayload("refusing to write an empty document")
        }
        val stream = activity.contentResolver.openOutputStream(uri, "wt")
            ?: throw FileNotFoundException("the document could not be opened for writing")
        stream.use { out ->
            out.write(bytes)
            out.flush()
        }
        return bytes.size
    }

    @Throws(IOException::class)
    private fun read(uri: Uri): ByteArray {
        val stream = activity.contentResolver.openInputStream(uri)
            ?: throw FileNotFoundException("the document could not be opened for reading")
        return stream.use { it.readBytes() }
    }

    /** What the provider says the document is, never what it should be. */
    @Throws(IOException::class)
    private fun describe(uri: Uri): Map<String, Any?> {
        var name: String? = null
        var size: Long? = null
        val projection = arrayOf(OpenableColumns.DISPLAY_NAME, OpenableColumns.SIZE)
        val cursor = activity.contentResolver
            .query(uri, projection, null, null, null)
            ?: throw FileNotFoundException("the provider has no row for this document")
        cursor.use {
            // A folder that was deleted outside the app still has a standing
            // grant, and the query succeeds — with no row in it. Without this
            // check the app reported a vanished folder as available with zero
            // backups, and the user found out when a save failed.
            if (!it.moveToFirst()) {
                throw FileNotFoundException("the folder no longer exists")
            }
            val nameIndex = it.getColumnIndex(OpenableColumns.DISPLAY_NAME)
            if (nameIndex >= 0 && !it.isNull(nameIndex)) {
                name = it.getString(nameIndex)
            }
            val sizeIndex = it.getColumnIndex(OpenableColumns.SIZE)
            if (sizeIndex >= 0 && !it.isNull(sizeIndex)) {
                size = it.getLong(sizeIndex)
            }
        }
        return mapOf(
            "uri" to uri.toString(),
            // The provider is the authority on the name: it may have appended an
            // extension of its own, and the app reports what is actually there
            // rather than what it suggested.
            "displayName" to (name ?: lastSegment(uri)),
            "size" to size,
        )
    }

    private fun lastSegment(uri: Uri): String =
        uri.lastPathSegment?.substringAfterLast('/') ?: "backup"

    fun dispose() {
        pending = null
        pendingFolder = null
        io.shutdown()
    }
}

/** A payload with nothing in it, kept apart so the Dart side can name it. */
private class EmptyPayload(message: String) : IOException(message)
