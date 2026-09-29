package com.appswithlove.debug.sample

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
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.tooling.preview.Preview
import com.appswithlove.debug.api.DevConfig
import com.appswithlove.debug.api.DevModulesConfig
import com.appswithlove.debug.domain.model.DevSettings
import com.appswithlove.debug.sample.ui.theme.AwlDebugTheme
import com.appswithlove.debug.ui.dev.sheet.DevSheet
import kotlinx.coroutines.launch
import com.appswithlove.debug.ui.dev.log.DevLogTree
import timber.log.Timber

class MainActivity : ComponentActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        Timber.plant(DevLogTree())
        enableEdgeToEdge()
        setContent { App() }
    }
}

@Composable
private fun App() {
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
            isAlwaysActive = false,
            swipeToDismiss = false,
            inheritHostTheme = true,
            modulesConfig = DevModulesConfig(),
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
                        Text(text = "Hello, World!")
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

@Preview(showBackground = true)
@Composable
fun GreetingPreview() {
    AwlDebugTheme {
        App()
    }
}
