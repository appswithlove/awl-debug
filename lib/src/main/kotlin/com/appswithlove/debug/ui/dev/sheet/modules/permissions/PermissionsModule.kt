package com.appswithlove.debug.ui.dev.sheet.modules.permissions

import android.content.pm.PackageManager
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.getValue
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import androidx.core.content.ContextCompat
import com.appswithlove.debug.ui.theme.DevTheme

@Composable
fun PermissionsModule(modifier: Modifier = Modifier) {
    val context = LocalContext.current

    val grouped = remember {
        val packageManager = context.packageManager
        val packageInfo = packageManager.getPackageInfo(
            context.packageName,
            PackageManager.GET_PERMISSIONS,
        )
        (packageInfo.requestedPermissions ?: emptyArray())
            .map { name ->
                val description = try {
                    packageManager.getPermissionInfo(name, 0)
                        .loadDescription(packageManager)
                        ?.toString()
                        ?.takeIf { it.isNotBlank() }
                } catch (_: PackageManager.NameNotFoundException) {
                    null
                }
                PermissionItem(
                    name = name,
                    isGranted = ContextCompat.checkSelfPermission(
                        context,
                        name
                    ) == PackageManager.PERMISSION_GRANTED,
                    origin = name.toPermissionOrigin(context.packageName),
                    description = description,
                )
            }
            .groupBy { it.origin }
    }

    var expandedPermission by remember { mutableStateOf<String?>(null) }

    Column(modifier = modifier) {
        LazyColumn(
            modifier = Modifier
                .weight(1f, fill = false)
                .fillMaxWidth()
                .border(1.dp, MaterialTheme.colorScheme.onSurface, RoundedCornerShape(4.dp)),
            contentPadding = PaddingValues(4.dp),
        ) {
            if (grouped.isEmpty()) {
                item {
                    Text(
                        text = "No permissions declared",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurface,
                        modifier = Modifier.padding(4.dp),
                    )
                }
            } else {
                listOf(
                    PermissionOrigin.App,
                    PermissionOrigin.System,
                    PermissionOrigin.Library,
                ).forEach { origin ->
                    val items = grouped[origin] ?: return@forEach
                    val label = when (origin) {
                        PermissionOrigin.App -> "App"
                        PermissionOrigin.System -> "System"
                        PermissionOrigin.Library -> "Libraries"
                    }
                    item {
                        Text(
                            text = label,
                            style = MaterialTheme.typography.labelSmall.copy(fontWeight = FontWeight.Bold),
                            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f),
                            modifier = Modifier.padding(start = 4.dp, top = 8.dp, bottom = 4.dp),
                        )
                    }
                    itemsIndexed(items) { index, item ->
                        PermissionRow(
                            item = item,
                            isLastItem = index == items.lastIndex,
                            expanded = expandedPermission == item.name,
                            onClick = {
                                expandedPermission =
                                    if (expandedPermission == item.name) null else item.name
                            },
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun PermissionRow(
    item: PermissionItem,
    isLastItem: Boolean,
    expanded: Boolean,
    onClick: () -> Unit,
) {
    Column(
        modifier = Modifier
            .clickable(onClick = onClick)
            .padding(vertical = 4.dp, horizontal = 4.dp),
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(
                text = item.name.substringAfterLast('.'),
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurface,
                modifier = Modifier.weight(1f),
            )
            Text(
                text = if (item.isGranted) "Granted" else "Denied",
                style = MaterialTheme.typography.labelSmall,
                color = if (item.isGranted)
                    MaterialTheme.colorScheme.onSurface
                else
                    MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f),
                fontWeight = if (item.isGranted) FontWeight.Bold else FontWeight.Normal,
            )
        }
        AnimatedVisibility(visible = expanded) {
            Text(
                text = item.description ?: "No description available.",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f),
                modifier = Modifier.padding(top = 2.dp, bottom = 2.dp),
            )
        }
        if (!isLastItem) {
            HorizontalDivider(modifier = Modifier.padding(top = 4.dp))
        }
    }
}

private fun String.toPermissionOrigin(appPackage: String): PermissionOrigin = when {
    startsWith("$appPackage.permission") -> PermissionOrigin.App
    startsWith("android.permission.") -> PermissionOrigin.System
    else -> PermissionOrigin.Library
}

@Preview(showBackground = true)
@Composable
private fun PermissionsModulePreview() {
    DevTheme {
        PermissionsModule(modifier = Modifier.padding(8.dp))
    }
}
