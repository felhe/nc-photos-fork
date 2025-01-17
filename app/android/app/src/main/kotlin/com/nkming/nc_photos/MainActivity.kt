package com.nkming.nc_photos

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import androidx.annotation.NonNull
import com.google.android.gms.maps.MapsInitializer
import com.google.android.gms.maps.OnMapsSdkInitializedCallback
import com.nkming.nc_photos.plugin.*
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.net.URLEncoder

class MainActivity : FlutterActivity(), MethodChannel.MethodCallHandler,
	OnMapsSdkInitializedCallback {
	companion object {
		private const val METHOD_CHANNEL = "com.nkming.nc_photos/activity"

		private const val TAG = "MainActivity"
	}

	override fun onCreate(savedInstanceState: Bundle?) {
		super.onCreate(savedInstanceState)
		if (intent.action == NcPhotosPlugin.ACTION_SHOW_IMAGE_PROCESSOR_RESULT) {
			val route = getRouteFromImageProcessorResult(intent) ?: return
			logI(TAG, "Initial route: $route")
			_initialRoute = route
		}
		MapsInitializer.initialize(
			applicationContext, MapsInitializer.Renderer.LATEST, this
		)
	}

	override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
		super.configureFlutterEngine(flutterEngine)
		MethodChannel(
			flutterEngine.dartExecutor.binaryMessenger,
			SelfSignedCertChannelHandler.CHANNEL
		).setMethodCallHandler(
			SelfSignedCertChannelHandler(this)
		)
		MethodChannel(
			flutterEngine.dartExecutor.binaryMessenger,
			ShareChannelHandler.CHANNEL
		).setMethodCallHandler(
			ShareChannelHandler(this)
		)
		MethodChannel(
			flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL
		).setMethodCallHandler(this)

		EventChannel(
			flutterEngine.dartExecutor.binaryMessenger,
			DownloadEventCancelChannelHandler.CHANNEL
		).setStreamHandler(
			DownloadEventCancelChannelHandler(this)
		)
	}

	override fun onNewIntent(intent: Intent) {
		if (intent.action == NcPhotosPlugin.ACTION_SHOW_IMAGE_PROCESSOR_RESULT) {
			val route = getRouteFromImageProcessorResult(intent) ?: return
			logI(TAG, "Navigate to route: $route")
			flutterEngine?.navigationChannel?.pushRoute(route)
		} else {
			super.onNewIntent(intent)
		}
	}

	override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
		when (call.method) {
			"consumeInitialRoute" -> {
				result.success(_initialRoute)
				_initialRoute = null
			}

			"isNewGMapsRenderer" -> {
				result.success(_isNewGMapsRenderer)
			}

			else -> result.notImplemented()
		}
	}

	override fun onMapsSdkInitialized(renderer: MapsInitializer.Renderer) {
		_isNewGMapsRenderer = when (renderer) {
			MapsInitializer.Renderer.LATEST -> {
				logD(TAG, "Using new map renderer")
				true
			}
			MapsInitializer.Renderer.LEGACY -> {
				logD(TAG, "Using legacy map renderer")
				false
			}
		}
	}

	private fun getRouteFromImageProcessorResult(intent: Intent): String? {
		val resultUri =
			intent.getParcelableExtra<Uri>(
				NcPhotosPlugin.EXTRA_IMAGE_RESULT_URI
			)
		if (resultUri == null) {
			logE(TAG, "Image result uri == null")
			return null
		}
		return if (resultUri.scheme?.startsWith("http") == true) {
			// remote uri
			val encodedUrl = URLEncoder.encode(resultUri.toString(), "utf-8")
			"/result-viewer?url=$encodedUrl"
		} else {
			val filename = UriUtil.resolveFilename(this, resultUri)?.let {
				URLEncoder.encode(it, Charsets.UTF_8.toString())
			}
			StringBuilder().apply {
				append("/enhanced-photo-browser?")
				if (filename != null) append("filename=$filename")
			}.toString()
		}
	}

	private var _initialRoute: String? = null
	private var _isNewGMapsRenderer = false
}
