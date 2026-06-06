package com.lanesync.dashcam.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowUpward
import androidx.compose.material.icons.filled.SubdirectoryArrowLeft
import androidx.compose.material.icons.filled.SubdirectoryArrowRight
import androidx.compose.material.icons.filled.Flag
import androidx.compose.material.icons.filled.Merge
import androidx.compose.material.icons.filled.MyLocation
import androidx.compose.material.icons.filled.Navigation
import androidx.compose.material.icons.filled.Speed
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
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
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.lanesync.dashcam.DashcamUiState
import com.lanesync.dashcam.ManeuverType
import com.lanesync.dashcam.RouteManeuver
import com.lanesync.dashcam.ui.components.DemoBanner
import com.lanesync.dashcam.ui.components.SectionHeader
import com.lanesync.dashcam.ui.theme.LaneSyncColors

@Composable
fun RouteFollowerScreen(
  state: DashcamUiState,
  modifier: Modifier = Modifier,
) {
  val route = state.activeRoute

  LazyColumn(
    modifier = modifier.fillMaxSize(),
    contentPadding = PaddingValues(16.dp),
    verticalArrangement = Arrangement.spacedBy(14.dp),
  ) {
    item {
      SectionHeader("Route follower", "Live nav from Android Auto & comma")
    }

    if (state.isDemoMode) {
      item { DemoBanner("Sample route — syncs with Android Auto when cloud is live") }
    }

    item {
      RouteMapCard(route.progress, route.origin, route.destination)
    }

    item {
      TurnCard(
        instruction = route.currentInstruction,
        distance = route.distanceToTurn,
        type = ManeuverType.TURN_RIGHT,
        next = route.nextInstruction,
      )
    }

    item {
      Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
        TripStatCard("ETA", "${route.etaMinutes} min", Modifier.weight(1f))
        TripStatCard("Distance", String.format("%.1f mi", route.distanceMiles), Modifier.weight(1f))
        TripStatCard("Progress", "${(route.progress * 100).toInt()}%", Modifier.weight(1f))
      }
    }

    item {
      SpeedCard(
        current = route.currentSpeedMph,
        limit = route.speedLimitMph,
      )
    }

    item {
      Text("Upcoming", style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold)
    }

    items(route.maneuvers, key = { it.instruction }) { maneuver ->
      ManeuverRow(maneuver)
    }
  }
}

@Composable
private fun RouteMapCard(progress: Float, origin: String, destination: String) {
  Card(
    shape = RoundedCornerShape(20.dp),
    colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant),
  ) {
    Column(Modifier.padding(16.dp)) {
      Box(
        Modifier
          .fillMaxWidth()
          .height(120.dp)
          .clip(RoundedCornerShape(14.dp))
          .background(
            Brush.linearGradient(
              listOf(
                LaneSyncColors.SurfaceHigh,
                LaneSyncColors.GreenDark.copy(alpha = 0.4f),
                LaneSyncColors.Background,
              ),
            ),
          ),
      ) {
        Box(
          Modifier
            .align(Alignment.CenterStart)
            .padding(start = 16.dp)
            .size(10.dp)
            .clip(CircleShape)
            .background(LaneSyncColors.Green),
        )
        Box(
          Modifier
            .align(Alignment.CenterEnd)
            .padding(end = 16.dp)
            .size(10.dp)
            .clip(CircleShape)
            .background(LaneSyncColors.GreenGlow),
        )
        Box(
          Modifier
            .align(Alignment.Center)
            .fillMaxWidth(progress.coerceIn(0.05f, 1f))
            .height(4.dp)
            .background(LaneSyncColors.Green.copy(alpha = 0.35f)),
        )
        Icon(
          Icons.Default.Navigation,
          null,
          tint = LaneSyncColors.Green,
          modifier = Modifier
            .align(Alignment.CenterStart)
            .padding(start = (progress.coerceIn(0f, 1f) * 240f).dp + 8.dp)
            .size(28.dp)
            .background(MaterialTheme.colorScheme.surface, CircleShape)
            .padding(4.dp),
        )
      }
      Spacer(Modifier.height(12.dp))
      Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
        Column {
          Text(origin, style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
          Text("Origin", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
        Column(horizontalAlignment = Alignment.End) {
          Text(destination, style = MaterialTheme.typography.labelLarge, fontWeight = FontWeight.SemiBold)
          Text("Destination", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
      }
      Spacer(Modifier.height(10.dp))
      LinearProgressIndicator(
        progress = { progress },
        modifier = Modifier.fillMaxWidth(),
        color = LaneSyncColors.Green,
      )
    }
  }
}

@Composable
private fun TurnCard(
  instruction: String,
  distance: String,
  type: ManeuverType,
  next: String,
) {
  Card(
    shape = RoundedCornerShape(18.dp),
    colors = CardDefaults.cardColors(containerColor = LaneSyncColors.Green.copy(alpha = 0.12f)),
  ) {
    Row(Modifier.padding(18.dp), verticalAlignment = Alignment.CenterVertically) {
      Surface(
        shape = RoundedCornerShape(14.dp),
        color = LaneSyncColors.Green.copy(alpha = 0.25f),
      ) {
        Icon(
          maneuverIcon(type),
          null,
          tint = LaneSyncColors.Green,
          modifier = Modifier.padding(14.dp).size(32.dp),
        )
      }
      Spacer(Modifier.width(16.dp))
      Column(Modifier.weight(1f)) {
        Text(distance, style = MaterialTheme.typography.labelLarge, color = LaneSyncColors.Green, fontWeight = FontWeight.Bold)
        Text(instruction, style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold)
        Text("Then $next", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
      }
    }
  }
}

@Composable
private fun TripStatCard(label: String, value: String, modifier: Modifier = Modifier) {
  Card(
    modifier = modifier,
    shape = RoundedCornerShape(14.dp),
    colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
  ) {
    Column(Modifier.padding(14.dp), horizontalAlignment = Alignment.CenterHorizontally) {
      Text(value, style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold)
      Text(label, style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
    }
  }
}

@Composable
private fun SpeedCard(current: Int, limit: Int) {
  val over = current > limit
  Card(shape = RoundedCornerShape(14.dp)) {
    Row(Modifier.padding(16.dp), verticalAlignment = Alignment.CenterVertically) {
      Icon(Icons.Default.Speed, null, tint = if (over) LaneSyncColors.Warning else LaneSyncColors.Green)
      Spacer(Modifier.width(12.dp))
      Column(Modifier.weight(1f)) {
        Text("Speed", style = MaterialTheme.typography.titleSmall)
        Text(
          "$current mph · limit $limit",
          style = MaterialTheme.typography.bodySmall,
          color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
      }
      if (over) {
        Text("Advisory", color = LaneSyncColors.Warning, style = MaterialTheme.typography.labelMedium)
      }
    }
  }
}

@Composable
private fun ManeuverRow(maneuver: RouteManeuver) {
  val alpha = if (maneuver.completed) 0.45f else 1f
  Row(
    Modifier
      .fillMaxWidth()
      .padding(vertical = 4.dp),
    verticalAlignment = Alignment.CenterVertically,
  ) {
    Icon(
      maneuverIcon(maneuver.icon),
      null,
      tint = if (maneuver.completed) MaterialTheme.colorScheme.onSurfaceVariant else LaneSyncColors.Green,
      modifier = Modifier.size(22.dp),
    )
    Spacer(Modifier.width(12.dp))
    Column(Modifier.weight(1f)) {
      Text(
        maneuver.instruction,
        style = MaterialTheme.typography.bodyMedium,
        color = MaterialTheme.colorScheme.onSurface.copy(alpha = alpha),
      )
      Text(maneuver.distance, style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
    }
    if (!maneuver.completed && maneuver.icon != ManeuverType.DEPART) {
      Icon(Icons.Default.MyLocation, null, tint = LaneSyncColors.Green, modifier = Modifier.size(16.dp))
    }
  }
}

private fun maneuverIcon(type: ManeuverType): ImageVector = when (type) {
  ManeuverType.TURN_LEFT -> Icons.Default.SubdirectoryArrowLeft
  ManeuverType.TURN_RIGHT -> Icons.Default.SubdirectoryArrowRight
  ManeuverType.MERGE -> Icons.Default.Merge
  ManeuverType.ARRIVE -> Icons.Default.Flag
  else -> Icons.Default.ArrowUpward
}
