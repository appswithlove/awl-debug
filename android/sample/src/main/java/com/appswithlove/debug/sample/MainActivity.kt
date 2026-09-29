package com.appswithlove.debug.sample

import android.content.Intent
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.tooling.preview.Preview
import com.appswithlove.debug.api.DeeplinkItem
import com.appswithlove.debug.api.DevConfig
import com.appswithlove.debug.api.DevModulesConfig
import com.appswithlove.debug.api.DevTrigger
import com.appswithlove.debug.domain.model.DevSettings
import com.appswithlove.debug.sample.ui.theme.AwlDebugTheme
import com.appswithlove.debug.ui.dev.sheet.DevSheet
import kotlinx.coroutines.launch
import com.appswithlove.debug.ui.dev.log.DevLogTree
import androidx.compose.foundation.layout.Column
import androidx.compose.material3.Button
import kotlinx.coroutines.Dispatchers
import timber.log.Timber

class MainActivity : ComponentActivity() {

    private val openedDeeplink = mutableStateOf<String?>(null)

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        Timber.plant(DevLogTree())
        openedDeeplink.value = intent?.dataString
        enableEdgeToEdge()
        setContent { App(openedDeeplink.value) }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        openedDeeplink.value = intent.dataString
    }
}

@Composable
private fun App(openedDeeplink: String? = null) {
    AwlDebugTheme {
        LaunchedEffect(Unit) {
            HttpUtils.sendHttpRequest()
            Timber.d("This is an example of Timber debug message")
            Timber.i("This is an example of Timber info message")
            Timber.w("This is an example of Timber warning message")
            Timber.e("This is an example of Timber error message")
        }

        DevSheet(
            modifier = Modifier.fillMaxSize(),
            devConfig = DevConfig(
                versionName = "Sample App",
                versionCode = 1,
                buildType = "1",
                flavor = "dev",
            ),
            triggers = DevTrigger.entries.toSet(),
            isAlwaysActive = false,
            swipeToDismiss = false,
            inheritHostTheme = true,
            modulesConfig = DevModulesConfig(
                deeplinks = listOf(
                    DeeplinkItem(label = "Profile", url = "awl-sample://profile/123"),
                    DeeplinkItem(label = "Settings", url = "awl-sample://settings"),
                ),
            ),
            customModules = {
                Text(text = "Custom Module", color = MaterialTheme.colorScheme.onSurface)
                Text(text = "Custom Module", color = MaterialTheme.colorScheme.onSurface)
            },
            content = {
                Scaffold(modifier = Modifier.fillMaxSize()) { innerPadding ->
                    Box(
                        modifier = Modifier
                            .fillMaxSize()
                            .padding(innerPadding)
                            .background(MaterialTheme.colorScheme.background),
                        contentAlignment = Alignment.Center,
                    ) {
                        val context = LocalContext.current
                        val checked = DevSettings.isDevToolActivated(context).collectAsState(false)
                        val scope = rememberCoroutineScope()
                        Column(horizontalAlignment = Alignment.CenterHorizontally) {
                            Text(text = openedDeeplink?.let { "Opened $it" } ?: "Hello, World!")
                            // Load generators for the Performance module and overlay.
                            Button(onClick = { Thread.sleep(1_500) }) { Text("Block main thread 1.5 s") }
                            Button(onClick = { scope.launch(Dispatchers.Default) { busyLoop(5_000) } }) {
                                Text("CPU load 5 s")
                            }
                        }
                        Switch(
                            modifier = Modifier.align(Alignment.BottomCenter),
                            onCheckedChange = {
                                scope.launch {
                                    DevSettings.activateDevTool(context, it)
                                }
                            },
                            checked = checked.value
                        )
                    }
                }
            }
        )
    }
}

private fun busyLoop(durationMs: Long) {
    val end = System.currentTimeMillis() + durationMs
    var value = 0L
    while (System.currentTimeMillis() < end) value += value xor end
    Timber.d("Busy loop done ($value)")
}

@Preview(showBackground = true)
@Composable
fun GreetingPreview() {
    AwlDebugTheme {
        App()
    }
}
