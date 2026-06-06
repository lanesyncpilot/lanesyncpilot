package com.lanesync.dashcam.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Bookmark
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.FilterChip
import androidx.compose.material3.FilterChipDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.lanesync.dashcam.DashcamClip
import com.lanesync.dashcam.DashcamUiState
import com.lanesync.dashcam.ui.theme.LaneSyncColors

@Composable
fun DemoBanner(message: String, modifier: Modifier = Modifier) {
  Surface(
    modifier = modifier.fillMaxWidth(),
    color = LaneSyncColors.Green.copy(alpha = 0.12f),
    shape = RoundedCornerShape(12.dp),
    border = androidx.compose.foundation.BorderStroke(1.dp, LaneSyncColors.Green.copy(alpha = 0.35f)),
  ) {
    Row(
      Modifier.padding(horizontal = 14.dp, vertical = 10.dp),
      verticalAlignment = Alignment.CenterVertically,
    ) {
      Box(
        Modifier
          .size(8.dp)
          .clip(CircleShape)
          .background(LaneSyncColors.GreenGlow),
      )
      Spacer(Modifier.width(10.dp))
      Text(message, style = MaterialTheme.typography.bodySmall, color = LaneSyncColors.Green)
    }
  }
}

@Composable
fun SectionHeader(title: String, subtitle: String? = null, modifier: Modifier = Modifier) {
  Column(modifier) {
    Text(title, style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.SemiBold)
    subtitle?.let {
      Text(it, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
    }
  }
}

@Composable
fun StatCard(
  label: String,
  value: String,
  modifier: Modifier = Modifier,
) {
  Card(
    modifier = modifier,
    colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant),
    shape = RoundedCornerShape(16.dp),
  ) {
    Column(Modifier.padding(16.dp)) {
      Text(label, style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
      Spacer(Modifier.height(4.dp))
      Text(value, style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold)
    }
  }
}

@Composable
fun StatusPill(text: String, active: Boolean, modifier: Modifier = Modifier) {
  val bg = if (active) LaneSyncColors.Green.copy(alpha = 0.18f) else MaterialTheme.colorScheme.surfaceVariant
  val fg = if (active) LaneSyncColors.Green else MaterialTheme.colorScheme.onSurfaceVariant
  Surface(
    modifier = modifier,
    shape = RoundedCornerShape(50),
    color = bg,
  ) {
    Text(
      text,
      modifier = Modifier.padding(horizontal = 12.dp, vertical = 6.dp),
      style = MaterialTheme.typography.labelMedium,
      color = fg,
    )
  }
}

@Composable
fun ClipThumbnail(
  clip: DashcamClip,
  modifier: Modifier = Modifier,
  onPlay: (() -> Unit)? = null,
) {
  val gradient = Brush.linearGradient(
    colors = listOf(
      Color.hsl(clip.thumbnailHue, 0.45f, 0.28f),
      Color.hsl(clip.thumbnailHue + 25f, 0.35f, 0.18f),
    ),
  )
  Box(
    modifier = modifier
      .clip(RoundedCornerShape(14.dp))
      .background(gradient)
      .height(120.dp)
      .fillMaxWidth(),
  ) {
    Box(
      Modifier
        .fillMaxSize()
        .background(Color.Black.copy(alpha = 0.15f)),
    )
    if (clip.preserved) {
      Icon(
        Icons.Default.Bookmark,
        contentDescription = null,
        tint = LaneSyncColors.Green,
        modifier = Modifier.padding(10.dp).align(Alignment.TopEnd).size(18.dp),
      )
    }
    if (onPlay != null) {
      Surface(
        modifier = Modifier.align(Alignment.Center).clickable(onClick = onPlay),
        shape = CircleShape,
        color = Color.White.copy(alpha = 0.92f),
      ) {
        Icon(
          Icons.Default.PlayArrow,
          contentDescription = "Play",
          tint = Color.Black,
          modifier = Modifier.padding(10.dp).size(28.dp),
        )
      }
    }
    if (clip.durationSec > 0) {
      Text(
        clip.formattedDuration(),
        modifier = Modifier
          .align(Alignment.BottomEnd)
          .padding(8.dp)
          .background(Color.Black.copy(alpha = 0.55f), RoundedCornerShape(6.dp))
          .padding(horizontal = 6.dp, vertical = 2.dp),
        style = MaterialTheme.typography.labelSmall,
        color = Color.White,
      )
    }
  }
}

@Composable
fun ClipCard(
  clip: DashcamClip,
  state: DashcamUiState,
  onPlay: (DashcamClip) -> Unit,
  onDownload: (DashcamClip) -> Unit,
  modifier: Modifier = Modifier,
) {
  Card(
    modifier = modifier.fillMaxWidth(),
    shape = RoundedCornerShape(18.dp),
    colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
    elevation = CardDefaults.cardElevation(defaultElevation = 2.dp),
  ) {
    Column {
      ClipThumbnail(clip, onPlay = { onPlay(clip) })
      Column(Modifier.padding(14.dp)) {
        Text(clip.displayTitle(), style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold)
        if (clip.location.isNotBlank()) {
          Text(clip.location, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
        Row(Modifier.padding(top = 4.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
          Text(clip.recordedAt, style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
          Text("·", color = MaterialTheme.colorScheme.onSurfaceVariant)
          Text(clip.formattedSize(), style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
        if (state.downloadingId == clip.id) {
          Spacer(Modifier.height(10.dp))
          LinearProgressIndicator(
            progress = { state.downloadProgress.coerceIn(0f, 1f) },
            modifier = Modifier.fillMaxWidth(),
            color = LaneSyncColors.Green,
          )
        }
      }
    }
  }
}

@Composable
fun FilterChipRow(
  selected: com.lanesync.dashcam.ClipFilter,
  onSelect: (com.lanesync.dashcam.ClipFilter) -> Unit,
  modifier: Modifier = Modifier,
) {
  Row(modifier, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
    com.lanesync.dashcam.ClipFilter.entries.forEach { filter ->
      FilterChip(
        selected = selected == filter,
        onClick = { onSelect(filter) },
        label = { Text(filter.name.lowercase().replaceFirstChar { it.uppercase() }) },
        colors = FilterChipDefaults.filterChipColors(
          selectedContainerColor = LaneSyncColors.Green.copy(alpha = 0.2f),
          selectedLabelColor = LaneSyncColors.Green,
        ),
      )
    }
  }
}

@Composable
fun HeroHeader(
  title: String,
  subtitle: String,
  modifier: Modifier = Modifier,
) {
  Box(
    modifier = modifier
      .fillMaxWidth()
      .clip(RoundedCornerShape(20.dp))
      .background(
        Brush.linearGradient(
          listOf(
            LaneSyncColors.GreenDark.copy(alpha = 0.85f),
            LaneSyncColors.SurfaceHigh,
            LaneSyncColors.Background,
          ),
        ),
      )
      .border(1.dp, LaneSyncColors.Green.copy(alpha = 0.25f), RoundedCornerShape(20.dp))
      .padding(20.dp),
  ) {
    Column {
      Text("LaneSync", style = MaterialTheme.typography.labelLarge, color = LaneSyncColors.GreenGlow)
      Text(title, style = MaterialTheme.typography.headlineMedium, color = Color.White, fontWeight = FontWeight.Bold)
      Spacer(Modifier.height(6.dp))
      Text(subtitle, style = MaterialTheme.typography.bodyMedium, color = Color.White.copy(alpha = 0.75f))
    }
  }
}
