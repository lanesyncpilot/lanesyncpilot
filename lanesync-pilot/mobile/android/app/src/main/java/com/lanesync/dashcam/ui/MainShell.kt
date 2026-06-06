package com.lanesync.dashcam.ui

import android.app.Application
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.DarkMode
import androidx.compose.material.icons.filled.Home
import androidx.compose.material.icons.filled.LightMode
import androidx.compose.material.icons.filled.Navigation
import androidx.compose.material.icons.filled.Person
import androidx.compose.material.icons.filled.Shield
import androidx.compose.material.icons.filled.Videocam
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.NavigationBarItemDefaults
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Snackbar
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.navigation.NavGraph.Companion.findStartDestination
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController
import com.lanesync.dashcam.DashcamViewModel
import com.lanesync.dashcam.ThemeMode
import com.lanesync.dashcam.ui.navigation.AppDestination
import com.lanesync.dashcam.ui.screens.AccountScreen
import com.lanesync.dashcam.ui.screens.ClipsScreen
import com.lanesync.dashcam.ui.screens.HomeScreen
import com.lanesync.dashcam.ui.screens.RouteFollowerScreen
import com.lanesync.dashcam.ui.screens.SafetyCenterScreen
import com.lanesync.dashcam.ui.theme.LaneSyncColors
import com.lanesync.dashcam.ui.theme.LaneSyncTheme

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun MainShell() {
  val app = LocalContext.current.applicationContext as Application
  val vm: DashcamViewModel = viewModel(factory = DashcamViewModel.factory(app))
  val state by vm.state.collectAsState()

  LaneSyncTheme(themeMode = state.themeMode) {
    MainShellContent(vm = vm, state = state)
  }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun MainShellContent(
  vm: DashcamViewModel,
  state: com.lanesync.dashcam.DashcamUiState,
) {
  val navController = rememberNavController()
  val snackbarHostState = remember { SnackbarHostState() }
  val navBackStackEntry by navController.currentBackStackEntryAsState()
  val currentRoute = navBackStackEntry?.destination?.route ?: AppDestination.Home.route

  LaunchedEffect(state.error, state.infoMessage) {
    val message = state.error ?: state.infoMessage ?: return@LaunchedEffect
    snackbarHostState.showSnackbar(message)
    vm.dismissMessage()
  }

  val topBarTitle = when (currentRoute) {
    AppDestination.Home.route -> "LaneSync Pilot"
    AppDestination.Drive.route -> "Route follower"
    AppDestination.Safety.route -> "Safety center"
    AppDestination.Clips.route -> "Dashcam"
    AppDestination.Account.route -> "Account"
    else -> "LaneSync Pilot"
  }

  val themeIcon = when (state.themeMode) {
    ThemeMode.DARK -> Icons.Default.DarkMode
    ThemeMode.LIGHT -> Icons.Default.LightMode
    ThemeMode.SYSTEM -> Icons.Default.DarkMode
  }

  Scaffold(
    topBar = {
      TopAppBar(
        title = { Text(topBarTitle, fontWeight = FontWeight.SemiBold) },
        actions = {
          IconButton(onClick = vm::cycleThemeMode) {
            Icon(themeIcon, contentDescription = "Theme: ${state.themeMode.label}")
          }
        },
        colors = TopAppBarDefaults.topAppBarColors(
          containerColor = MaterialTheme.colorScheme.background,
          titleContentColor = MaterialTheme.colorScheme.onBackground,
        ),
      )
    },
    bottomBar = {
      NavigationBar(containerColor = MaterialTheme.colorScheme.surface) {
        AppDestination.entries.forEach { dest ->
          val selected = currentRoute == dest.route
          NavigationBarItem(
            selected = selected,
            onClick = {
              navController.navigate(dest.route) {
                popUpTo(navController.graph.findStartDestination().id) { saveState = true }
                launchSingleTop = true
                restoreState = true
              }
            },
            icon = {
              Icon(
                when (dest) {
                  AppDestination.Home -> Icons.Default.Home
                  AppDestination.Drive -> Icons.Default.Navigation
                  AppDestination.Safety -> Icons.Default.Shield
                  AppDestination.Clips -> Icons.Default.Videocam
                  AppDestination.Account -> Icons.Default.Person
                },
                contentDescription = dest.label,
              )
            },
            label = { Text(dest.label) },
            colors = NavigationBarItemDefaults.colors(
              selectedIconColor = LaneSyncColors.Green,
              selectedTextColor = LaneSyncColors.Green,
              indicatorColor = LaneSyncColors.Green.copy(alpha = 0.15f),
            ),
          )
        }
      }
    },
    snackbarHost = {
      SnackbarHost(snackbarHostState) { data ->
        Snackbar(
          snackbarData = data,
          containerColor = MaterialTheme.colorScheme.surfaceVariant,
          contentColor = MaterialTheme.colorScheme.onSurface,
        )
      }
    },
  ) { padding ->
    NavHost(
      navController = navController,
      startDestination = AppDestination.Home.route,
      modifier = Modifier.padding(padding),
    ) {
      composable(AppDestination.Home.route) {
        HomeScreen(
          state = state,
          vm = vm,
          onOpenClips = { navController.navigate(AppDestination.Clips.route) { launchSingleTop = true } },
          onOpenDrive = { navController.navigate(AppDestination.Drive.route) { launchSingleTop = true } },
          onOpenSafety = { navController.navigate(AppDestination.Safety.route) { launchSingleTop = true } },
        )
      }
      composable(AppDestination.Drive.route) {
        RouteFollowerScreen(state = state)
      }
      composable(AppDestination.Safety.route) {
        SafetyCenterScreen(state = state)
      }
      composable(AppDestination.Clips.route) {
        ClipsScreen(state = state, vm = vm)
      }
      composable(AppDestination.Account.route) {
        AccountScreen(state = state, vm = vm)
      }
    }
  }
}
