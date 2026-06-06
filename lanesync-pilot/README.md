# LaneSync Pilot

**LaneSync Pilot** is an advanced open-source driver assistance platform based on openpilot, designed to bring Vehicle-to-Infrastructure (V2I) communication, navigation integration, and connected driving features directly to compatible vehicles.

Built on top of openpilot v0.11.0, LaneSync Pilot extends traditional ADAS functionality by allowing vehicles to interact with smart traffic infrastructure, receive real-time roadway information, and integrate turn-by-turn navigation from a connected mobile device.

---

## Overview

LaneSync Pilot combines:

* Advanced lane centering
* Adaptive cruise control support
* Navigation guidance
* Vehicle-to-Infrastructure communication
* Speed limit awareness
* Connected device services
* Future cloud dashcam capabilities

The goal is to create a safer, smarter, and more connected driving experience while maintaining compatibility with upstream openpilot releases whenever possible.

---

## Repository Structure

```text
V2I-for-Comma/
├── lanesync-pilot/
│
├── system/
│   ├── v2i/
│   │   ├── v2i_daemon.py
│   │   ├── signal_receiver.py
│   │   ├── speed_advisory.py
│   │   ├── hazard_alerts.py
│   │   └── phone_nav_bridge.py
│
├── tools/
│   ├── v2i/
│   │   ├── rsu_simulator.py
│   │   ├── intersection_simulator.py
│   │   ├── hud_preview.py
│   │   ├── ios_setup/
│   │   └── test_scenarios/
│
├── att/
│   ├── modem_profiles/
│   └── carrier_configs/
│
├── tmobile/
│   ├── modem_profiles/
│   └── carrier_configs/
│
├── verizon/
│   ├── modem_profiles/
│   └── carrier_configs/
│
├── docs/
│   ├── LANESYNC.md
│   ├── V2I.md
│   ├── NAVIGATION.md
│   ├── CONNECTIVITY.md
│   └── DEVELOPMENT.md
│
└── README.md
```

---

# Key Features

## Vehicle-to-Infrastructure (V2I)

LaneSync Pilot can communicate with roadside infrastructure systems to improve situational awareness and driving efficiency.

### Supported Data Types

* Traffic signal phase and timing (SPaT)
* Roadside unit (RSU) broadcasts
* Speed recommendations
* Construction alerts
* Hazard notifications
* School zones
* Emergency vehicle alerts
* Temporary road restrictions
* Lane closure information

### Driver Benefits

* Advance traffic light awareness
* Reduced stop-and-go traffic
* Improved speed planning
* Enhanced hazard visibility
* Better energy efficiency
* Smoother autonomous driving behavior

---

## Integrated Navigation

LaneSync Pilot includes a phone-to-device navigation bridge.

Supported sources include:

* Apple Maps
* Google Maps
* Waze
* Organic Maps
* OpenStreetMap-based navigation apps

Navigation data is transmitted from the phone to the comma device over a secure local Wi-Fi connection.

### Navigation Features

* Turn-by-turn instructions
* Lane guidance
* Route awareness
* ETA display
* Upcoming maneuver preview
* Navigation HUD integration
* Planner route assistance

---

## Speed Limit Intelligence

LaneSync Pilot continuously monitors roadway speed limits using multiple data sources.

### Sources

* OpenStreetMap
* Roadside speed sign detection
* Vehicle camera recognition
* Navigation map data
* Infrastructure broadcasts

### Features

* Automatic speed limit detection
* Smart cruise speed adjustments
* Speed limit display
* Upcoming speed zone warnings
* Construction speed zone awareness
* School zone support

---

## Connectivity Platform

LaneSync Pilot supports multiple methods of maintaining connectivity between the vehicle and mobile devices.

### Supported Connections

* Wi-Fi Hotspot
* USB Tethering
* Bluetooth Companion Link
* LTE Modems
* 5G Compatible Modems

### Carrier Profiles

Included carrier configurations:

* AT&T
* T-Mobile
* Verizon

Additional carrier profiles can be added through community contributions.

---

## Driver Assistance Enhancements

### Lane Centering

* Automated lane centering
* Highway support
* Curvature prediction
* Improved path planning

### Adaptive Cruise Control

* Automatic following distance
* Smooth acceleration profiles
* Traffic-aware speed control
* Stop-and-go support

### Navigation-Aware Driving

* Upcoming turn preparation
* Speed adjustments before turns
* Route-based lane positioning
* Intelligent maneuver handling

---

## Future Dashcam Platform

A cloud-connected dashcam system is currently under development.

### Planned Features

* Automatic drive uploads
* Secure encrypted storage
* Event-triggered clips
* Video downloads
* Shareable incident links
* Mobile app access

### Privacy

All uploaded footage will use:

* End-to-end encryption
* User-controlled retention
* Secure authentication
* Encrypted transport

### Storage Policy

* Videos stored for up to 7 days
* Manual downloads available
* Automatic expiration after retention period
* Optional future premium storage plans

---

# LaneSync Mobile App

A companion mobile application is planned for iOS and Android.

### Planned Features

* Navigation synchronization
* Device monitoring
* Drive history
* Dashcam access
* Vehicle status
* Remote updates
* Account management
* Cloud synchronization

---

# Installation

## Install During Device Setup

Enter the LaneSync Pilot installer URL during comma device onboarding.

---

## Manual Installation

```bash
cd /data

git clone https://github.com/yourusername/lanesync-pilot.git openpilot

cd openpilot

git checkout lanesync-main
```

Restart the device after installation.

---

# Configuration

Enable V2I:

```bash
params set V2IEnabled 1
```

Enable Navigation Bridge:

```bash
params set PhoneNavEnabled 1
```

Enable Speed Limit Following:

```bash
params set SpeedLimitControl 1
```

Enable Developer Tools:

```bash
params set LaneSyncDeveloperMode 1
```

---

# Device Settings

Navigate to:

```text
Settings
 └── LaneSync Pilot
      ├── V2I Settings
      ├── Navigation
      ├── Connectivity
      ├── Speed Limits
      ├── Dashcam
      ├── Developer Options
      └── About
```

---

# Version Information

| Component            | Version           |
| -------------------- | ----------------- |
| LaneSync Pilot       | 1.0.0             |
| Base Platform        | openpilot v0.11.0 |
| Navigation Bridge    | 1.0               |
| V2I System           | 1.0               |
| Connectivity Manager | 1.0               |

---

# Development Goals

### Phase 1

* V2I foundation
* Navigation bridge
* Speed limit support
* Carrier connectivity

### Phase 2

* Mobile applications
* Cloud dashboard
* Dashcam platform
* Fleet support

### Phase 3

* Smart city integrations
* Municipal traffic systems
* Infrastructure partnerships
* Advanced route optimization

---

# Credits

LaneSync Pilot is based on the outstanding work of the open-source community and the openpilot project.

Special thanks to:

* comma.ai
* The openpilot contributor community
* OpenStreetMap contributors
* V2I research organizations
* Smart transportation developers

---

# Disclaimer

LaneSync Pilot is experimental driver assistance software.

Drivers must remain attentive and responsible for vehicle operation at all times.

The software does not make the vehicle autonomous and should only be used in accordance with applicable laws and regulations.

Always keep your hands on the wheel and be prepared to take control immediately.
