package com.appswithlove.debug.ui.dev.sheet

import android.app.Activity
import android.content.ClipData
import android.content.res.Configuration
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
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.SideEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.platform.ClipEntry
import androidx.compose.ui.platform.LocalClipboard
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.Density
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
import com.appswithlove.debug.ui.dev.sheet.modules.AppInfoModule
import com.appswithlove.debug.ui.dev.sheet.modules.FcmPushTokenModule
import com.appswithlove.debug.ui.dev.sheet.modules.LogsModule
import com.appswithlove.debug.ui.dev.sheet.modules.performance.PerformanceModule
import com.appswithlove.debug.ui.dev.sheet.modules.permissions.PermissionsModule
import com.appswithlove.debug.ui.dev.sheet.modules.accessibility.AccessibilityModule
import com.appswithlove.debug.ui.dev.sheet.modules.TestCrashesModule
import com.appswithlove.debug.ui.dev.sheet.modules.deeplinks.DeeplinksModule
import com.appswithlove.debug.ui.dev.sheet.modules.session.SessionDetailModule
import com.appswithlove.debug.ui.dev.sheet.modules.session.SessionManager
import com.appswithlove.debug.ui.dev.sheet.modules.session.SessionModule
import com.appswithlove.debug.ui.component.threeFingerTap
import com.appswithlove.debug.ui.dev.log.LogCollector
import com.appswithlove.debug.ui.dev.log.LogHistory
import com.appswithlove.debug.ui.theme.AppTheme
import com.appswithlove.debug.ui.theme.DevTheme
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.launch

/**
 * A composable that provides a development sheet that can be triggered by a three-finger tap.
 *
 * @param modifier Modifier to be applied to the `DevSheet`. Note that this only modifies the
 * `DevSheet` itself, not the content.
 * @param viewModel The [DevViewModel] that manages the state of the `DevSheet`.
 * @param logHistory The [LogHistory] to be displayed in the logs module.
 * @param devConfig The [DevConfig] to be displayed in the app info module. Map your app's
 * `BuildConfig` to this to show app info on the sheet.
 * @param modulesConfig A [com.appswithlove.debug.api.DevModulesConfig] that controls which built-in modules are shown in the
 * `DevSheet`. All modules are enabled by default.
 * @param customModules A composable lambda that allows you to add your own custom modules to the
 * `DevSheet`.
 * @param isAlwaysActive If set to `true`, the three-finger tap gesture to open the `DevSheet`
 * will always be active. Defaults to `false`.
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
    viewModel: DevViewModel = rememberDevViewModel(),
    logHistory: LogHistory = LogCollector.logHistory,
    devConfig: DevConfig? = null,
    modulesConfig: DevModulesConfig = DevModulesConfig(),
    customModules: @Composable ColumnScope.() -> Unit = {},
    isAlwaysActive: Boolean = false,
    swipeToDismiss: Boolean = false,
    inheritHostTheme: Boolean = false,
    content: @Composable () -> Unit,
) {
    val hostColorScheme = MaterialTheme.colorScheme
    val state = viewModel.state.collectAsStateWithLifecycle()
    var fontScale by rememberSaveable { mutableFloatStateOf(1f) }

    val density = LocalDensity.current

    LaunchedEffect(isAlwaysActive) {
        viewModel.setIsAlwaysActive(isAlwaysActive)
    }

    Box(
        modifier = modifier
            .fillMaxSize()
            .threeFingerTap { viewModel.submitAction(DevAction.ShowDevSheet()) }
    ) {
        CompositionLocalProvider(
            LocalDensity provides Density(density.density, fontScale)
        ) {
            content()
        }

        DevTheme(
            colorScheme = if (inheritHostTheme) hostColorScheme else null,
        ) {
            DevSheetContent(
                modifier = modifier,
                state = state.value,
                modulesConfig = modulesConfig,
                devConfig = devConfig,
                logHistory = logHistory,
                actioner = { action -> viewModel.submitAction(action) },
                customModules = customModules,
                swipeToDismiss = swipeToDismiss,
                onTrackLogsChanged = { viewModel.setTrackLogs(it) },
                onMaxLogsChanged = { viewModel.setMaxLogSize(it) },
                fontScale = fontScale,
                onFontScaleChanged = { fontScale = it },
            )
        }
    }
}

@Composable
private fun DevSheetContent(
    modifier: Modifier = Modifier,
    state: DevSheetState,
    logHistory: LogHistory,
    devConfig: DevConfig? = null,
    modulesConfig: DevModulesConfig = DevModulesConfig(),
    actioner: (DevAction) -> Unit,
    customModules: @Composable ColumnScope.() -> Unit = {},
    swipeToDismiss: Boolean = false,
    onTrackLogsChanged: (Boolean) -> Unit,
    onMaxLogsChanged: (Int) -> Unit,
    fontScale: Float = 1f,
    onFontScaleChanged: (Float) -> Unit = {},
) {
    val context = LocalContext.current
    val coroutineScope = rememberCoroutineScope()
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    val clipboard = LocalClipboard.current
    val performanceMonitor = remember {
        if (modulesConfig.showPerformanceModule) PerformanceMonitor(context) else null
    }
    val sessionManager = remember {
        if (modulesConfig.showSessionModule && modulesConfig.sessionProviders.isNotEmpty()) {
            SessionManager(modulesConfig.sessionProviders)
        } else {
            null
        }
    }
    var currentPage by rememberSaveable { mutableStateOf(DevSheetPage.Home) }

    fun hideBottomSheet() {
        coroutineScope.launch {
            sheetState.hide()
        }.invokeOnCompletion {
            if (!sheetState.isVisible) {
                actioner(DevAction.ShowDevSheet())
            }
        }
    }

    LaunchedEffect(state.isShown) {
        if (state.isShown) sheetState.show() else sheetState.hide()
    }

    if (state.isShown || sheetState.isVisible) {
        ModalBottomSheet(
            modifier = Modifier.statusBarsPadding(),
            onDismissRequest = { hideBottomSheet() },
            containerColor = AppTheme.colors.background,
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
                    currentPage = DevSheetPage.Home
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
                                DevSwitch(
                                    checked = trackLogs,
                                    onCheckedChange = onTrackLogsChanged,
                                )
                                Spacer(modifier = Modifier.width(8.dp))
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

                    DevSheetPage.Performance -> performanceMonitor?.let { monitor ->
                    val isTracking by monitor.isTracking.collectAsStateWithLifecycle()
                    ModuleDetail(swipeToDismiss = swipeToDismiss) {
                        ModuleDetailNavBar(
                            title = "Performance",
                            onBack = { currentPage = DevSheetPage.Home },
                            onClose = { hideBottomSheet() },
                            actions = {
                                DevSwitch(
                                    checked = isTracking,
                                    onCheckedChange = { monitor.setTracking(it) },
                                )
                                Spacer(modifier = Modifier.width(8.dp))
                            },
                        )

                        PerformanceModule(
                            modifier = Modifier.weight(1f),
                            performanceMonitor = monitor,
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
                            fontScale = fontScale,
                            onFontScaleChanged = onFontScaleChanged,
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
                            deeplinks = modulesConfig.deeplinks,
                        )
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
                                top = if (swipeToDismiss) 0.dp else 16.dp,
                            ),
                    ) {
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(bottom = 12.dp),
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.CenterVertically,
                        ) {
                            Text(
                                text = "Debug Drawer",
                                style = MaterialTheme.typography.titleMedium.copy(
                                    fontWeight = FontWeight.Bold,
                                ),
                                color = MaterialTheme.colorScheme.onSurface,
                            )
                            Icon(
                                modifier = Modifier
                                    .clip(CircleShape)
                                    .clickable { hideBottomSheet() }
                                    .background(MaterialTheme.colorScheme.onSurface.copy(alpha = 0.08f))
                                    .padding(4.dp)
                                    .size(28.dp),
                                imageVector = TablerIcons.ArrowNarrowDownDashed,
                                contentDescription = "Close",
                                tint = MaterialTheme.colorScheme.onSurface,
                            )
                        }

                        Column(
                            modifier = Modifier.verticalScroll(rememberScrollState()),
                            verticalArrangement = Arrangement.spacedBy(12.dp),
                        ) {
                        AppInfoModule(devConfig = devConfig)

                        if (modulesConfig.showLogsModule) {
                            HorizontalDivider(color = MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.4f))
                            val logsActive by logHistory.trackLogs.collectAsStateWithLifecycle()
                            NavItem(
                                text = "Logs",
                                onCLick = { currentPage = DevSheetPage.Logs },
                                active = logsActive,
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
                                onLongPress = {
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

                        if (modulesConfig.showTestCrashesModule) {
                            HorizontalDivider(color = MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.4f))
                            NavItem(
                                text = "Test Crashes",
                                onCLick = { currentPage = DevSheetPage.TestCrashes },
                            )
                        }

                        if (modulesConfig.hasAnyModuleEnabled) {
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
            .padding(top = if (swipeToDismiss) 0.dp else 16.dp),
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
        Icon(
            modifier = Modifier
                .clip(CircleShape)
                .clickable { onBack() }
                .background(MaterialTheme.colorScheme.onSurface.copy(alpha = 0.08f))
                .padding(4.dp)
                .size(28.dp),
            imageVector = TablerIcons.ChevronLeft,
            contentDescription = "Back",
            tint = MaterialTheme.colorScheme.onSurface,
        )
        Spacer(modifier = Modifier.width(8.dp))
        Text(
            text = title,
            style = MaterialTheme.typography.titleMedium.copy(
                fontWeight = FontWeight.Bold,
            ),
            color = MaterialTheme.colorScheme.onSurface,
        )
        Spacer(modifier = Modifier.weight(1f))
        actions()
        Icon(
            modifier = Modifier
                .clip(CircleShape)
                .clickable { onClose() }
                .background(MaterialTheme.colorScheme.onSurface.copy(alpha = 0.08f))
                .padding(4.dp)
                .size(28.dp),
            imageVector = TablerIcons.ArrowNarrowDownDashed,
            contentDescription = "Close",
            tint = MaterialTheme.colorScheme.onSurface,
        )
    }
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
            .clickable { onCLick() }
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
    Home, Logs, Performance, Permissions, Accessibility, Deeplinks, Session, TestCrashes
}
