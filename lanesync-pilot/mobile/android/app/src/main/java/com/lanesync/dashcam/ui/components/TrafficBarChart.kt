package com.lanesync.dashcam.ui.components

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import com.lanesync.dashcam.DayTrafficStat
import com.lanesync.dashcam.ui.theme.LaneSyncColors

@Composable
fun TrafficBarChart(
  stats: List<DayTrafficStat>,
  modifier: Modifier = Modifier,
) {
  val maxValue = stats.maxOfOrNull { it.redLights + it.advisories + it.hazards }?.coerceAtLeast(1) ?: 1

  Column(modifier) {
    Canvas(Modifier.fillMaxWidth().height(140.dp).padding(vertical = 8.dp)) {
      val barCount = stats.size
      val gap = size.width * 0.04f
      val barWidth = (size.width - gap * (barCount + 1)) / barCount
      val chartHeight = size.height - 20.dp.toPx()

      stats.forEachIndexed { index, day ->
        val total = day.redLights + day.advisories + day.hazards
        val barHeight = (total.toFloat() / maxValue) * chartHeight
        val x = gap + index * (barWidth + gap)
        val y = size.height - barHeight - 16.dp.toPx()

        var stackY = y + barHeight
        val segments = listOf(
          day.redLights to LaneSyncColors.Error.copy(alpha = 0.85f),
          day.advisories to LaneSyncColors.Warning.copy(alpha = 0.85f),
          day.hazards to LaneSyncColors.Green.copy(alpha = 0.85f),
        )
        segments.forEach { (value, color) ->
          if (value <= 0) return@forEach
          val segH = (value.toFloat() / maxValue) * chartHeight
          stackY -= segH
          drawRoundRect(
            color = color,
            topLeft = Offset(x, stackY),
            size = Size(barWidth, segH),
            cornerRadius = CornerRadius(4.dp.toPx(), 4.dp.toPx()),
          )
        }
      }
    }
    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
      stats.forEach { day ->
        Text(
          day.label,
          style = MaterialTheme.typography.labelSmall,
          color = MaterialTheme.colorScheme.onSurfaceVariant,
          modifier = Modifier.weight(1f),
        )
      }
    }
    Row(
      Modifier.fillMaxWidth().padding(top = 10.dp),
      horizontalArrangement = Arrangement.spacedBy(16.dp),
    ) {
      ChartLegend("Red lights", LaneSyncColors.Error)
      ChartLegend("Advisories", LaneSyncColors.Warning)
      ChartLegend("Hazards", LaneSyncColors.Green)
    }
  }
}

@Composable
private fun ChartLegend(label: String, color: Color) {
  Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
    Box(Modifier.size(8.dp).background(color, CircleShape))
    Text(label, style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
  }
}
