package tw.offline.icd.icd_dictionary

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.StatFs
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private val worker = Executors.newSingleThreadExecutor()
    private var pickerResult: MethodChannel.Result? = null
    private val pickerCode = 7312
    private val maxPackageBytes = 256L * 1024 * 1024

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "tw.offline.icd/storage")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "availableBytes" -> try { result.success(StatFs(call.arguments as String).availableBytes) }
                        catch (e: Exception) { result.error("STORAGE", "Cannot inspect available storage", null) }
                    "pickPackage" -> {
                        if (pickerResult != null) result.error("BUSY", "A file picker is already open", null)
                        else {
                            pickerResult = result
                            try {
                                startActivityForResult(Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                                    addCategory(Intent.CATEGORY_OPENABLE)
                                    type = "*/*"
                                    addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                                }, pickerCode)
                            } catch (e: Exception) {
                                pickerResult = null
                                result.error("PICKER", "Unable to open document picker", null)
                            }
                        }
                    }
                    // Internal test hook: debug builds only, same bounded URI-copy implementation.
                    "debugCopyPackageUri" -> {
                        if ((applicationInfo.flags and android.content.pm.ApplicationInfo.FLAG_DEBUGGABLE) == 0) result.notImplemented()
                        else copyPackage(Uri.parse(call.arguments as String), result)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode != pickerCode) { super.onActivityResult(requestCode, resultCode, data); return }
        val result = pickerResult ?: return
        pickerResult = null
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) { result.success(null); return }
        copyPackage(uri, result)
    }

    private fun copyPackage(uri: Uri, result: MethodChannel.Result) {
        worker.execute {
            var output: File? = null
            try {
                val folder = File(cacheDir, "icd-import").apply { mkdirs() }
                val targetFile = File.createTempFile("package-", ".icdpack", folder)
                output = targetFile
                contentResolver.openInputStream(uri).use { input ->
                    requireNotNull(input) { "Cannot open selected document" }
                    targetFile.outputStream().use { target ->
                        val buffer = ByteArray(64 * 1024)
                        var size = 0L
                        while (true) {
                            val count = input.read(buffer)
                            if (count < 0) break
                            size += count
                            require(size <= maxPackageBytes) { "Package exceeds 256 MiB" }
                            require(StatFs(folder.path).availableBytes > count + 16L * 1024 * 1024) { "Insufficient free storage" }
                            target.write(buffer, 0, count)
                        }
                    }
                }
                val path = targetFile.absolutePath
                runOnUiThread { result.success(path) }
            } catch (e: Exception) {
                output?.delete() // Only this invocation's newly-created temporary copy.
                runOnUiThread { result.error("IMPORT_COPY", e.message ?: "Document copy failed", null) }
            }
        }
    }
}
