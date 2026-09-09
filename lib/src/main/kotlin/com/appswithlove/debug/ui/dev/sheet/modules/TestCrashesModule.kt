package com.appswithlove.debug.ui.dev.sheet.modules

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.material3.Icon
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.appswithlove.debug.ui.component.DevOutlinedButton
import com.appswithlove.debug.ui.component.icons.TablerIcons
import com.appswithlove.debug.ui.theme.AppTheme

@Composable
fun TestCrashesModule() {
    Column(modifier = Modifier.padding(vertical = 12.dp)) {

        DevOutlinedButton(
            modifier = Modifier.fillMaxWidth(),
            contentColor = AppTheme.colors.error,
            text = "Simulate crash - Runtime exception",
            leadingIcon = {
                Icon(
                    modifier = Modifier.size(18.dp),
                    imageVector = TablerIcons.AlertTriangle,
                    contentDescription = null,
                    tint = AppTheme.colors.error
                )
            },
            onClick = {
                crashOne()
            }
        )

        DevOutlinedButton(
            modifier = Modifier.fillMaxWidth(),
            contentColor = AppTheme.colors.error,
            text = "Simulate crash - Array index out of bounds",
            leadingIcon = {
                Icon(
                    modifier = Modifier.size(18.dp),
                    imageVector = TablerIcons.AlertTriangle,
                    contentDescription = null,
                    tint = AppTheme.colors.error
                )
            },
            onClick = {
                crashTwo()
            }
        )
    }
}

fun crashOne() {
    throw RuntimeException("Don't worry, be happy!")
}

fun crashTwo() {
    val testArray = emptyArray<Int>()
    testArray[0]
    testArray[1] = 5
}
