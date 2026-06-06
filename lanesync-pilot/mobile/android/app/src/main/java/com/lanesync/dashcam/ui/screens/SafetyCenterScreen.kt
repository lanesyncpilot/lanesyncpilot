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
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowDownward
import androidx.compose.material.icons.filled.ArrowUpward
import androidx.compose.material.icons.filled.Report
import androidx.compose.material.icons.filled.Shield
import androidx.compose.material.icons.filled.Traffic
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.lanesync.dashcam.AlertSeverity
import com.lanesync.dashcam.DashcamUiState
import com.lanesync.dashcam.SafetyAlert
import com.lanesync.dashcam.ui.components.DemoBanner
import com.lanesync.dashcam.ui.components.SafetyScoreRing
import com.lanesync.dashcam.ui.components.ScoreBar
import com.lanesync.dashcam.ui.components.SectionHeader
import com.lanesync.dashcam.ui.components.StatCard
import com.lanesync.dashcam.ui.components.TrafficBarChart
import com.lanesync.dashcam.ui.theme.LaneSyncColors

@Composable
fun SafetyCenterScreen(
  state: DashcamUiState,
  modifier: Modifier = Modifier,
) {
  val score = state.safetyScore
  val analytics = state.trafficAnalytics

  LazyColumn(
    modifier = modifier.fillMaxSize(),
    contentPadding = PaddingValues(16.dp),
    verticalArrangement = Arrangement.spacedBy(16.dp),
  ) {
    item {
      SectionHeader("Safety center", "Score, alerts & V2I insights")
    }

    if (state.isDemoMode) {
      item { DemoBanner("Demo safety data — live when app.lanesyncpilot.ai launches") }
    }

    item {
      SafetyScoreCard(score)
    }

    item {
      Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
        StatCard("Smoothness", score.smoothness.toString(), Modifier.weight(1f))
        StatCard("Attention", score.attention.toString(), Modifier.weight(1f))
      }
    }

    item {
      Card(shape = RoundedCornerShape(18.dp)) {
        Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
          Text("Score breakdown", style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold)
          ScoreBar("Driving smoothness", score.smoothness)
          ScoreBar("Driver attention", score.attention)
          ScoreBar("Rule compliance", score.compliance)
        }
      }
    }

    item {
      SectionHeader("Traffic analytics", "V2I events this week")
    }

    item {
      Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
        AnalyticsPill(Icons.Default.Traffic, "Red lights", analytics.redLightStops.toString(), Modifier.weight(1f))
        AnalyticsPill(Icons.Default.Warning, "Advisories", analytics.speedAdvisories.toString(), Modifier.weight(1f))
      }
    }

    item {
      Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
        AnalyticsPill(Icons.Default.Report, "Hazards", analytics.hazardsDetected.toString(), Modifier.weight(1f))
        AnalyticsPill(Icons.Default.Shield, "V2I msgs", analytics.v2iMessages.toString(), Modifier.weight(1f))
      }
    }

    item {
      Card(shape = RoundedCornerShape(18.dp), colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant)) {
        Column(Modifier.padding(16.dp)) {
          Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
            Text("Weekly activity", style = MaterialTheme.typography.titleSmall, fontWeight = FontWeight.SemiBold)
            Text(
              "${analytics.weeklyDriveHours} hrs",
              style = MaterialTheme.typography.labelLarge,
              color = LaneSyncColors.Green,
            )
          }
          Spacer(Modifier.height(8.dp))
          TrafficBarChart(analytics.dailyStats)
        }
      }
    }

    item {
      Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween, verticalAlignment = Alignment.CenterVertically) {
        SectionHeader("Recent alerts")
        Text(
          "Congestion ${analytics.avgCongestion}%",
          style = MaterialTheme.typography.labelMedium,
          color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
      }
    }

    items(state.safetyAlerts, key = { it.id }) { alert ->
      AlertCard(alert)
    }
  }
}

@Composable
private fun SafetyScoreCard(score: com.lanesync.dashcam.SafetyScore) {
  Card(
    shape = RoundedCornerShape(20.dp),
    colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant),
  ) {
    Row(
      Modifier.padding(20.dp),
      verticalAlignment = Alignment.CenterVertically,
      horizontalArrangement = Arrangement.SpaceEvenly,
    ) {
      SafetyScoreRing(score)
      Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Text("Safety score", style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold)
        Row(verticalAlignment = Alignment.CenterVertically) {
          Icon(
            if (score.weekDelta >= 0) Icons.Default.ArrowUpward else Icons.Default.ArrowDownward,
            null,
            tint = if (score.weekDelta >= 0) LaneSyncColors.Green else LaneSyncColors.Error,
            modifier = Modifier.size(18.dp),
          )
          Text(
            "${if (score.weekDelta >= 0) "+" else ""}${score.weekDelta} vs last week",
            style = MaterialTheme.typography.bodySmall,
            color = if (score.weekDelta >= 0) LaneSyncColors.Green else LaneSyncColors.Error,
          )
        }
        Text(
          "Based on openpilot engagement, braking, and V2I compliance",
          style = MaterialTheme.typography.bodySmall,
          color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
      }
    }
  }
}

@Composable
private fun AnalyticsPill(
  icon: androidx.compose.ui.graphics.vector.ImageVector,
  label: String,
  value: String,
  modifier: Modifier = Modifier,
) {
  Card(modifier = modifier, shape = RoundedCornerShape(14.dp)) {
    Column(Modifier.padding(14.dp)) {
      Icon(icon, null, tint = LaneSyncColors.Green, modifier = Modifier.size(20.dp))
      Spacer(Modifier.height(6.dp))
      Text(value, style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold)
      Text(label, style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
    }
  }
}

@Composable
private fun AlertCard(alert: SafetyAlert) {
  val (color, icon) = when (alert.severity) {
    AlertSeverity.CRITICAL -> LaneSyncColors.Error to Icons.Default.Warning
    AlertSeverity.WARNING -> LaneSyncColors.Warning to Icons.Default.Report
    AlertSeverity.INFO -> LaneSyncColors.Green to Icons.Default.Shield
  }
  Surface(
    shape = RoundedCornerShape(14.dp),
    color = color.copy(alpha = 0.1f),
    modifier = Modifier.fillMaxWidth(),
  ) {
    Row(Modifier.padding(14.dp), verticalAlignment = Alignment.Top) {
      Icon(icon, null, tint = color, modifier = Modifier.size(22.dp))
      Column(Modifier.padding(start = 12.dp)) {
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
          Text(alert.title, style = MaterialTheme.typography.titleSmall, fontWeight = FontWeight.SemiBold)
          Text(alert.timeAgo, style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
        Text(alert.detail, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
      }
    }
  }
}
