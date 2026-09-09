package com.appswithlove.debug.ui.component.icons

import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.graphics.vector.addPathNodes
import androidx.compose.ui.unit.dp

/**
 * Tabler (https://tabler.io/icons, MIT) outline icons vendored as [ImageVector]s so the library
 * doesn't depend on androidx.compose.material:material-icons-extended.
 *
 * Icons are stroke-based (24x24, stroke width 2, round caps/joins) and are tinted by [androidx.compose.material3.Icon].
 */
object TablerIcons {
    val X: ImageVector by lazyIcon("TablerX", "M18 6l-12 12", "M6 6l12 12")

    val ChevronLeft: ImageVector by lazyIcon("TablerChevronLeft", "M15 6l-6 6l6 6")

    val ArrowNarrowDownDashed: ImageVector by lazyIcon(
        "TablerArrowNarrowDownDashed",
        "M12 5v.5m0 3v1.5m0 3v6",
        "M16 15l-4 4",
        "M8 15l4 4",
    )

    val Trash: ImageVector by lazyIcon(
        "TablerTrash",
        "M4 7l16 0",
        "M10 11l0 6",
        "M14 11l0 6",
        "M5 7l1 12a2 2 0 0 0 2 2h8a2 2 0 0 0 2 -2l1 -12",
        "M9 7v-3a1 1 0 0 1 1 -1h4a1 1 0 0 1 1 1v3",
    )

    val TrashX: ImageVector by lazyIcon(
        "TablerTrashX",
        "M4 7h16",
        "M5 7l1 12a2 2 0 0 0 2 2h8a2 2 0 0 0 2 -2l1 -12",
        "M9 7v-3a1 1 0 0 1 1 -1h4a1 1 0 0 1 1 1v3",
        "M10 12l4 4m0 -4l-4 4",
    )

    val Pencil: ImageVector by lazyIcon(
        "TablerPencil",
        "M4 20h4l10.5 -10.5a2.828 2.828 0 1 0 -4 -4l-10.5 10.5v4",
        "M13.5 6.5l4 4",
    )

    val InfoCircle: ImageVector by lazyIcon(
        "TablerInfoCircle",
        "M3 12a9 9 0 1 0 18 0a9 9 0 0 0 -18 0",
        "M12 9h.01",
        "M11 12h1v4h1",
    )

    val Share: ImageVector by lazyIcon(
        "TablerShare",
        "M3 12a3 3 0 1 0 6 0a3 3 0 1 0 -6 0",
        "M15 6a3 3 0 1 0 6 0a3 3 0 1 0 -6 0",
        "M15 18a3 3 0 1 0 6 0a3 3 0 1 0 -6 0",
        "M8.7 10.7l6.6 -3.4",
        "M8.7 13.3l6.6 3.4",
    )

    val AlertTriangle: ImageVector by lazyIcon(
        "TablerAlertTriangle",
        "M12 9v4",
        "M10.363 3.591l-8.106 13.534a1.914 1.914 0 0 0 1.636 2.871h16.214a1.914 1.914 0 0 0 1.636 -2.87l-8.106 -13.536a1.914 1.914 0 0 0 -3.274 0",
        "M12 16h.01",
    )

    val Refresh: ImageVector by lazyIcon(
        "TablerRefresh",
        "M20 11a8.1 8.1 0 0 0 -15.5 -2m-.5 -4v4h4",
        "M4 13a8.1 8.1 0 0 0 15.5 2m.5 4v-4h-4",
    )

    val Eraser: ImageVector by lazyIcon(
        "TablerEraser",
        "M19 20h-10.5l-4.21 -4.3a1 1 0 0 1 0 -1.41l10 -10a1 1 0 0 1 1.41 0l5 5a1 1 0 0 1 0 1.41l-9.2 9.3",
        "M18 13.3l-6.3 -6.3",
    )

    val Copy: ImageVector by lazyIcon(
        "TablerCopy",
        "M7 9.667a2.667 2.667 0 0 1 2.667 -2.667h8.666a2.667 2.667 0 0 1 2.667 2.667v8.666a2.667 2.667 0 0 1 -2.667 2.667h-8.666a2.667 2.667 0 0 1 -2.667 -2.667l0 -8.666",
        "M4.012 16.737a2.005 2.005 0 0 1 -1.012 -1.737v-10c0 -1.1 .9 -2 2 -2h10c.75 0 1.158 .385 1.5 1",
    )

    val Eye: ImageVector by lazyIcon(
        "TablerEye",
        "M10 12a2 2 0 1 0 4 0a2 2 0 0 0 -4 0",
        "M21 12c-2.4 4 -5.4 6 -9 6c-3.6 0 -6.6 -2 -9 -6c2.4 -4 5.4 -6 9 -6c3.6 0 6.6 2 9 6",
    )

    val EyeOff: ImageVector by lazyIcon(
        "TablerEyeOff",
        "M10.585 10.587a2 2 0 0 0 2.829 2.828",
        "M16.681 16.673a8.717 8.717 0 0 1 -4.681 1.327c-3.6 0 -6.6 -2 -9 -6c1.272 -2.12 2.712 -3.678 4.32 -4.674m2.86 -1.146a9.055 9.055 0 0 1 1.82 -.18c3.6 0 6.6 2 9 6c-.666 1.11 -1.379 2.067 -2.138 2.87",
        "M3 3l18 18",
    )
}

private fun lazyIcon(name: String, vararg paths: String): Lazy<ImageVector> =
    lazy(LazyThreadSafetyMode.NONE) {
        ImageVector.Builder(
            name = name,
            defaultWidth = 24.dp,
            defaultHeight = 24.dp,
            viewportWidth = 24f,
            viewportHeight = 24f,
        ).apply {
            paths.forEach { pathString ->
                addPath(
                    pathData = addPathNodes(pathString),
                    stroke = SolidColor(Color.Black),
                    strokeLineWidth = 2f,
                    strokeLineCap = StrokeCap.Round,
                    strokeLineJoin = StrokeJoin.Round,
                )
            }
        }.build()
    }
