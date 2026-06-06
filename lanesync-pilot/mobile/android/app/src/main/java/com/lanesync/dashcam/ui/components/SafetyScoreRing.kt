package com.lanesync.dashcam.ui.components

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.size
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.lanesync.dashcam.SafetyScore
import com.lanesync.dashcam.ui.theme.LaneSyncColors

@Composable
fun SafetyScoreRing(
  score: SafetyScore,
  modifier: Modifier = Modifier,
  sizeDp: Int = 160,
) {
  val trackColor = MaterialTheme.colorScheme.surfaceVariant
  val progress = score.overall / 100f
  val ringColor = when {
    score.overall >= 90 -> LaneSyncColors.Green
    score.overall >= 75 -> LaneSyncColors.GreenGlow
    score.overall >= 60 -> LaneSyncColors.Warning
    else -> LaneSyncColors.Error
  }

  Box(modifier.size(sizeDp.dp), contentAlignment = Alignment.Center) {
    Canvas(Modifier.size(sizeDp.dp)) {
      val stroke = 14.dp.toPx()
      drawArc(
        color = trackColor,
        startAngle = 135f,
        sweepAngle = 270f,
        useCenter = false,
        style = Stroke(width = stroke, cap = StrokeCap.Round),
      )
      drawArc(
        color = ringColor,
        startAngle = 135f,
        sweepAngle = 270f * progress,
        useCenter = false,
        style = Stroke(width = stroke, cap = StrokeCap.Round),
      )
    }
    Column(horizontalAlignment = Alignment.CenterHorizontally) {
      Text(
        score.overall.toString(),
        fontSize = 36.sp,
        fontWeight = FontWeight.Bold,
        color = MaterialTheme.colorScheme.onSurface,
      )
      Text(
        "Grade ${score.grade}",
        style = MaterialTheme.typography.labelMedium,
        color = ringColor,
      )
    }
  }
}

@Composable
fun ScoreBar(label: String, value: Int, modifier: Modifier = Modifier) {
  Column(modifier) {
    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
      Text(label, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
      Text("$value", style = MaterialTheme.typography.labelLarge, fontWeight = FontWeight.SemiBold)
    }
    Spacer(Modifier.height(4.dp))
    LinearProgressIndicator(
      progress = { value / 100f },
      modifier = Modifier.fillMaxWidth(),
      color = LaneSyncColors.Green,
      trackColor = MaterialTheme.colorScheme.surfaceVariant,
    )
  }
}
