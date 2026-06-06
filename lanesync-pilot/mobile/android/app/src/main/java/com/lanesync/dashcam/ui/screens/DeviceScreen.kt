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
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.DirectionsCar
import androidx.compose.material.icons.filled.Link
import androidx.compose.material.icons.filled.Router
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.lanesync.dashcam.DashcamUiState
import com.lanesync.dashcam.DashcamViewModel
import com.lanesync.dashcam.LaneSyncConfig
import com.lanesync.dashcam.ui.components.DemoBanner
import com.lanesync.dashcam.ui.components.SectionHeader
import com.lanesync.dashcam.ui.components.StatusPill
import com.lanesync.dashcam.ui.theme.LaneSyncColors

@Composable
fun DeviceScreen(
  state: DashcamUiState,
  vm: DashcamViewModel,
  modifier: Modifier = Modifier,
) {
  var showAdvanced by rememberSaveable { mutableStateOf(false) }

  LazyColumn(
    modifier = modifier.fillMaxSize(),
    contentPadding = PaddingValues(16.dp),
    verticalArrangement = Arrangement.spacedBy(16.dp),
  ) {
    item {
      SectionHeader("Link device", "Pair your comma with the LaneSync cloud")
    }

    if (state.isDemoMode) {
      item { DemoBanner("Pairing is simulated until ${LaneSyncConfig.CLOUD_URL} is live") }
    }

    item {
      Card(
        shape = RoundedCornerShape(20.dp),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant),
      ) {
        Column(Modifier.padding(20.dp), horizontalAlignment = Alignment.CenterHorizontally) {
          Icon(
            Icons.Default.DirectionsCar,
            contentDescription = null,
            tint = LaneSyncColors.Green,
            modifier = Modifier.size(48.dp),
          )
          Spacer(Modifier.height(12.dp))
          Text(state.deviceName, style = MaterialTheme.typography.headlineSmall, fontWeight = FontWeight.Bold)
          Spacer(Modifier.height(8.dp))
          Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            StatusPill(
              text = if (state.deviceOnline) "Online" else "Offline",
              active = state.deviceOnline,
            )
            if (state.deviceOnline) {
              Icon(Icons.Default.CheckCircle, null, tint = LaneSyncColors.Green, modifier = Modifier.size(20.dp))
            }
          }
          Spacer(Modifier.height(6.dp))
          Text(
            "Dongle ${state.dongleId}",
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
          )
        }
      }
    }

    item {
      OutlinedTextField(
        value = state.deviceName,
        onValueChange = vm::updateDeviceName,
        label = { Text("Device name") },
        modifier = Modifier.fillMaxWidth(),
        singleLine = true,
        shape = RoundedCornerShape(14.dp),
      )
    }

    item {
      OutlinedTextField(
        value = state.dongleId,
        onValueChange = vm::updateDongleId,
        label = { Text("Dongle ID") },
        modifier = Modifier.fillMaxWidth(),
        singleLine = true,
        shape = RoundedCornerShape(14.dp),
      )
    }

    item {
      OutlinedTextField(
        value = state.cloudUrl,
        onValueChange = vm::updateCloudUrl,
        label = { Text("Cloud URL") },
        modifier = Modifier.fillMaxWidth(),
        singleLine = true,
        shape = RoundedCornerShape(14.dp),
        supportingText = { Text("Default: app.lanesyncpilot.ai") },
      )
    }

    item {
      Button(
        onClick = vm::pairDevice,
        modifier = Modifier.fillMaxWidth().height(52.dp),
        shape = RoundedCornerShape(14.dp),
        colors = ButtonDefaults.buttonColors(containerColor = LaneSyncColors.Green, contentColor = LaneSyncColors.Background),
        enabled = !state.loading,
      ) {
        if (state.loading) {
          CircularProgressIndicator(modifier = Modifier.size(22.dp), color = LaneSyncColors.Background)
        } else {
          Icon(Icons.Default.Link, null, modifier = Modifier.padding(end = 8.dp))
          Text("Link to cloud", fontWeight = FontWeight.SemiBold)
        }
      }
    }

    item {
      Card(
        onClick = { showAdvanced = !showAdvanced },
        shape = RoundedCornerShape(14.dp),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
      ) {
        Row(Modifier.padding(16.dp), verticalAlignment = Alignment.CenterVertically) {
          Icon(Icons.Default.Router, null, tint = MaterialTheme.colorScheme.onSurfaceVariant)
          Column(Modifier.padding(start = 14.dp).weight(1f)) {
            Text("Direct comma access", style = MaterialTheme.typography.titleSmall)
            Text(
              if (showAdvanced) "Hotspot fallback when cloud is unavailable" else "Tap for advanced settings",
              style = MaterialTheme.typography.bodySmall,
              color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
          }
        }
      }
    }

    if (showAdvanced) {
      item {
        OutlinedTextField(
          value = state.deviceUrl,
          onValueChange = vm::updateDeviceUrl,
          label = { Text("Local dashcam API") },
          modifier = Modifier.fillMaxWidth(),
          singleLine = true,
          shape = RoundedCornerShape(14.dp),
          supportingText = { Text("Comma hotspot: 192.168.43.1:7720") },
        )
      }
      item {
        OutlinedTextField(
          value = state.token,
          onValueChange = vm::updateToken,
          label = { Text("API token (optional)") },
          modifier = Modifier.fillMaxWidth(),
          singleLine = true,
          shape = RoundedCornerShape(14.dp),
        )
      }
    }
  }
}
