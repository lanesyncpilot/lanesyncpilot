package com.lanesync.dashcam

data class RouteManeuver(
  val instruction: String,
  val distance: String,
  val icon: ManeuverType,
  val completed: Boolean = false,
)

enum class ManeuverType { DEPART, STRAIGHT, TURN_RIGHT, TURN_LEFT, MERGE, ARRIVE }

data class ActiveRoute(
  val active: Boolean,
  val destination: String,
  val origin: String,
  val etaMinutes: Int,
  val distanceMiles: Float,
  val progress: Float,
  val currentInstruction: String,
  val distanceToTurn: String,
  val nextInstruction: String,
  val speedLimitMph: Int,
  val currentSpeedMph: Int,
  val maneuvers: List<RouteManeuver>,
)

data class SafetyScore(
  val overall: Int,
  val smoothness: Int,
  val attention: Int,
  val compliance: Int,
  val weekDelta: Int,
  val grade: String,
)

data class SafetyAlert(
  val id: String,
  val title: String,
  val detail: String,
  val severity: AlertSeverity,
  val timeAgo: String,
)

enum class AlertSeverity { INFO, WARNING, CRITICAL }

data class DayTrafficStat(
  val label: String,
  val redLights: Int,
  val advisories: Int,
  val hazards: Int,
)

data class TrafficAnalytics(
  val redLightStops: Int,
  val speedAdvisories: Int,
  val hazardsDetected: Int,
  val v2iMessages: Int,
  val weeklyDriveHours: Float,
  val avgCongestion: Int,
  val dailyStats: List<DayTrafficStat>,
)

object MockSafetyData {
  fun activeRoute() = ActiveRoute(
    active = true,
    destination = "Stanford University",
    origin = "San Jose",
    etaMinutes = 18,
    distanceMiles = 12.4f,
    progress = 0.42f,
    currentInstruction = "Turn right onto Alma St",
    distanceToTurn = "350 ft",
    nextInstruction = "Continue 1.2 mi on Alma St",
    speedLimitMph = 35,
    currentSpeedMph = 32,
    maneuvers = listOf(
      RouteManeuver("Depart San Jose", "0 mi", ManeuverType.DEPART, completed = true),
      RouteManeuver("Merge onto US-101 N", "2.1 mi", ManeuverType.MERGE, completed = true),
      RouteManeuver("Take exit 402 toward Palo Alto", "8.4 mi", ManeuverType.STRAIGHT, completed = true),
      RouteManeuver("Turn right onto Alma St", "350 ft", ManeuverType.TURN_RIGHT, completed = false),
      RouteManeuver("Turn left onto Stanford Ave", "1.2 mi", ManeuverType.TURN_LEFT, completed = false),
      RouteManeuver("Arrive at Stanford University", "0.3 mi", ManeuverType.ARRIVE, completed = false),
    ),
  )

  fun safetyScore() = SafetyScore(
    overall = 87,
    smoothness = 92,
    attention = 85,
    compliance = 88,
    weekDelta = 3,
    grade = "A",
  )

  fun safetyAlerts() = listOf(
    SafetyAlert(
      id = "1",
      title = "Hard brake event",
      detail = "Detected on I-280 S near Woodside Rd",
      severity = AlertSeverity.WARNING,
      timeAgo = "2h ago",
    ),
    SafetyAlert(
      id = "2",
      title = "Red light hold",
      detail = "V2I held at green wave — Sand Hill Rd",
      severity = AlertSeverity.INFO,
      timeAgo = "Yesterday",
    ),
    SafetyAlert(
      id = "3",
      title = "Forward collision warning",
      detail = "Openpilot FCW triggered — resolved",
      severity = AlertSeverity.CRITICAL,
      timeAgo = "Jun 3",
    ),
  )

  fun trafficAnalytics() = TrafficAnalytics(
    redLightStops = 12,
    speedAdvisories = 8,
    hazardsDetected = 3,
    v2iMessages = 47,
    weeklyDriveHours = 14.2f,
    avgCongestion = 34,
    dailyStats = listOf(
      DayTrafficStat("Mon", 2, 1, 0),
      DayTrafficStat("Tue", 3, 2, 1),
      DayTrafficStat("Wed", 1, 0, 0),
      DayTrafficStat("Thu", 2, 2, 0),
      DayTrafficStat("Fri", 4, 2, 1),
      DayTrafficStat("Sat", 0, 1, 1),
      DayTrafficStat("Sun", 0, 0, 0),
    ),
  )
}
