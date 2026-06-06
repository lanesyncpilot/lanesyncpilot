package com.lanesync.dashcam.ui.screens

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ChevronRight
import androidx.compose.material.icons.filled.Cloud
import androidx.compose.material.icons.filled.DirectionsCar
import androidx.compose.material.icons.filled.Navigation
import androidx.compose.material.icons.filled.SignalCellularAlt
import androidx.compose.material.icons.filled.Traffic
import androidx.compose.material.icons.filled.Shield
import androidx.compose.material.icons.filled.Videocam
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.lanesync.dashcam.DashcamUiState
import com.lanesync.dashcam.DashcamViewModel
import com.lanesync.dashcam.LaneSyncConfig
import com.lanesync.dashcam.ui.components.ClipThumbnail
import com.lanesync.dashcam.ui.components.DemoBanner
import com.lanesync.dashcam.ui.components.HeroHeader
import com.lanesync.dashcam.ui.components.SectionHeader
import com.lanesync.dashcam.ui.components.SafetyScoreRing
import com.lanesync.dashcam.ui.components.StatCard
import com.lanesync.dashcam.ui.components.StatusPill
import com.lanesync.dashcam.ui.theme.LaneSyncColors

@Composable
fun HomeScreen(
  state: DashcamUiState,
  vm: DashcamViewModel,
  onOpenClips: () -> Unit,
  onOpenDrive: () -> Unit = {},
  onOpenSafety: () -> Unit = {},
  modifier: Modifier = Modifier,
) {
  LazyColumn(
    modifier = modifier.fillMaxSize(),
    contentPadding = PaddingValues(16.dp),
    verticalArrangement = Arrangement.spacedBy(16.dp),
  ) {
    item {
      HeroHeader(
        title = "Pilot",
        subtitle = "Dashcam, V2I & nav — synced to the cloud",
      )
    }

    if (state.isDemoMode) {
      item {
        DemoBanner("Preview mode · ${LaneSyncConfig.CLOUD_URL} launching soon")
      }
    }

    item {
      Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        StatusPill(
          text = if (state.deviceOnline) "Device online" else "Device offline",
          active = state.deviceOnline,
        )
        StatusPill(
          text = if (state.isSignedIn) "Signed in" else "Guest",
          active = state.isSignedIn,
        )
        StatusPill(text = state.networkCarrier, active = true)
      }
    }

    item {
      Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
        StatCard("Saved clips", state.clipsSynced.toString(), Modifier.weight(1f))
        StatCard("Safety score", state.safetyScore.overall.toString(), Modifier.weight(1f))
      }
    }

    item {
      Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
        QuickActionCard(
          icon = { Icon(Icons.Default.Navigation, null, tint = LaneSyncColors.Green) },
          title = "Route",
          subtitle = state.activeRoute.destination,
          onClick = onOpenDrive,
          modifier = Modifier.weight(1f),
        )
        QuickActionCard(
          icon = { Icon(Icons.Default.Shield, null, tint = LaneSyncColors.Green) },
          title = "Safety",
          subtitle = "Score ${state.safetyScore.overall}",
          onClick = onOpenSafety,
          modifier = Modifier.weight(1f),
        )
      }
    }

    item {
      ActiveRoutePreview(state, onOpenDrive)
    }

    item {
      Card(
        onClick = onOpenSafety,
        shape = RoundedCornerShape(18.dp),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant),
      ) {
        Row(Modifier.padding(16.dp), verticalAlignment = Alignment.CenterVertically) {
          SafetyScoreRing(state.safetyScore, sizeDp = 90)
          Column(Modifier.padding(start = 16.dp)) {
            Text("Safety score", style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold)
            Text(
              "+${state.safetyScore.weekDelta} this week · Grade ${state.safetyScore.grade}",
              style = MaterialTheme.typography.bodySmall,
              color = LaneSyncColors.Green,
            )
            Text(
              "${state.trafficAnalytics.v2iMessages} V2I events · ${state.trafficAnalytics.redLightStops} red-light holds",
              style = MaterialTheme.typography.labelSmall,
              color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
          }
        }
      }
    }

    item {
      CloudStatusCard(state)
    }

    item {
      FeatureRow(
        icon = { Icon(Icons.Default.Traffic, null, tint = LaneSyncColors.Green) },
        title = "V2I",
        subtitle = if (state.v2iEnabled) "Traffic signals & hazards active" else "Disabled on device",
      )
    }

    item {
      FeatureRow(
        icon = { Icon(Icons.Default.Navigation, null, tint = LaneSyncColors.Green) },
        title = "Android Auto",
        subtitle = if (state.phoneNavEnabled) "Navigation bridge ready" else "Disabled on device",
      )
    }

    item {
      Row(
        Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically,
      ) {
        SectionHeader("Recent clips", "Bookmarked on your comma")
        Row(
          Modifier.clickable(onClick = onOpenClips),
          verticalAlignment = Alignment.CenterVertically,
        ) {
          Text("See all", color = LaneSyncColors.Green, style = MaterialTheme.typography.labelLarge)
          Icon(Icons.Default.ChevronRight, null, tint = LaneSyncColors.Green)
        }
      }
    }

    if (state.loading) {
      item {
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.Center) {
          CircularProgressIndicator(color = LaneSyncColors.Green)
        }
      }
    } else if (state.clips.isEmpty()) {
      item {
        EmptyClipsHint(onRefresh = vm::refresh)
      }
    } else {
      item {
        LazyRow(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
          items(state.clips.take(4), key = { it.id }) { clip ->
            Card(
              modifier = Modifier.width(200.dp),
              shape = RoundedCornerShape(16.dp),
              onClick = { vm.play(clip) },
            ) {
              Column {
                ClipThumbnail(clip, modifier = Modifier.height(110.dp))
                Column(Modifier.padding(12.dp)) {
                  Text(clip.displayTitle(), style = MaterialTheme.typography.labelLarge, maxLines = 1)
                  Text(
                    clip.recordedAt,
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                  )
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
private fun QuickActionCard(
  icon: @Composable () -> Unit,
  title: String,
  subtitle: String,
  onClick: () -> Unit,
  modifier: Modifier = Modifier,
) {
  Card(
    onClick = onClick,
    modifier = modifier,
    shape = RoundedCornerShape(16.dp),
  ) {
    Column(Modifier.padding(14.dp)) {
      icon()
      Spacer(Modifier.height(8.dp))
      Text(title, style = MaterialTheme.typography.titleSmall, fontWeight = FontWeight.SemiBold)
      Text(subtitle, style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant, maxLines = 1)
    }
  }
}

@Composable
private fun ActiveRoutePreview(state: DashcamUiState, onOpen: () -> Unit) {
  val route = state.activeRoute
  Card(onClick = onOpen, shape = RoundedCornerShape(16.dp)) {
    Row(Modifier.padding(16.dp), verticalAlignment = Alignment.CenterVertically) {
      Icon(Icons.Default.DirectionsCar, null, tint = LaneSyncColors.Green)
      Column(Modifier.padding(start = 14.dp).weight(1f)) {
        Text("En route to ${route.destination}", style = MaterialTheme.typography.titleSmall, fontWeight = FontWeight.SemiBold)
        Text(
          "${route.etaMinutes} min · ${String.format("%.1f", route.distanceMiles)} mi · ${route.currentInstruction}",
          style = MaterialTheme.typography.bodySmall,
          color = MaterialTheme.colorScheme.onSurfaceVariant,
          maxLines = 1,
        )
      }
      Icon(Icons.Default.ChevronRight, null, tint = LaneSyncColors.Green)
    }
  }
}

@Composable
private fun CloudStatusCard(state: DashcamUiState) {
  Card(
    shape = RoundedCornerShape(16.dp),
    colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant),
  ) {
    Row(Modifier.padding(16.dp), verticalAlignment = Alignment.CenterVertically) {
      Icon(Icons.Default.Cloud, null, tint = LaneSyncColors.Green, modifier = Modifier.padding(end = 14.dp))
      Column(Modifier.weight(1f)) {
        Text("Cloud", style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold)
        Text(
          state.cloudUrl.removePrefix("https://"),
          style = MaterialTheme.typography.bodySmall,
          color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        Text(
          if (state.isDemoMode) "Demo sync — API not live yet" else "Connected",
          style = MaterialTheme.typography.labelMedium,
          color = if (state.isDemoMode) LaneSyncColors.Warning else LaneSyncColors.Green,
        )
      }
      Icon(Icons.Default.SignalCellularAlt, null, tint = MaterialTheme.colorScheme.onSurfaceVariant)
    }
  }
}

@Composable
private fun FeatureRow(
  icon: @Composable () -> Unit,
  title: String,
  subtitle: String,
) {
  Surface(
    shape = RoundedCornerShape(14.dp),
    color = MaterialTheme.colorScheme.surface,
    tonalElevation = 1.dp,
  ) {
    Row(Modifier.padding(14.dp), verticalAlignment = Alignment.CenterVertically) {
      icon()
      Spacer(Modifier.width(14.dp))
      Column {
        Text(title, style = MaterialTheme.typography.titleSmall, fontWeight = FontWeight.SemiBold)
        Text(subtitle, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
      }
    }
  }
}

@Composable
private fun EmptyClipsHint(onRefresh: () -> Unit) {
  Card(
    onClick = onRefresh,
    shape = RoundedCornerShape(16.dp),
    colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant),
  ) {
    Row(Modifier.padding(20.dp), verticalAlignment = Alignment.CenterVertically) {
      Icon(Icons.Default.Videocam, null, tint = LaneSyncColors.Green)
      Spacer(Modifier.width(14.dp))
      Column {
        Text("No clips yet", style = MaterialTheme.typography.titleSmall)
        Text(
          "Tap to load demo clips or bookmark on your comma",
          style = MaterialTheme.typography.bodySmall,
          color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
      }
    }
  }
}
