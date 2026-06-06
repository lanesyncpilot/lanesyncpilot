package com.lanesync.dashcam.ui.theme

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import com.lanesync.dashcam.ThemeMode

object LaneSyncColors {
  val Green = Color(0xFF80D8A6)
  val GreenDark = Color(0xFF3D9E72)
  val GreenGlow = Color(0xFF4AE3A0)
  val Background = Color(0xFF0D0F11)
  val Surface = Color(0xFF161A1F)
  val SurfaceHigh = Color(0xFF1E242B)
  val SurfaceBorder = Color(0xFF2A3139)
  val TextPrimary = Color(0xFFF2F5F7)
  val TextSecondary = Color(0xFF9AA5B1)
  val Warning = Color(0xFFFFB84D)
  val Error = Color(0xFFFF6B6B)
}

private val DarkScheme = darkColorScheme(
  primary = LaneSyncColors.Green,
  onPrimary = Color(0xFF0A1A12),
  primaryContainer = Color(0xFF1A3D2E),
  onPrimaryContainer = LaneSyncColors.Green,
  secondary = LaneSyncColors.GreenGlow,
  background = LaneSyncColors.Background,
  onBackground = LaneSyncColors.TextPrimary,
  surface = LaneSyncColors.Surface,
  onSurface = LaneSyncColors.TextPrimary,
  surfaceVariant = LaneSyncColors.SurfaceHigh,
  onSurfaceVariant = LaneSyncColors.TextSecondary,
  outline = LaneSyncColors.SurfaceBorder,
  error = LaneSyncColors.Error,
)

private val LightScheme = lightColorScheme(
  primary = LaneSyncColors.GreenDark,
  onPrimary = Color.White,
  primaryContainer = Color(0xFFD4F5E4),
  onPrimaryContainer = Color(0xFF0A2E1C),
  background = Color(0xFFF4F6F8),
  onBackground = Color(0xFF121416),
  surface = Color.White,
  onSurface = Color(0xFF121416),
  surfaceVariant = Color(0xFFE8EDF2),
  onSurfaceVariant = Color(0xFF5C6670),
  outline = Color(0xFFD0D8E0),
)

@Composable
fun LaneSyncTheme(
  themeMode: ThemeMode = ThemeMode.DARK,
  content: @Composable () -> Unit,
) {
  val systemDark = isSystemInDarkTheme()
  val useDark = when (themeMode) {
    ThemeMode.DARK -> true
    ThemeMode.LIGHT -> false
    ThemeMode.SYSTEM -> systemDark
  }
  MaterialTheme(
    colorScheme = if (useDark) DarkScheme else LightScheme,
    typography = LaneSyncTypography,
    content = content,
  )
}
