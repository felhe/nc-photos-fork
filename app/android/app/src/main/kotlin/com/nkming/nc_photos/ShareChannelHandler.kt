package com.nkming.nc_photos

import android.app.Activity
import android.content.ClipData
import android.content.Intent
import android.net.Uri
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class ShareChannelHandler(activity: Activity) :
	MethodChannel.MethodCallHandler {
	companion object {
		const val CHANNEL = "com.nkming.nc_photos/share"
	}

	override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
		when (call.method) {
			"shareItems" -> {
				try {
					shareItems(
						call.argument("fileUris")!!,
						call.argument("mimeTypes")!!,
						result
					)
				} catch (e: Throwable) {
					result.error("systemException", e.toString(), null)
				}
			}
			"shareText" -> {
				try {
					shareText(
						call.argument("text")!!,
						call.argument("mimeType"),
						result
					)
				} catch (e: Throwable) {
					result.error("systemException", e.toString(), null)
				}
			}
			else -> {
				result.notImplemented()
			}
		}
	}

	private fun shareItems(
		fileUris: List<String>,
		mimeTypes: List<String?>,
		result: MethodChannel.Result
	) {
		assert(fileUris.isNotEmpty())
		assert(fileUris.size == mimeTypes.size)
		val uris = fileUris.map { Uri.parse(it) }

		val shareIntent = if (uris.size == 1) Intent().apply {
			action = Intent.ACTION_SEND
			putExtra(Intent.EXTRA_STREAM, uris[0])
			// setting clipdata is needed for FLAG_GRANT_READ_URI_PERMISSION to
			// work, see: https://developer.android.com/reference/android/content/Intent#ACTION_SEND
			clipData =
				ClipData.newUri(_context.contentResolver, "Share", uris[0])
			type = mimeTypes[0] ?: "*/*"
			addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
			addFlags(Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
		} else Intent().apply {
			action = Intent.ACTION_SEND_MULTIPLE
			putParcelableArrayListExtra(Intent.EXTRA_STREAM, ArrayList(uris))
			clipData =
				ClipData.newUri(_context.contentResolver, "Share", uris[0])
					.apply {
						for (uri in uris.subList(1, uris.size)) {
							addItem(ClipData.Item(uri))
						}
					}
			type = if (mimeTypes.all {
					it?.startsWith("image/") == true
				}) "image/*" else "*/*"
			addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
			addFlags(Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
		}
		val shareChooser = Intent.createChooser(
			shareIntent, _context.getString(
				R.string.download_successful_notification_action_share_chooser
			)
		)
		_context.startActivity(shareChooser)
		result.success(null)
	}

	private fun shareText(
		text: String, mimeType: String?, result: MethodChannel.Result
	) {
		val shareIntent = Intent().apply {
			action = Intent.ACTION_SEND
			type = mimeType ?: "text/plain"
			putExtra(Intent.EXTRA_TEXT, text)
		}
		val shareChooser = Intent.createChooser(
			shareIntent, _context.getString(
				R.string.download_successful_notification_action_share_chooser
			)
		)
		_context.startActivity(shareChooser)
		result.success(null)
	}

	private val _activity = activity
	private val _context get() = _activity
}
