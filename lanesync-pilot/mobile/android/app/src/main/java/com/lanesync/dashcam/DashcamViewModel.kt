package com.lanesync.dashcam

import android.app.Application
import android.content.Context
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import java.io.File

enum class ClipFilter { ALL, SAVED, RECENT }

data class DashcamUiState(
  val cloudUrl: String = LaneSyncConfig.CLOUD_URL,
  val deviceUrl: String = LaneSyncConfig.LOCAL_DEVICE_URL,
  val token: String = "",
  val isDemoMode: Boolean = true,
  val isSignedIn: Boolean = false,
  val userEmail: String = "",
  val dongleId: String = "7c3b9f2a1e8d",
  val deviceName: String = "Comma 3X",
  val deviceOnline: Boolean = true,
  val clips: List<DashcamClip> = emptyList(),
  val clipFilter: ClipFilter = ClipFilter.ALL,
  val clipSearch: String = "",
  val loading: Boolean = false,
  val error: String? = null,
  val infoMessage: String? = null,
  val playingClip: DashcamClip? = null,
  val downloadingId: String? = null,
  val downloadProgress: Float = 0f,
  val lastSavedPath: String? = null,
  val v2iEnabled: Boolean = true,
  val phoneNavEnabled: Boolean = true,
  val networkCarrier: String = "T-Mobile",
  val clipsSynced: Int = 0,
  val themeMode: ThemeMode = ThemeMode.DARK,
  val activeRoute: ActiveRoute = MockSafetyData.activeRoute(),
  val safetyScore: SafetyScore = MockSafetyData.safetyScore(),
  val safetyAlerts: List<SafetyAlert> = MockSafetyData.safetyAlerts(),
  val trafficAnalytics: TrafficAnalytics = MockSafetyData.trafficAnalytics(),
)

class DashcamViewModel(app: Application) : AndroidViewModel(app) {
  companion object {
    fun factory(app: Application): ViewModelProvider.Factory = object : ViewModelProvider.Factory {
      @Suppress("UNCHECKED_CAST")
      override fun <T : ViewModel> create(modelClass: Class<T>): T {
        return DashcamViewModel(app) as T
      }
    }
  }

  private val api = DashcamApi()
  private val prefs = app.getSharedPreferences("lanesync_dashcam", Context.MODE_PRIVATE)

  private val _state = MutableStateFlow(
    DashcamUiState(
      cloudUrl = prefs.getString("cloud_url", LaneSyncConfig.CLOUD_URL) ?: LaneSyncConfig.CLOUD_URL,
      deviceUrl = prefs.getString("device_url", LaneSyncConfig.LOCAL_DEVICE_URL) ?: LaneSyncConfig.LOCAL_DEVICE_URL,
      token = prefs.getString("token", "") ?: "",
      dongleId = prefs.getString("dongle_id", "7c3b9f2a1e8d") ?: "7c3b9f2a1e8d",
      deviceName = prefs.getString("device_name", "Comma 3X") ?: "Comma 3X",
      isDemoMode = prefs.getBoolean("demo_mode", true),
      userEmail = prefs.getString("user_email", "") ?: "",
      isSignedIn = prefs.getBoolean("signed_in", false),
      themeMode = ThemeMode.entries.getOrElse(prefs.getInt("theme_mode", ThemeMode.DARK.ordinal)) { ThemeMode.DARK },
    )
  )
  val state: StateFlow<DashcamUiState> = _state.asStateFlow()

  init {
    if (_state.value.isDemoMode) {
      loadDemoClips()
    }
  }

  fun updateCloudUrl(url: String) {
    _state.update { it.copy(cloudUrl = url) }
    prefs.edit().putString("cloud_url", url).apply()
  }

  fun updateDeviceUrl(url: String) {
    _state.update { it.copy(deviceUrl = url) }
    prefs.edit().putString("device_url", url).apply()
  }

  fun updateToken(token: String) {
    _state.update { it.copy(token = token) }
    prefs.edit().putString("token", token).apply()
  }

  fun updateDongleId(id: String) {
    _state.update { it.copy(dongleId = id) }
    prefs.edit().putString("dongle_id", id).apply()
  }

  fun updateDeviceName(name: String) {
    _state.update { it.copy(deviceName = name) }
    prefs.edit().putString("device_name", name).apply()
  }

  fun updateClipSearch(query: String) {
    _state.update { it.copy(clipSearch = query) }
  }

  fun setClipFilter(filter: ClipFilter) {
    _state.update { it.copy(clipFilter = filter) }
  }

  fun dismissMessage() {
    _state.update { it.copy(error = null, infoMessage = null) }
  }

  fun setThemeMode(mode: ThemeMode) {
    _state.update { it.copy(themeMode = mode) }
    prefs.edit().putInt("theme_mode", mode.ordinal).apply()
  }

  fun cycleThemeMode() {
    val next = when (_state.value.themeMode) {
      ThemeMode.DARK -> ThemeMode.LIGHT
      ThemeMode.LIGHT -> ThemeMode.SYSTEM
      ThemeMode.SYSTEM -> ThemeMode.DARK
    }
    setThemeMode(next)
  }

  fun refresh() {
    val current = _state.value
    viewModelScope.launch {
      _state.update { it.copy(loading = true, error = null, infoMessage = null, lastSavedPath = null) }
      delay(600)
      if (current.isDemoMode) {
        val clips = MockDashcamData.clips(current.dongleId)
        _state.update {
          it.copy(
            loading = false,
            clips = clips,
            clipsSynced = clips.size,
            deviceOnline = true,
            infoMessage = "Demo data — ${LaneSyncConfig.CLOUD_URL} is not live yet",
          )
        }
        return@launch
      }
      try {
        val token = current.token.ifBlank { null }
        val base = current.cloudUrl.trimEnd('/')
        if (!api.health(base, token)) {
          throw IllegalStateException("Cannot reach ${current.cloudUrl}")
        }
        val clips = api.listClips(base, token)
        _state.update { it.copy(loading = false, clips = clips, clipsSynced = clips.size) }
      } catch (e: Exception) {
        _state.update {
          it.copy(
            loading = false,
            error = e.message ?: "Failed to sync with cloud",
            isDemoMode = true,
          )
        }
        loadDemoClips()
      }
    }
  }

  fun signIn(email: String, password: String) {
    viewModelScope.launch {
      _state.update { it.copy(loading = true, error = null) }
      delay(500)
      if (email.isBlank()) {
        _state.update { it.copy(loading = false, error = "Enter your email") }
        return@launch
      }
      prefs.edit()
        .putString("user_email", email)
        .putBoolean("signed_in", true)
        .apply()
      _state.update {
        it.copy(
          loading = false,
          isSignedIn = true,
          userEmail = email,
          infoMessage = "Signed in locally — cloud auth launches with app.lanesyncpilot.ai",
        )
      }
    }
  }

  fun signOut() {
    prefs.edit()
      .putBoolean("signed_in", false)
      .putString("user_email", "")
      .apply()
    _state.update { it.copy(isSignedIn = false, userEmail = "", infoMessage = "Signed out") }
  }

  fun pairDevice() {
    val current = _state.value
    viewModelScope.launch {
      _state.update { it.copy(loading = true, error = null) }
      delay(700)
      _state.update {
        it.copy(
          loading = false,
          deviceOnline = true,
          infoMessage = "${current.deviceName} linked to ${current.cloudUrl} (demo)",
        )
      }
      if (current.isDemoMode) loadDemoClips()
      else refresh()
    }
  }

  fun play(clip: DashcamClip) {
    _state.update { it.copy(playingClip = clip, error = null) }
  }

  fun stopPlayback() {
    _state.update { it.copy(playingClip = null) }
  }

  fun download(clip: DashcamClip) {
    if (_state.value.isDemoMode) {
      _state.update {
        it.copy(infoMessage = "Downloads will work once ${LaneSyncConfig.CLOUD_URL} is live")
      }
      return
    }
    val current = _state.value
    viewModelScope.launch {
      _state.update { it.copy(downloadingId = clip.id, downloadProgress = 0f, error = null) }
      try {
        val dir = File(getApplication<Application>().getExternalFilesDir(null), "saved_dashcams").apply { mkdirs() }
        val token = current.token.ifBlank { null }
        val file = api.downloadClip(current.cloudUrl, clip, dir, token) { p ->
          _state.update { it.copy(downloadProgress = p) }
        }
        _state.update { it.copy(downloadingId = null, downloadProgress = 1f, lastSavedPath = file.absolutePath) }
      } catch (e: Exception) {
        _state.update {
          it.copy(downloadingId = null, downloadProgress = 0f, error = e.message ?: "Download failed")
        }
      }
    }
  }

  fun filteredClips(): List<DashcamClip> {
    val s = _state.value
    var list = s.clips
    list = when (s.clipFilter) {
      ClipFilter.ALL -> list
      ClipFilter.SAVED -> list.filter { it.preserved }
      ClipFilter.RECENT -> list.take(3)
    }
    val q = s.clipSearch.trim().lowercase()
    if (q.isNotEmpty()) {
      list = list.filter {
        it.displayTitle().lowercase().contains(q) ||
          it.location.lowercase().contains(q) ||
          it.recordedAt.lowercase().contains(q)
      }
    }
    return list
  }

  private fun loadDemoClips() {
    val clips = MockDashcamData.clips(_state.value.dongleId)
    _state.update { it.copy(clips = clips, clipsSynced = clips.size, deviceOnline = true) }
  }
}
