package com.appswithlove.debug.ui.dev.recording

import android.app.Activity
import android.app.Application
import android.content.Context
import android.content.SharedPreferences
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Rect
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.HandlerThread
import android.os.Looper
import android.os.SystemClock
import android.util.Log
import android.view.MotionEvent
import android.view.PixelCopy
import android.view.Window
import android.view.WindowManager
import androidx.annotation.MainThread
import androidx.core.view.ViewCompat
import androidx.core.view.WindowInsetsCompat
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleOwner
import com.appswithlove.debug.R
import com.appswithlove.debug.api.DevScreenRecordingConfig
import com.appswithlove.debug.api.bridge.AwlDebugInternalApi
import com.appswithlove.debug.api.bridge.DevBridge
import com.appswithlove.debug.api.bridge.RecordingExport
import java.io.File
import java.lang.ref.WeakReference
import java.util.Locale
import java.util.concurrent.atomic.AtomicBoolean
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.withContext

/**
 * Records the resumed activity's window as JPEG frames, 3 per second, only while testers interact:
 * during a touch or with the keyboard open, for one second after that, plus two more frames. Nothing is
 * recorded while the panel is open or the app is in the background. The main thread only collects mask
 * areas and starts a `PixelCopy`; masking, touch circles, encoding and file access run on a worker thread,
 * and a frame is skipped while the previous one is still being encoded.
 */
internal object ScreenRecorder {
    val durationOptionsSeconds = listOf(30, 60, 300, 600)

    private const val FRAME_INTERVAL_MS = 333L
    private const val ACTIVITY_WINDOW_MS = 1_000L
    private const val TRAILING_FRAMES = 2
    private const val JPEG_QUALITY = 60
    private const val FRAMES_PER_SECOND = 3
    private const val MASK_PADDING_DP = 8f
    private const val TAG = "AwlDebugRecording"
    private const val PREFS = "awl_debug_recording"
    private const val KEY_ON = "is_on"
    private const val KEY_MAX_DURATION = "max_duration_seconds"

    private val _isOn = MutableStateFlow(false)
    /** The tester's "Screen recording" switch. */
    val isOn: StateFlow<Boolean> = _isOn.asStateFlow()

    private val _maxDurationSeconds = MutableStateFlow(DevScreenRecordingConfig().maxDurationSeconds)
    val maxDurationSeconds: StateFlow<Int> = _maxDurationSeconds.asStateFlow()

    private val _lastRecording = MutableStateFlow<RecordingInfo?>(null)
    /** Frames of the previous app run, available until the next start. */
    val lastRecording: StateFlow<RecordingInfo?> = _lastRecording.asStateFlow()

    private val _currentFrameCount = MutableStateFlow(0)
    val currentFrameCount: StateFlow<Int> = _currentFrameCount.asStateFlow()

    private val mainHandler = Handler(Looper.getMainLooper())
    private val touches = TouchTracker()
    private val isEncoding = AtomicBoolean(false)

    private var prefs: SharedPreferences? = null
    private lateinit var buffer: RecordingBuffer
    private lateinit var cacheRoot: File
    private lateinit var worker: Handler
    private var resumedActivity: WeakReference<Activity>? = null
    private var isPanelOpen = false
    private var isLoopRunning = false
    private var lastActivityAt = 0L
    private var trailingFrames = 0

    /** Reused between frames; only touched while [isEncoding] is held. */
    private var frameBitmap: Bitmap? = null

    private val tick = Runnable { onTick() }

    /** Starts the recorder once per process; later calls only attach to [activity]. */
    @MainThread
    fun install(activity: Activity, config: DevScreenRecordingConfig) {
        if (prefs == null) {
            val application = activity.application
            val preferences = application.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            prefs = preferences
            _isOn.value = preferences.getBoolean(KEY_ON, config.isOnByDefault)
            _maxDurationSeconds.value = preferences.getInt(KEY_MAX_DURATION, config.maxDurationSeconds).coerceAtLeast(1)
            cacheRoot = File(application.cacheDir, "awl-debug")
            buffer = RecordingBuffer(File(cacheRoot, "recording"))
            worker = Handler(HandlerThread("awl-debug-recording").apply { start() }.looper)
            worker.post {
                runCatching { buffer.rotate() }.onFailure { Log.w(TAG, "Could not prepare the recording folder", it) }
                _lastRecording.value = buffer.lastRecording()
                _currentFrameCount.value = 0
            }
            application.registerActivityLifecycleCallbacks(lifecycleCallbacks)
            registerFeedbackBridge()
        }
        val isResumed = (activity as? LifecycleOwner)?.lifecycle?.currentState?.isAtLeast(Lifecycle.State.RESUMED) ?: true
        if (isResumed) onActivityResumed(activity)
    }

    fun setOn(on: Boolean) {
        _isOn.value = on
        prefs?.edit()?.putBoolean(KEY_ON, on)?.apply()
        if (on) {
            resumedActivity?.get()?.let { wrapWindowCallback(it.window) }
            markActivity()
        } else {
            touches.clear()
        }
    }

    fun setMaxDurationSeconds(seconds: Int) {
        _maxDurationSeconds.value = seconds
        prefs?.edit()?.putInt(KEY_MAX_DURATION, seconds)?.apply()
        if (prefs != null) {
            worker.post {
                buffer.trim(maxFrames())
                _currentFrameCount.value = buffer.frameCount
            }
        }
    }

    /** Folder with the frames of this run, or of the previous run with [last]; `null` before the first start. */
    fun recordingDir(last: Boolean): File? = if (prefs == null) null else if (last) buffer.lastDir else buffer.currentDir

    /** Folder for exported files, inside the file provider's `cacheDir/awl-debug`; `null` before the first start. */
    fun exportDir(name: String): File? = if (prefs == null) null else File(cacheRoot, name)

    /** Lets feedback attach the recording (contract "Anhang video / frames / timeline"). */
    @OptIn(AwlDebugInternalApi::class)
    private fun registerFeedbackBridge() {
        DevBridge.hasRecording = { _currentFrameCount.value > 0 || _lastRecording.value != null }
        DevBridge.lastRecording = {
            withContext(Dispatchers.IO) {
                val source = if (_currentFrameCount.value > 0) buffer.currentDir else buffer.lastDir
                RecordingExporter.exportForFeedback(source, File(cacheRoot, "recording-feedback"))?.let {
                    RecordingExport(video = it.files?.video, frames = it.files?.frames, timeline = it.files?.timeline)
                }
            }
        }
    }

    /** Pauses recording while the panel covers the app. */
    fun setPanelOpen(open: Boolean) {
        isPanelOpen = open
        if (!open) markActivity()
    }

    private fun onActivityResumed(activity: Activity) {
        resumedActivity = WeakReference(activity)
        if (_isOn.value) wrapWindowCallback(activity.window)
        markActivity()
    }

    private val lifecycleCallbacks = object : Application.ActivityLifecycleCallbacks {
        override fun onActivityResumed(activity: Activity) = this@ScreenRecorder.onActivityResumed(activity)

        override fun onActivityPaused(activity: Activity) {
            if (resumedActivity?.get() === activity) resumedActivity = null
        }

        override fun onActivityCreated(activity: Activity, savedInstanceState: Bundle?) = Unit
        override fun onActivityStarted(activity: Activity) = Unit
        override fun onActivityStopped(activity: Activity) = Unit
        override fun onActivitySaveInstanceState(activity: Activity, outState: Bundle) = Unit
        override fun onActivityDestroyed(activity: Activity) = Unit
    }

    private fun wrapWindowCallback(window: Window) {
        val decor = window.decorView
        if (decor.getTag(R.id.awl_debug_recording_callback) == true) return
        val callback = window.callback ?: return
        window.callback = RecordingWindowCallback(callback, ::onTouch)
        decor.setTag(R.id.awl_debug_recording_callback, true)
    }

    private fun onTouch(event: MotionEvent) {
        if (!_isOn.value) return
        touches.onTouch(event, System.currentTimeMillis())
        markActivity()
    }

    private fun markActivity() {
        lastActivityAt = SystemClock.uptimeMillis()
        trailingFrames = 0
        if (!isLoopRunning && canCapture()) {
            isLoopRunning = true
            mainHandler.post(tick)
        }
    }

    private fun canCapture(): Boolean =
        prefs != null && _isOn.value && !isPanelOpen && resumedActivity?.get() != null

    private fun onTick() {
        val activity = resumedActivity?.get()
        if (activity == null || !canCapture()) {
            isLoopRunning = false
            return
        }
        val now = SystemClock.uptimeMillis()
        if (isKeyboardVisible(activity)) lastActivityAt = now
        val isIdle = now - lastActivityAt >= ACTIVITY_WINDOW_MS
        if (isIdle) trailingFrames++
        captureFrame(activity)
        if (isIdle && trailingFrames >= TRAILING_FRAMES) {
            isLoopRunning = false
        } else {
            mainHandler.postDelayed(tick, FRAME_INTERVAL_MS)
        }
    }

    /** Typing happens in the keyboard's own window, so an open keyboard counts as interaction. */
    private fun isKeyboardVisible(activity: Activity): Boolean =
        ViewCompat.getRootWindowInsets(activity.window.decorView)?.isVisible(WindowInsetsCompat.Type.ime()) == true

    private fun captureFrame(activity: Activity) {
        val window = activity.window
        val decor = window.decorView
        val width = decor.width
        val height = decor.height
        if (width <= 0 || height <= 0) return
        if (!isEncoding.compareAndSet(false, true)) return

        val masks = try {
            collectMaskRects(decor)
        } catch (e: RuntimeException) {
            // Without masks the frame could show a password: skip it.
            Log.w(TAG, "Could not find masked views", e)
            isEncoding.set(false)
            return
        }
        val bitmap = frameBitmap?.takeIf { it.width == width && it.height == height }
            ?: Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888).also {
                frameBitmap?.recycle()
                frameBitmap = it
            }
        val frame = PendingFrame(
            timeMillis = System.currentTimeMillis(),
            bitmap = bitmap,
            masks = masks,
            touches = touches.drain(),
            density = activity.resources.displayMetrics.density,
        )

        val isSecure = window.attributes.flags and WindowManager.LayoutParams.FLAG_SECURE != 0
        when {
            isSecure -> worker.post {
                bitmap.eraseColor(Color.BLACK)
                finishFrame(frame)
            }
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.O -> try {
                PixelCopy.request(window, bitmap, { result ->
                    if (result == PixelCopy.SUCCESS) finishFrame(frame) else isEncoding.set(false)
                }, worker)
            } catch (e: IllegalArgumentException) {
                // The window has no surface yet.
                isEncoding.set(false)
            }
            else -> try {
                decor.draw(Canvas(bitmap))
                worker.post { finishFrame(frame) }
            } catch (e: RuntimeException) {
                Log.w(TAG, "Could not draw the window", e)
                isEncoding.set(false)
            }
        }
    }

    /** Worker thread: burns in masks and touches, then writes the frame. */
    private fun finishFrame(frame: PendingFrame) {
        try {
            frame.draw()
            buffer.writeFrame(frame.timeMillis, frame.bitmap, JPEG_QUALITY)
            buffer.appendEvents(frame.eventLines())
            buffer.trim(maxFrames())
            _currentFrameCount.value = buffer.frameCount
        } catch (e: Exception) {
            Log.w(TAG, "Could not save a frame", e)
        } finally {
            isEncoding.set(false)
        }
    }

    private fun maxFrames(): Int = _maxDurationSeconds.value * FRAMES_PER_SECOND

    private class PendingFrame(
        val timeMillis: Long,
        val bitmap: Bitmap,
        val masks: List<Rect>,
        val touches: List<TouchPoint>,
        val density: Float,
    ) {
        fun draw() {
            val canvas = Canvas(bitmap)
            touches.forEach { touch ->
                val radius = (if (touch.phase == TouchPhase.Moved) 15f else 20f) * density
                canvas.drawCircle(touch.x, touch.y, radius, touchFillPaint)
                when (touch.phase) {
                    TouchPhase.Began -> canvas.drawCircle(touch.x, touch.y, radius, strokePaint(BEGAN_COLOR))
                    TouchPhase.Ended -> canvas.drawCircle(touch.x, touch.y, radius, strokePaint(ENDED_COLOR))
                    TouchPhase.Moved -> Unit
                }
            }
            // Masks last, so nothing is drawn over them.
            val padding = (MASK_PADDING_DP * density).toInt()
            masks.forEach { mask ->
                canvas.drawRect(Rect(mask).apply { inset(-padding, -padding) }, maskPaint)
            }
        }

        fun eventLines(): List<String> = touches
            .filter { it.phase != TouchPhase.Moved }
            .map { touch ->
                String.format(
                    Locale.ROOT,
                    "%d\t%s\t%.4f\t%.4f",
                    touch.timeMillis,
                    if (touch.phase == TouchPhase.Began) "began" else "ended",
                    (touch.x / bitmap.width).coerceIn(0f, 1f),
                    (touch.y / bitmap.height).coerceIn(0f, 1f),
                )
            }

        private fun strokePaint(color: Int) = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.STROKE
            strokeWidth = 3f * density
            this.color = color
        }
    }

    private const val BEGAN_COLOR = 0xFF4CAF50.toInt()
    private const val ENDED_COLOR = 0xFFE53935.toInt()
    private val maskPaint = Paint().apply { color = Color.BLACK }
    private val touchFillPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = 0x88FFFFFF.toInt() }
}
