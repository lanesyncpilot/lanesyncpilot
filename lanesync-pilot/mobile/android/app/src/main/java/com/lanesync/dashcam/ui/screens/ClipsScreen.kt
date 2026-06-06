package com.lanesync.dashcam.ui.screens

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Download
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material.icons.filled.Search
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.lanesync.dashcam.DashcamClip
import com.lanesync.dashcam.DashcamUiState
import com.lanesync.dashcam.DashcamViewModel
import com.lanesync.dashcam.LaneSyncConfig
import com.lanesync.dashcam.ui.components.ClipCard
import com.lanesync.dashcam.ui.components.ClipThumbnail
import com.lanesync.dashcam.ui.components.DemoBanner
import com.lanesync.dashcam.ui.components.FilterChipRow
import com.lanesync.dashcam.ui.components.SectionHeader
import com.lanesync.dashcam.ui.theme.LaneSyncColors

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ClipsScreen(
  state: DashcamUiState,
  vm: DashcamViewModel,
  modifier: Modifier = Modifier,
) {
  val clips = vm.filteredClips()

  LazyColumn(
    modifier = modifier.fillMaxSize(),
    contentPadding = PaddingValues(16.dp),
    verticalArrangement = Arrangement.spacedBy(14.dp),
  ) {
    item {
      Row(
        Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically,
      ) {
        SectionHeader("Saved dashcam", "Synced from ${state.cloudUrl.removePrefix("https://")}")
        IconButton(onClick = vm::refresh) {
          Icon(Icons.Default.Refresh, contentDescription = "Refresh")
        }
      }
    }

    if (state.isDemoMode) {
      item { DemoBanner("Showing sample clips until cloud is live") }
    }

    item {
      OutlinedTextField(
        value = state.clipSearch,
        onValueChange = vm::updateClipSearch,
        modifier = Modifier.fillMaxWidth(),
        placeholder = { Text("Search clips, routes, locations…") },
        leadingIcon = { Icon(Icons.Default.Search, null) },
        singleLine = true,
        shape = RoundedCornerShape(14.dp),
      )
    }

    item {
      FilterChipRow(selected = state.clipFilter, onSelect = vm::setClipFilter)
    }

    if (state.loading) {
      item {
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.Center) {
          CircularProgressIndicator(color = LaneSyncColors.Green)
        }
      }
    } else if (clips.isEmpty()) {
      item {
        Text(
          "No clips match your search. Bookmark segments on the comma device to save them here.",
          style = MaterialTheme.typography.bodyMedium,
          color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
      }
    } else {
      items(clips, key = { it.id }) { clip ->
        ClipCard(
          clip = clip,
          state = state,
          onPlay = vm::play,
          onDownload = vm::download,
        )
      }
    }
  }

  state.playingClip?.let { clip ->
    ClipPlayerSheet(
      clip = clip,
      isDemoMode = state.isDemoMode,
      onClose = vm::stopPlayback,
      onDownload = { vm.download(clip) },
    )
  }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun ClipPlayerSheet(
  clip: DashcamClip,
  isDemoMode: Boolean,
  onClose: () -> Unit,
  onDownload: () -> Unit,
) {
  val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
  ModalBottomSheet(
    onDismissRequest = onClose,
    sheetState = sheetState,
    containerColor = MaterialTheme.colorScheme.surface,
  ) {
    Column(Modifier.padding(horizontal = 20.dp, vertical = 8.dp)) {
      Row(
        Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically,
      ) {
        Text(clip.displayTitle(), style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold)
        IconButton(onClick = onClose) {
          Icon(Icons.Default.Close, contentDescription = "Close")
        }
      }
      ClipThumbnail(clip, modifier = Modifier.height(200.dp))
      Spacer(Modifier.height(12.dp))
      if (clip.location.isNotBlank()) {
        Text(clip.location, style = MaterialTheme.typography.bodyMedium)
      }
      Text(
        "${clip.recordedAt} · ${clip.formattedSize()}",
        style = MaterialTheme.typography.bodySmall,
        color = MaterialTheme.colorScheme.onSurfaceVariant,
      )
      Spacer(Modifier.height(16.dp))
      if (isDemoMode) {
        Text(
          "Video playback will stream from ${LaneSyncConfig.CLOUD_URL} when the service launches.",
          style = MaterialTheme.typography.bodySmall,
          color = LaneSyncColors.Warning,
        )
      }
      Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.End) {
        TextButton(onClick = onDownload) {
          Icon(Icons.Default.Download, null, modifier = Modifier.padding(end = 6.dp))
          Text("Download")
        }
      }
      Spacer(Modifier.height(24.dp))
    }
  }
}
