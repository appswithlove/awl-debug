package com.appswithlove.debug.ui.dev.sheet

import android.app.Activity
import android.content.ClipData
import android.content.res.Configuration
import android.util.Log
import androidx.compose.foundation.clickable
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInHorizontally
import androidx.compose.animation.slideOutHorizontally
import androidx.activity.BackEventCompat
import androidx.activity.compose.PredictiveBackHandler
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.BottomSheetDefaults
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Text
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.SideEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.ClipEntry
import androidx.compose.ui.platform.LocalClipboard
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import androidx.compose.ui.window.DialogWindowProvider
import androidx.core.view.WindowCompat
import com.appswithlove.debug.R
import com.appswithlove.debug.ui.component.icons.TablerIcons
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.lifecycle.viewmodel.initializer
import androidx.lifecycle.viewmodel.viewModelFactory
import com.appswithlove.debug.api.DevConfig
import com.appswithlove.debug.api.DevModulesConfig
import com.appswithlove.debug.domain.storage.DevStore
import com.appswithlove.debug.ui.component.DevSwitch
import com.appswithlove.debug.ui.dev.sheet.modules.performance.PerformanceMonitor
import com.appswithlove.debug.ui.dev.sheet.modules.performance.PerformanceOverlayHost
import com.appswithlove.debug.ui.dev.sheet.modules.AppInfoModule
import com.appswithlove.debug.ui.dev.sheet.modules.FcmPushTokenModule
import com.appswithlove.debug.ui.dev.sheet.modules.LogsModule
import com.appswithlove.debug.ui.dev.sheet.modules.performance.PerformanceModule
import com.appswithlove.debug.ui.dev.sheet.modules.permissions.PermissionsModule
import com.appswithlove.debug.ui.dev.sheet.modules.accessibility.AccessibilityModule
import com.appswithlove.debug.ui.dev.sheet.modules.accessibility.AccessibilityOverride
import com.appswithlove.debug.ui.dev.sheet.modules.accessibility.AccessibilitySettings
import com.appswithlove.debug.ui.dev.sheet.modules.accessibility.applyAppNightMode
import com.appswithlove.debug.ui.dev.sheet.modules.TestCrashesModule
import com.appswithlove.debug.ui.dev.sheet.modules.deeplinks.DeeplinkDetailModule
import com.appswithlove.debug.ui.dev.sheet.modules.deeplinks.DeeplinkDispatcher
import com.appswithlove.debug.ui.dev.sheet.modules.deeplinks.DeeplinkScheduler
import com.appswithlove.debug.ui.dev.sheet.modules.ClearAppDataModule
import com.appswithlove.debug.ui.dev.sheet.modules.clearAppData
import com.appswithlove.debug.ui.dev.sheet.modules.VersionOverlay
import com.appswithlove.debug.ui.dev.sheet.modules.deeplinks.DeeplinksModule
import com.appswithlove.debug.api.DeeplinkItem
import androidx.compose.runtime.DisposableEffect
import kotlinx.coroutines.delay
import com.appswithlove.debug.ui.dev.sheet.modules.session.SessionDetailModule
import com.appswithlove.debug.ui.dev.sheet.modules.session.SessionManager
import com.appswithlove.debug.ui.dev.sheet.modules.session.SessionModule
import com.appswithlove.debug.api.DevTrigger
import com.appswithlove.debug.api.extension.AwlDebugExtensions
import com.appswithlove.debug.api.extension.DevExtensionSection
import com.appswithlove.debug.ui.component.ScreenshotTrigger
import com.appswithlove.debug.ui.component.ShakeTrigger
import com.appswithlove.debug.ui.component.devTriggerGestures
import com.appswithlove.debug.ui.component.findActivity
import com.appswithlove.debug.ui.dev.log.LogCollector
import com.appswithlove.debug.ui.dev.network.NetworkCollector
import com.appswithlove.debug.ui.dev.network.NetworkViewModel
import com.appswithlove.debug.ui.dev.network.exportTimestamp
import com.appswithlove.debug.ui.dev.network.networkExportText
import com.appswithlove.debug.ui.dev.network.toShareText
import com.appswithlove.debug.ui.dev.sheet.modules.network.NetworkDetailModule
import com.appswithlove.debug.ui.dev.sheet.modules.network.NetworkFiltersModule
import com.appswithlove.debug.ui.dev.sheet.modules.network.NetworkModule
import com.appswithlove.debug.ui.component.shareTextFile
import com.appswithlove.debug.ui.dev.log.LogHistory
import com.appswithlove.debug.ui.dev.recording.ScreenRecorder
import com.appswithlove.debug.ui.dev.recording.ScreenRecordingEffect
import com.appswithlove.debug.ui.dev.recording.ScreenRecordingModule
import com.appswithlove.debug.ui.theme.AppTheme
import com.appswithlove.debug.ui.theme.DevTheme
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.launch

/**
 * A composable that provides a development sheet that opens with the configured [triggers].
 *
 * @param modifier Modifier to be applied to the `DevSheet`. Note that this only modifies the
 * `DevSheet` itself, not the content.
 * @param devConfig The [DevConfig] to be displayed in the app info module. Map your app's
 * `BuildConfig` to this to show app info on the sheet.
 * @param modulesConfig A [com.appswithlove.debug.api.DevModulesConfig] that controls which built-in modules are shown in the
 * `DevSheet`. All modules are enabled by default.
 * @param triggers The gestures that open the `DevSheet`. Defaults to [DevTrigger.ThreeFingerTap].
 * A trigger never closes an open sheet. Triggers that a registered extension section claims are left to it.
 * @param customModules A composable lambda that allows you to add your own custom modules to the
 * `DevSheet`.
 * @param isAlwaysActive If set to `true`, the [triggers] work even while the dev tool is
 * deactivated (see `DevSettings`). Defaults to `false`.
 * @param swipeToDismiss If set to `true`, the `DevSheet` can be dismissed by swiping it down.
 * Defaults to `false`.
 * @param inheritHostTheme If set to `true`, the drawer adopts the host app's full [MaterialTheme]
 * (color scheme, typography and shapes) instead of neutral Material defaults. Requires `DevSheet`
 * to be called from within the app's `MaterialTheme`. Defaults to `false`. Note: the drawer's
 * typography and shapes already follow the ambient theme regardless of this flag; it additionally
 * inherits the host color scheme.
 * @param content The content of your screen. The `DevSheet` will be displayed on top of this
 * content.
 */
@Composable
fun DevSheet(
    modifier: Modifier = Modifier,
    devConfig: DevConfig? = null,
    modulesConfig: DevModulesConfig = DevModulesConfig(),
    triggers: Set<DevTrigger> = setOf(DevTrigger.ThreeFingerTap),
    customModules: @Composable ColumnScope.() -> Unit = {},
    isAlwaysActive: Boolean = false,
    swipeToDismiss: Boolean = false,
    inheritHostTheme: Boolean = false,
    content: @Composable () -> Unit,
) {
    DevSheet(
        viewModel = rememberDevViewModel(),
        logHistory = LogCollector.logHistory,
        modifier = modifier,
        devConfig = devConfig,
        modulesConfig = modulesConfig,
        triggers = triggers,
        customModules = customModules,
        isAlwaysActive = isAlwaysActive,
        swipeToDismiss = swipeToDismiss,
        inheritHostTheme = inheritHostTheme,
        content = content,
    )
}

/** [DevSheet] with an injectable [viewModel] and [logHistory]; kept internal so the public API matches `debug-no-op`. */
@Composable
internal fun DevSheet(
    viewModel: DevViewModel,
    logHistory: LogHistory,
    modifier: Modifier = Modifier,
    devConfig: DevConfig? = null,
    modulesConfig: DevModulesConfig = DevModulesConfig(),
    triggers: Set<DevTrigger> = setOf(DevTrigger.ThreeFingerTap),
    customModules: @Composable ColumnScope.() -> Unit = {},
    isAlwaysActive: Boolean = false,
    swipeToDismiss: Boolean = false,
    inheritHostTheme: Boolean = false,
    content: @Composable () -> Unit,
) {
    val hostColorScheme = MaterialTheme.colorScheme
    val state = viewModel.state.collectAsStateWithLifecycle()
    val density = LocalDensity.current
    val context = LocalContext.current
    // Shared by the Performance page and the overlay, which lives outside the sheet.
    val performanceMonitor = remember {
        if (modulesConfig.showPerformanceModule) PerformanceMonitor(context.applicationContext) else null
    }
    val devStore = remember { DevStore(context.applicationContext) }
    val overlayScope = rememberCoroutineScope()
    var openPerformanceRequests by remember { mutableIntStateOf(0) }
    val accessibility by devStore.accessibility.collectAsStateWithLifecycle(initialValue = AccessibilitySettings())
    val accessibilityScope = rememberCoroutineScope()

    LaunchedEffect(isAlwaysActive) {
        viewModel.setIsAlwaysActive(isAlwaysActive)
    }

    val savedVersionOverlay by devStore.versionOverlayVisible.collectAsStateWithLifecycle(initialValue = null)
    val showVersionOverlay = savedVersionOverlay ?: modulesConfig.showVersionOverlay
    if (modulesConfig.showScreenRecordingModule) {
        ScreenRecordingEffect(config = modulesConfig.screenRecording, isPanelOpen = state.value.isShown)
    }
    val isRecording = modulesConfig.showScreenRecordingModule &&
        ScreenRecorder.isOn.collectAsStateWithLifecycle().value

    DisposableEffect(modulesConfig.deeplinkHandler) {
        DeeplinkDispatcher.setHandler(modulesConfig.deeplinkHandler)
        onDispose { DeeplinkDispatcher.setHandler(null) }
    }

    val extensionSections by AwlDebugExtensions.sections.collectAsStateWithLifecycle()
    val panelTriggers = remember(triggers, extensionSections) { panelTriggers(triggers, extensionSections.claimedTriggers()) }
    val canTrigger = state.value.isActive || state.value.isAlwaysActive
    val openFromTrigger = { viewModel.submitAction(DevAction.ShowDevSheet(show = true)) }
    if (canTrigger && DevTrigger.Shake in panelTriggers) ShakeTrigger(onShake = openFromTrigger)
    if (canTrigger && DevTrigger.Screenshot in panelTriggers) ScreenshotTrigger(onScreenshot = openFromTrigger)

    Box(
        modifier = modifier
            .fillMaxSize()
            .devTriggerGestures(
                threeFingerTap = canTrigger && DevTrigger.ThreeFingerTap in panelTriggers,
                tripleTap = canTrigger && DevTrigger.TripleTap in panelTriggers,
                onTrigger = openFromTrigger,
            )
    ) {
        AccessibilityOverride(settings = accessibility, content = content)

        if ((showVersionOverlay && devConfig != null) || isRecording) {
            VersionOverlay(devConfig = devConfig.takeIf { showVersionOverlay }, isRecording = isRecording)
        }

        DevTheme(
            colorScheme = if (inheritHostTheme) hostColorScheme else null,
        ) {
            performanceMonitor?.let { monitor ->
                PerformanceOverlayHost(
                    monitor = monitor,
                    devStore = devStore,
                    onLongPress = {
                        viewModel.submitAction(DevAction.ShowDevSheet(show = true))
                        openPerformanceRequests++
                    },
                )
            }
            DevSheetContent(
                modifier = modifier,
                state = state.value,
                performanceMonitor = performanceMonitor,
                openPerformanceRequests = openPerformanceRequests,
                onPerformanceOverlayChanged = { visible ->
                    overlayScope.launch { devStore.setPerformanceOverlayVisible(visible) }
                },
                modulesConfig = modulesConfig,
                devConfig = devConfig,
                showVersionOverlay = showVersionOverlay,
                onShowVersionOverlayChanged = { visible ->
                    overlayScope.launch { devStore.setVersionOverlayVisible(visible) }
                },
                logHistory = logHistory,
                actioner = { action -> viewModel.submitAction(action) },
                customModules = customModules,
                extensionSections = extensionSections,
                swipeToDismiss = swipeToDismiss,
                onTrackLogsChanged = { viewModel.setTrackLogs(it) },
                onMaxLogsChanged = { viewModel.setMaxLogSize(it) },
                systemFontScale = density.fontScale,
                accessibility = accessibility,
                onAccessibilityChanged = { settings ->
                    val appearanceChanged = settings.appearance != accessibility.appearance
                    accessibilityScope.launch {
                        devStore.setAccessibility(settings)
                        // After saving: a new night mode recreates the activity and cancels this scope.
                        if (appearanceChanged) applyAppNightMode(context, settings.appearance)
                    }
                },
            )
        }
    }
}

@Composable
private fun DevSheetContent(
    modifier: Modifier = Modifier,
    state: DevSheetState,
    performanceMonitor: PerformanceMonitor? = null,
    openPerformanceRequests: Int = 0,
    onPerformanceOverlayChanged: (Boolean) -> Unit = {},
    logHistory: LogHistory,
    devConfig: DevConfig? = null,
    showVersionOverlay: Boolean = false,
    onShowVersionOverlayChanged: ((Boolean) -> Unit)? = null,
    modulesConfig: DevModulesConfig = DevModulesConfig(),
    actioner: (DevAction) -> Unit,
    customModules: @Composable ColumnScope.() -> Unit = {},
    extensionSections: List<DevExtensionSection> = emptyList(),
    swipeToDismiss: Boolean = false,
    onTrackLogsChanged: (Boolean) -> Unit,
    onMaxLogsChanged: (Int) -> Unit,
    systemFontScale: Float = 1f,
    accessibility: AccessibilitySettings = AccessibilitySettings(),
    onAccessibilityChanged: (AccessibilitySettings) -> Unit = {},
) {
    val context = LocalContext.current
    val coroutineScope = rememberCoroutineScope()
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    val clipboard = LocalClipboard.current
    val sessionManager = remember {
        // Also without providers: the module page then shows how to add one.
        if (modulesConfig.showSessionModule) {
            SessionManager(modulesConfig.sessionProviders)
        } else {
            null
        }
    }
    var currentPage by rememberSaveable { mutableStateOf(DevSheetPage.Home) }
    // Kept outside the page transition, so returning from a module restores the position on the home page.
    val homeScrollState = rememberScrollState()
    LaunchedEffect(openPerformanceRequests) {
        if (openPerformanceRequests > 0 && performanceMonitor != null) currentPage = DevSheetPage.Performance
    }
    val networkViewModel = rememberNetworkViewModel()
    val hasNetworkInterceptor by NetworkCollector.store.hasInterceptor.collectAsStateWithLifecycle()
    val showNetworkModule = modulesConfig.showNetworkModule && hasNetworkInterceptor
    var selectedNetworkEntryId by rememberSaveable { mutableStateOf<Long?>(null) }
    val devStore = remember { DevStore(context.applicationContext) }
    val savedDeeplinks by devStore.savedDeeplinks.collectAsStateWithLifecycle(initialValue = emptyList())
    var selectedDeeplink by rememberSaveable { mutableStateOf<Pair<String, String>?>(null) }

    fun copyToClipboard(text: String) {
        coroutineScope.launch {
            clipboard.setClipEntry(ClipEntry(ClipData.newPlainText("AWL Debug", text)))
        }
    }

    fun shareText(fileName: String, text: String, chooserTitle: String) {
        coroutineScope.launch {
            try {
                shareTextFile(context, fileName, text, chooserTitle)
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
    }

    /** Hides the sheet, then runs [then]. */
    fun hideBottomSheet(then: () -> Unit = {}) {
        coroutineScope.launch {
            sheetState.hide()
        }.invokeOnCompletion {
            if (!sheetState.isVisible) {
                actioner(DevAction.ShowDevSheet(show = false))
            }
            then()
        }
    }

    fun fireDeeplink(url: String): Boolean {
        val fired = DeeplinkDispatcher.fire(context, url)
        if (fired) hideBottomSheet()
        return fired
    }

    LaunchedEffect(state.isShown) {
        if (state.isShown) sheetState.show() else sheetState.hide()
    }

    if (state.isShown || sheetState.isVisible) {
        ModalBottomSheet(
            modifier = Modifier.statusBarsPadding(),
            onDismissRequest = { hideBottomSheet() },
            containerColor = AppTheme.colors.background,
            // Text without an explicit color (e.g. a log tag) would otherwise be black on the dark sheet when the
            // host theme is inherited, because the sheet color is not part of the host color scheme.
            contentColor = MaterialTheme.colorScheme.onSurface,
            sheetState = sheetState,
            sheetGesturesEnabled = swipeToDismiss,
            dragHandle = if (swipeToDismiss) {
                { BottomSheetDefaults.DragHandle() }
            } else {
                null
            },
        ) {
            val view = LocalView.current
            val darkTheme = isSystemInDarkTheme()

            // Fixes status bar colors
            SideEffect {
                val window = (view.parent as? DialogWindowProvider)?.window
                    ?: (view.context as? Activity)?.window

                window?.let { w ->
                    WindowCompat.getInsetsController(w, view).isAppearanceLightStatusBars =
                        !darkTheme
                }
            }

            val backProgress = remember { Animatable(0f) }
            PredictiveBackHandler(enabled = currentPage != DevSheetPage.Home) { progress: Flow<BackEventCompat> ->
                try {
                    progress.collect { event -> backProgress.snapTo(event.progress) }
                    currentPage = currentPage.parent
                    backProgress.snapTo(0f)
                } catch (e: CancellationException) {
                    backProgress.animateTo(0f)
                }
            }

            AnimatedContent(
                targetState = currentPage,
                transitionSpec = {
                    val direction = if (targetState != DevSheetPage.Home) 1 else -1
                    (fadeIn(tween(220)) + slideInHorizontally(tween(220)) { (it / 6) * direction }) togetherWith
                        (fadeOut(tween(180)) + slideOutHorizontally(tween(180)) { (-it / 6) * direction })
                },
                label = "DevSheetPage",
            ) { page ->
                val gestureModifier = if (page != DevSheetPage.Home) {
                    Modifier.graphicsLayer {
                        val p = backProgress.value
                        translationX = p * size.width * 0.18f
                        scaleX = 1f - p * 0.08f
                        scaleY = 1f - p * 0.08f
                        alpha = 1f - p * 0.2f
                    }
                } else {
                    Modifier
                }
                Box(modifier = gestureModifier) {
                when (page) {
                    DevSheetPage.Logs -> {
                    val trackLogs by logHistory.trackLogs.collectAsStateWithLifecycle()
                    ModuleDetail(swipeToDismiss = swipeToDismiss) {
                        ModuleDetailNavBar(
                            title = "Logs",
                            onBack = { currentPage = DevSheetPage.Home },
                            onClose = { hideBottomSheet() },
                            actions = {
                                NavBarSwitch(label = "Record logs", checked = trackLogs, onCheckedChange = onTrackLogsChanged)
                            },
                        )

                        LogsModule(
                            modifier = Modifier.weight(1f),
                            logHistory = logHistory,
                            onEntryLongPress = {
                                coroutineScope.launch {
                                    clipboard.setClipEntry(
                                        ClipEntry(ClipData.newPlainText(it, it))
                                    )
                                }
                            },
                            onMaxLogsChanged = onMaxLogsChanged,
                        )
                    }
                }

                    DevSheetPage.Network -> {
                    val networkState by networkViewModel.state.collectAsStateWithLifecycle()
                    ModuleDetail(swipeToDismiss = swipeToDismiss) {
                        ModuleDetailNavBar(
                            title = "Network",
                            onBack = { currentPage = DevSheetPage.Home },
                            onClose = { hideBottomSheet() },
                            actions = {
                                NavBarSwitch(
                                    label = "Track network logs",
                                    checked = networkState.isTracking,
                                    onCheckedChange = { networkViewModel.setTracking(it) },
                                )
                            },
                        )

                        NetworkModule(
                            modifier = Modifier.weight(1f),
                            state = networkState,
                            onSearch = networkViewModel::search,
                            onEntryClick = { entry ->
                                selectedNetworkEntryId = entry.id
                                currentPage = DevSheetPage.NetworkDetail
                            },
                            onShowFilters = { currentPage = DevSheetPage.NetworkFilters },
                            onSortChanged = networkViewModel::setSort,
                            onClear = networkViewModel::clear,
                            onExport = {
                                val now = System.currentTimeMillis()
                                shareText(
                                    fileName = "awl-debug-network-${exportTimestamp(now)}.txt",
                                    text = networkExportText(networkState.entries, networkState.filter, devConfig, now),
                                    chooserTitle = "Export network logs",
                                )
                            },
                            onMaxSizeChanged = networkViewModel::setMaxSize,
                        )
                    }
                }

                    DevSheetPage.NetworkFilters -> {
                    val networkState by networkViewModel.state.collectAsStateWithLifecycle()
                    ModuleDetail(swipeToDismiss = swipeToDismiss) {
                        ModuleDetailNavBar(
                            title = "Filters",
                            onBack = { currentPage = DevSheetPage.Network },
                            onClose = { hideBottomSheet() },
                        )

                        NetworkFiltersModule(
                            modifier = Modifier.weight(1f),
                            state = networkState,
                            onExcludedMethodsChanged = networkViewModel::setExcludedMethods,
                            onExcludedStatusClassesChanged = networkViewModel::setExcludedStatusClasses,
                            onExcludedHostsChanged = networkViewModel::setExcludedHosts,
                            onDone = { currentPage = DevSheetPage.Network },
                        )
                    }
                }

                    DevSheetPage.NetworkDetail -> {
                    val entry = selectedNetworkEntryId?.let(networkViewModel::entry)
                    ModuleDetail(swipeToDismiss = swipeToDismiss) {
                        ModuleDetailNavBar(
                            title = entry?.let { "${it.method} ${it.path}" } ?: "Network",
                            onBack = { currentPage = DevSheetPage.Network },
                            onClose = { hideBottomSheet() },
                        )

                        if (entry == null) {
                            Text(text = "No requests yet", color = MaterialTheme.colorScheme.onSurface)
                        } else {
                            NetworkDetailModule(
                                modifier = Modifier.weight(1f),
                                entry = entry,
                                onCopy = ::copyToClipboard,
                                onShare = {
                                    shareText(
                                        fileName = "awl-debug-request-${exportTimestamp(entry.startedAtMillis)}.txt",
                                        text = entry.toShareText(),
                                        chooserTitle = "Share",
                                    )
                                },
                            )
                        }
                    }
                }

                    DevSheetPage.Performance -> performanceMonitor?.let { monitor ->
                    val isTracking by monitor.isTracking.collectAsStateWithLifecycle()
                    ModuleDetail(swipeToDismiss = swipeToDismiss) {
                        ModuleDetailNavBar(
                            title = "Performance",
                            onBack = { currentPage = DevSheetPage.Home },
                            onClose = { hideBottomSheet() },
                            actions = {
                                NavBarSwitch(
                                    label = "Measure performance",
                                    checked = isTracking,
                                    onCheckedChange = { monitor.setTracking(it) },
                                )
                            },
                        )

                        PerformanceModule(
                            modifier = Modifier.weight(1f),
                            performanceMonitor = monitor,
                            onOverlayVisibleChanged = onPerformanceOverlayChanged,
                        )
                    }
                }

                    DevSheetPage.Permissions -> {
                    ModuleDetail(swipeToDismiss = swipeToDismiss) {
                        ModuleDetailNavBar(
                            title = "Permissions",
                            onBack = { currentPage = DevSheetPage.Home },
                            onClose = { hideBottomSheet() },
                        )

                        PermissionsModule(modifier = Modifier.weight(1f))
                    }
                }

                    DevSheetPage.Accessibility -> {
                    ModuleDetail(swipeToDismiss = swipeToDismiss) {
                        ModuleDetailNavBar(
                            title = "Accessibility",
                            onBack = { currentPage = DevSheetPage.Home },
                            onClose = { hideBottomSheet() },
                        )

                        AccessibilityModule(
                            modifier = Modifier.weight(1f),
                            systemFontScale = systemFontScale,
                            settings = accessibility,
                            onSettingsChanged = onAccessibilityChanged,
                        )
                    }
                }

                    DevSheetPage.Deeplinks -> {
                    ModuleDetail(swipeToDismiss = swipeToDismiss) {
                        ModuleDetailNavBar(
                            title = "Deeplinks",
                            onBack = { currentPage = DevSheetPage.Home },
                            onClose = { hideBottomSheet() },
                        )

                        DeeplinksModule(
                            modifier = Modifier.weight(1f),
                            predefined = modulesConfig.deeplinks,
                            saved = savedDeeplinks,
                            onFire = ::fireDeeplink,
                            onSave = { item ->
                                coroutineScope.launch {
                                    devStore.setSavedDeeplinks(savedDeeplinks.filterNot { it.url == item.url } + item)
                                }
                            },
                            onDelete = { item ->
                                coroutineScope.launch { devStore.setSavedDeeplinks(savedDeeplinks - item) }
                            },
                            onOpen = { item ->
                                selectedDeeplink = item.label to item.url
                                currentPage = DevSheetPage.DeeplinkDetail
                            },
                        )
                    }
                }

                    DevSheetPage.DeeplinkDetail -> {
                    val item = selectedDeeplink?.let { (label, url) -> DeeplinkItem(label, url) }
                    ModuleDetail(swipeToDismiss = swipeToDismiss) {
                        ModuleDetailNavBar(
                            title = "Deeplinks",
                            onBack = { currentPage = DevSheetPage.Deeplinks },
                            onClose = { hideBottomSheet() },
                        )
                        if (item != null) {
                            DeeplinkDetailModule(
                                modifier = Modifier.weight(1f),
                                item = item,
                                onFire = { fireDeeplink(item.url) },
                                onSchedule = { delay ->
                                    DeeplinkScheduler.schedule(
                                        context = context,
                                        item = item,
                                        delaySeconds = delay,
                                        usesHandler = modulesConfig.deeplinkHandler != null,
                                    )
                                },
                                onScheduled = {
                                    coroutineScope.launch {
                                        // Leave time to read the confirmation, then send the app to the background.
                                        delay(1_500)
                                        context.findActivity()?.moveTaskToBack(true)
                                    }
                                },
                            )
                        }
                    }
                }

                    DevSheetPage.Session -> sessionManager?.let { manager ->
                    ModuleDetail(swipeToDismiss = swipeToDismiss) {
                        ModuleDetailNavBar(
                            title = "Session",
                            onBack = { currentPage = DevSheetPage.Home },
                            onClose = { hideBottomSheet() },
                        )

                        SessionDetailModule(
                            modifier = Modifier.weight(1f),
                            sessionManager = manager,
                        )
                    }
                }

                    DevSheetPage.ScreenRecording -> {
                    ModuleDetail(swipeToDismiss = swipeToDismiss) {
                        ModuleDetailNavBar(
                            title = "Screen Recording",
                            onBack = { currentPage = DevSheetPage.Home },
                            onClose = { hideBottomSheet() },
                        )

                        ScreenRecordingModule(modifier = Modifier.weight(1f))
                    }
                }

                    DevSheetPage.ClearAppData -> {
                    ModuleDetail(swipeToDismiss = swipeToDismiss) {
                        ModuleDetailNavBar(
                            title = "Clear App Data",
                            onBack = { currentPage = DevSheetPage.Home },
                            onClose = { hideBottomSheet() },
                        )

                        ClearAppDataModule(onClear = { clearAppData(context) })
                    }
                }

                    DevSheetPage.TestCrashes -> {
                    ModuleDetail(swipeToDismiss = swipeToDismiss) {
                        ModuleDetailNavBar(
                            title = "Test Crashes",
                            onBack = { currentPage = DevSheetPage.Home },
                            onClose = { hideBottomSheet() },
                        )

                        TestCrashesModule()
                    }
                }

                    DevSheetPage.Home -> {
                    Column(
                        modifier = modifier
                            .fillMaxSize()
                            .padding(horizontal = 24.dp)
                            .padding(
                                top = if (swipeToDismiss) 0.dp else 10.dp,
                            ),
                    ) {
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(bottom = 6.dp),
                            verticalAlignment = Alignment.CenterVertically,
                        ) {
                            Text(
                                modifier = Modifier
                                    .weight(1f)
                                    .semantics { heading() },
                                text = "AWL Debug",
                                style = MaterialTheme.typography.titleLarge.copy(
                                    fontWeight = FontWeight.Bold,
                                ),
                                color = MaterialTheme.colorScheme.onSurface,
                            )
                            HeaderButton(
                                modifier = Modifier.offset(x = HeaderButtonInset),
                                imageVector = TablerIcons.ArrowNarrowDownDashed,
                                contentDescription = "Close",
                                onClick = { hideBottomSheet() },
                            )
                        }

                        Column(
                            modifier = Modifier.verticalScroll(homeScrollState),
                            verticalArrangement = Arrangement.spacedBy(12.dp),
                        ) {
                        AppInfoModule(
                            devConfig = devConfig,
                            showVersionOverlay = showVersionOverlay,
                            onShowVersionOverlayChanged = onShowVersionOverlayChanged,
                        )

                        ExtensionSections(
                            sections = extensionSections,
                            onLink = { action -> hideBottomSheet(then = action) },
                            onCopy = ::copyToClipboard,
                        )

                        if (modulesConfig.showLogsModule) {
                            HorizontalDivider(color = MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.4f))
                            val logsActive by logHistory.trackLogs.collectAsStateWithLifecycle()
                            NavItem(
                                text = "Logs",
                                onCLick = { currentPage = DevSheetPage.Logs },
                                active = logsActive,
                            )
                        }

                        if (showNetworkModule) {
                            HorizontalDivider(color = MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.4f))
                            val networkTracking by NetworkCollector.store.isTracking.collectAsStateWithLifecycle()
                            NavItem(
                                text = "Network",
                                onCLick = { currentPage = DevSheetPage.Network },
                                active = networkTracking,
                            )
                        }

                        performanceMonitor?.let { monitor ->
                            HorizontalDivider(color = MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.4f))
                            val performanceActive by monitor.isTracking.collectAsStateWithLifecycle()
                            NavItem(
                                text = "Performance",
                                onCLick = { currentPage = DevSheetPage.Performance },
                                active = performanceActive,
                            )
                        }

                        if (modulesConfig.showPermissionsModule) {
                            HorizontalDivider(color = MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.4f))
                            NavItem(
                                text = "Permissions",
                                onCLick = { currentPage = DevSheetPage.Permissions },
                            )
                        }

                        if (modulesConfig.showAccessibilityModule) {
                            HorizontalDivider(color = MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.4f))
                            NavItem(
                                text = "Accessibility",
                                onCLick = { currentPage = DevSheetPage.Accessibility },
                                active = accessibility.isOverriding,
                            )
                        }

                        if (modulesConfig.showDeeplinksModule) {
                            HorizontalDivider(color = MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.4f))
                            NavItem(
                                text = "Deeplinks",
                                onCLick = { currentPage = DevSheetPage.Deeplinks },
                            )
                        }

                        if (modulesConfig.showSessionModule && sessionManager != null) {
                            HorizontalDivider(color = MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.4f))
                            val sessionManagerStates by sessionManager.states.collectAsStateWithLifecycle()
                            SessionModule(
                                states = sessionManagerStates,
                                onClick = { currentPage = DevSheetPage.Session },
                            )
                        }

                        val fcmProvider = modulesConfig.fcmTokenProvider
                        if (modulesConfig.showFcmPushTokenModule && fcmProvider != null) {
                            HorizontalDivider(color = MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.4f))
                            val fcmToken = fcmProvider.token
                                .collectAsStateWithLifecycle(initialValue = null).value
                            FcmPushTokenModule(
                                token = fcmToken,
                                onCopy = {
                                    coroutineScope.launch {
                                        clipboard.setClipEntry(
                                            ClipEntry(
                                                ClipData.newPlainText(it, it)
                                            )
                                        )
                                    }
                                },
                                onRefresh = fcmProvider.onRefresh?.let { refresh ->
                                    { coroutineScope.launch { refresh() } }
                                },
                                onRevoke = fcmProvider.onRevoke?.let { revoke ->
                                    { coroutineScope.launch { revoke() } }
                                },
                            )
                        }

                        if (modulesConfig.showScreenRecordingModule) {
                            HorizontalDivider(color = MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.4f))
                            val recordingActive by ScreenRecorder.isOn.collectAsStateWithLifecycle()
                            NavItem(
                                text = "Screen Recording",
                                onCLick = { currentPage = DevSheetPage.ScreenRecording },
                                active = recordingActive,
                            )
                        }

                        if (modulesConfig.showClearAppDataModule) {
                            HorizontalDivider(color = MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.4f))
                            NavItem(
                                text = "Clear App Data",
                                onCLick = { currentPage = DevSheetPage.ClearAppData },
                            )
                        }

                        if (modulesConfig.showTestCrashesModule) {
                            HorizontalDivider(color = MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.4f))
                            NavItem(
                                text = "Test Crashes",
                                onCLick = { currentPage = DevSheetPage.TestCrashes },
                            )
                        }

                        if (modulesConfig.hasAnyModuleEnabled || extensionSections.isNotEmpty()) {
                            HorizontalDivider(color = MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.4f))
                        }
                        customModules()

                        Spacer(modifier = Modifier.height(64.dp))
                        }
                    }
                }
            }
                }
            }
        }
    }
}

@Composable
private fun ModuleDetail(
    modifier: Modifier = Modifier,
    swipeToDismiss: Boolean,
    content: @Composable ColumnScope.() -> Unit,
) {
    Column(
        modifier = modifier
            .fillMaxSize()
            .padding(horizontal = 24.dp)
            .padding(top = if (swipeToDismiss) 0.dp else 10.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        content()
    }
}

@Composable
private fun ModuleDetailNavBar(
    title: String,
    onBack: () -> Unit,
    onClose: () -> Unit,
    actions: @Composable RowScope.() -> Unit = {},
) {
    Row(verticalAlignment = Alignment.CenterVertically) {
        HeaderButton(
            modifier = Modifier.offset(x = -HeaderButtonInset),
            imageVector = TablerIcons.ChevronLeft,
            contentDescription = "Back",
            onClick = onBack,
        )
        // Takes the remaining width, so actions and the close button stay visible with long titles and large fonts.
        Text(
            modifier = Modifier
                .weight(1f)
                .semantics { heading() },
            text = title,
            style = MaterialTheme.typography.titleMedium.copy(
                fontWeight = FontWeight.Bold,
            ),
            color = MaterialTheme.colorScheme.onSurface,
            maxLines = 2,
            overflow = TextOverflow.Ellipsis,
        )
        actions()
        HeaderButton(
            modifier = Modifier.offset(x = HeaderButtonInset),
            imageVector = TablerIcons.ArrowNarrowDownDashed,
            contentDescription = "Close",
            onClick = onClose,
        )
    }
}

/** How far the 48dp touch target reaches past the 36dp circle, so the circle lines up with the content edge. */
private val HeaderButtonInset = 6.dp

/** Round header button: a 36dp circle inside a 48dp touch target. */
@Composable
private fun HeaderButton(
    imageVector: ImageVector,
    contentDescription: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Box(
        modifier = modifier
            .size(48.dp)
            .clip(CircleShape)
            .clickable(role = Role.Button, onClick = onClick),
        contentAlignment = Alignment.Center,
    ) {
        Icon(
            modifier = Modifier
                .background(MaterialTheme.colorScheme.onSurface.copy(alpha = 0.08f), CircleShape)
                .padding(4.dp)
                .size(28.dp),
            imageVector = imageVector,
            contentDescription = contentDescription,
            tint = MaterialTheme.colorScheme.onSurface,
        )
    }
}

/** Switch in the page header; it has no visible label, so TalkBack gets [label]. */
@Composable
private fun NavBarSwitch(label: String, checked: Boolean, onCheckedChange: (Boolean) -> Unit) {
    DevSwitch(
        modifier = Modifier
            .padding(start = 8.dp)
            .semantics { contentDescription = label },
        checked = checked,
        onCheckedChange = onCheckedChange,
    )
}

/** [triggers] without those an extension claims; a trigger configured for both is left to the extension. */
internal fun panelTriggers(triggers: Set<DevTrigger>, claimed: Set<DevTrigger>): Set<DevTrigger> {
    val shared = triggers intersect claimed
    if (shared.isEmpty()) return triggers
    Log.w("AwlDebug", "Triggers $shared are handled by an extension, not by the DevSheet")
    return triggers - shared
}

@Composable
private fun NavItem(
    text: String,
    onCLick: () -> Unit,
    active: Boolean = false,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(role = Role.Button, onClick = onCLick)
            .semantics { if (active) stateDescription = "Active" }
            .padding(vertical = 6.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            text = text,
            style = MaterialTheme.typography.bodyLarge.copy(
                fontWeight = FontWeight(800),
            ),
            color = MaterialTheme.colorScheme.onSurface,
            modifier = Modifier.weight(1f),
        )
        if (active) {
            Box(
                modifier = Modifier
                    .size(8.dp)
                    .clip(CircleShape)
                    .background(AppTheme.colors.positive),
            )
            Spacer(modifier = Modifier.width(8.dp))
        }
        Icon(
            painter = painterResource(R.drawable.ic_chevron_right),
            contentDescription = null,
            tint = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.3f),
        )
    }
}

@Composable
private fun rememberNetworkViewModel(): NetworkViewModel {
    val context = LocalContext.current
    return viewModel(
        factory = viewModelFactory {
            initializer { NetworkViewModel(NetworkCollector.store, DevStore(context)) }
        }
    )
}

@Composable
private fun rememberDevViewModel(): DevViewModel {
    val context = LocalContext.current
    return viewModel(
        factory = viewModelFactory {
            initializer { DevViewModel(DevStore(context)) }
        }
    )
}

@Composable
private fun CustomModulesPreview() {
    Column(modifier = Modifier.padding(vertical = 12.dp)) {
        Text(text = "Custom Module 1", color = MaterialTheme.colorScheme.onSurface)
        Spacer(modifier = Modifier.height(16.dp))
        Text(text = "Custom Module 2", color = MaterialTheme.colorScheme.onSurface)
    }
}

@Preview(
    uiMode = Configuration.UI_MODE_NIGHT_NO,
    heightDp = 1100,
)
@Composable
private fun DevSheetPreview() {
    DevTheme {
        DevSheetContent(
            state = DevSheetState.Preview,
            logHistory = LogHistory.Preview,
            devConfig = DevConfig.Preview,
            swipeToDismiss = true,
            actioner = {},
            customModules = { CustomModulesPreview() },
            onTrackLogsChanged = {},
            onMaxLogsChanged = {},
        )
    }
}

@Preview(
    uiMode = Configuration.UI_MODE_NIGHT_YES,
    heightDp = 1100,
)
@Composable
private fun DevSheetDarkPreview() {
    DevTheme {
        DevSheetContent(
            state = DevSheetState.Preview,
            logHistory = LogHistory.Preview,
            devConfig = DevConfig.Preview,
            actioner = {},
            customModules = { CustomModulesPreview() },
            onTrackLogsChanged = {},
            onMaxLogsChanged = {},
        )
    }
}

private enum class DevSheetPage {
    Home, Logs, Network, NetworkFilters, NetworkDetail, Performance, Permissions, Accessibility, Deeplinks, DeeplinkDetail, Session, ScreenRecording, TestCrashes, ClearAppData;

    val parent: DevSheetPage
        get() = when (this) {
            NetworkFilters, NetworkDetail -> Network
            DeeplinkDetail -> Deeplinks
            else -> Home
        }
}
