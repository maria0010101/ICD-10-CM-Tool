package tw.offline.icd.icd_dictionary

import android.os.StatFs
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "tw.offline.icd/storage")
            .setMethodCallHandler { call, result ->
                if (call.method == "availableBytes") {
                    try { result.success(StatFs(call.arguments as String).availableBytes) }
                    catch (e: Exception) { result.error("STORAGE", "Cannot inspect available storage", null) }
                } else { result.notImplemented() }
            }
    }
}
