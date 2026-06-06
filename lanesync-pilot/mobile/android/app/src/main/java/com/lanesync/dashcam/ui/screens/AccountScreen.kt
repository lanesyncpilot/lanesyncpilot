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
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Cloud
import androidx.compose.material.icons.filled.DarkMode
import androidx.compose.material.icons.filled.Email
import androidx.compose.material.icons.filled.LightMode
import androidx.compose.material.icons.filled.Link
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material.icons.filled.Person
import androidx.compose.material.icons.filled.PhoneAndroid
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.FilterChip
import androidx.compose.material3.FilterChipDefaults
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.unit.dp
import com.lanesync.dashcam.DashcamUiState
import com.lanesync.dashcam.DashcamViewModel
import com.lanesync.dashcam.LaneSyncConfig
import com.lanesync.dashcam.ThemeMode
import com.lanesync.dashcam.ui.components.DemoBanner
import com.lanesync.dashcam.ui.components.SectionHeader
import com.lanesync.dashcam.ui.theme.LaneSyncColors

@Composable
fun AccountScreen(
  state: DashcamUiState,
  vm: DashcamViewModel,
  modifier: Modifier = Modifier,
) {
  var email by rememberSaveable(state.userEmail) { mutableStateOf(state.userEmail) }
  var password by rememberSaveable { mutableStateOf("") }

  LazyColumn(
    modifier = modifier.fillMaxSize(),
    contentPadding = PaddingValues(16.dp),
    verticalArrangement = Arrangement.spacedBy(16.dp),
  ) {
    item {
      SectionHeader("Account", "Sign in to sync across devices")
    }

    item {
      DemoBanner("Auth UI ready — ${LaneSyncConfig.CLOUD_URL} backend coming soon")
    }

    item {
      Surface(
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(20.dp),
        color = MaterialTheme.colorScheme.surfaceVariant,
      ) {
        Column(
          Modifier.padding(24.dp),
          horizontalAlignment = Alignment.CenterHorizontally,
        ) {
          Surface(
            shape = CircleShape,
            color = LaneSyncColors.Green.copy(alpha = 0.2f),
            modifier = Modifier.size(72.dp),
          ) {
            Icon(
              Icons.Default.Person,
              contentDescription = null,
              tint = LaneSyncColors.Green,
              modifier = Modifier.padding(18.dp),
            )
          }
          Spacer(Modifier.height(12.dp))
          Text(
            if (state.isSignedIn) state.userEmail else "Guest",
            style = MaterialTheme.typography.titleMedium,
            fontWeight = FontWeight.SemiBold,
          )
          Text(
            if (state.isSignedIn) "Signed in locally" else "Sign in when cloud launches",
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
          )
        }
      }
    }

    if (!state.isSignedIn) {
      item {
        OutlinedTextField(
          value = email,
          onValueChange = { email = it },
          label = { Text("Email") },
          leadingIcon = { Icon(Icons.Default.Email, null) },
          modifier = Modifier.fillMaxWidth(),
          singleLine = true,
          shape = RoundedCornerShape(14.dp),
        )
      }
      item {
        OutlinedTextField(
          value = password,
          onValueChange = { password = it },
          label = { Text("Password") },
          leadingIcon = { Icon(Icons.Default.Lock, null) },
          visualTransformation = PasswordVisualTransformation(),
          modifier = Modifier.fillMaxWidth(),
          singleLine = true,
          shape = RoundedCornerShape(14.dp),
        )
      }
      item {
        Button(
          onClick = { vm.signIn(email, password) },
          modifier = Modifier.fillMaxWidth().height(52.dp),
          shape = RoundedCornerShape(14.dp),
          colors = ButtonDefaults.buttonColors(containerColor = LaneSyncColors.Green, contentColor = LaneSyncColors.Background),
          enabled = !state.loading,
        ) {
          if (state.loading) {
            CircularProgressIndicator(modifier = Modifier.size(22.dp), color = LaneSyncColors.Background)
          } else {
            Text("Sign in", fontWeight = FontWeight.SemiBold)
          }
        }
      }
    } else {
      item {
        OutlinedButton(
          onClick = vm::signOut,
          modifier = Modifier.fillMaxWidth().height(48.dp),
          shape = RoundedCornerShape(14.dp),
        ) {
          Text("Sign out")
        }
      }
    }

    item {
      SectionHeader("Appearance", "Dark mode & theme")
    }

    item {
      Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        ThemeMode.entries.forEach { mode ->
          FilterChip(
            selected = state.themeMode == mode,
            onClick = { vm.setThemeMode(mode) },
            label = { Text(mode.label) },
            leadingIcon = if (mode == ThemeMode.DARK) {
              { Icon(Icons.Default.DarkMode, null, Modifier.size(16.dp)) }
            } else if (mode == ThemeMode.LIGHT) {
              { Icon(Icons.Default.LightMode, null, Modifier.size(16.dp)) }
            } else null,
            colors = FilterChipDefaults.filterChipColors(
              selectedContainerColor = LaneSyncColors.Green.copy(alpha = 0.2f),
              selectedLabelColor = LaneSyncColors.Green,
            ),
          )
        }
      }
    }

    item {
      SectionHeader("Device", "Link your comma to the cloud")
    }

    item {
      OutlinedTextField(
        value = state.deviceName,
        onValueChange = vm::updateDeviceName,
        label = { Text("Device name") },
        leadingIcon = { Icon(Icons.Default.PhoneAndroid, null) },
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
      Button(
        onClick = vm::pairDevice,
        modifier = Modifier.fillMaxWidth().height(48.dp),
        shape = RoundedCornerShape(14.dp),
        colors = ButtonDefaults.buttonColors(containerColor = LaneSyncColors.Green, contentColor = LaneSyncColors.Background),
        enabled = !state.loading,
      ) {
        Icon(Icons.Default.Link, null, modifier = Modifier.padding(end = 8.dp))
        Text("Link device")
      }
    }

    item {
      Card(
        shape = RoundedCornerShape(16.dp),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
      ) {
        Row(Modifier.padding(16.dp), verticalAlignment = Alignment.CenterVertically) {
          Icon(Icons.Default.Cloud, null, tint = LaneSyncColors.Green)
          Column(Modifier.padding(start = 14.dp)) {
            Text("Cloud endpoint", style = MaterialTheme.typography.titleSmall)
            Text(
              state.cloudUrl,
              style = MaterialTheme.typography.bodySmall,
              color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
          }
        }
      }
    }

    item {
      Text(
        "LaneSync Pilot v${LaneSyncConfig.VERSION}",
        style = MaterialTheme.typography.labelMedium,
        color = MaterialTheme.colorScheme.onSurfaceVariant,
        modifier = Modifier.fillMaxWidth(),
      )
    }
  }
}
