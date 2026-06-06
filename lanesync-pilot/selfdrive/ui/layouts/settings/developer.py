from openpilot.common.params import Params
from openpilot.selfdrive.ui.widgets.ssh_key import ssh_key_item
from openpilot.selfdrive.ui.ui_state import ui_state
from openpilot.system.ui.widgets import Widget
from openpilot.system.ui.widgets.list_view import toggle_item
from openpilot.system.ui.widgets.scroller_tici import Scroller
from openpilot.system.ui.widgets.confirm_dialog import ConfirmDialog
from openpilot.system.ui.lib.application import gui_app
from openpilot.system.ui.lib.multilang import tr, tr_noop
from openpilot.system.ui.widgets import DialogResult

# Description constants
DESCRIPTIONS = {
  'enable_adb': tr_noop(
    "ADB (Android Debug Bridge) allows connecting to your device over USB or over the network. " +
    "See https://docs.comma.ai/how-to/connect-to-comma for more info."
  ),
  'ssh_key': tr_noop(
    "Warning: This grants SSH access to all public keys in your GitHub settings. Never enter a GitHub username " +
    "other than your own. A comma employee will NEVER ask you to add their GitHub username."
  ),
  'v2i': tr_noop(
    "Enable Vehicle-to-Infrastructure (V2I). Listens for RSU messages on UDP (default port 7701) " +
    "and shows traffic-signal state on the HUD. Requires an external RSU, simulator, or CARLA bridge."
  ),
  'phone_nav': tr_noop(
    "Receive navigation from your iPhone while using Apple CarPlay. Your phone sends destination and " +
    "turn-by-turn updates over Wi‑Fi to the comma device (HTTP port 7710). Set up the iOS Shortcut in " +
    "tools/v2i/ios/README.md."
  ),
  'att_dataplan': tr_noop(
    "Apply AT&T cellular APN from the att/ data plan folder and enable the Wi‑Fi hotspot so your iPhone " +
    "can connect for V2I and navigation. Requires an AT&T SIM; copy att/ to /data/att on the device."
  ),
  'tmobile_dataplan': tr_noop(
    "Apply T-Mobile cellular APN from the tmobile/ data plan folder and enable the Wi‑Fi hotspot so your iPhone " +
    "can connect for V2I and navigation. Requires a T-Mobile SIM; copy tmobile/ to /data/tmobile on the device."
  ),
  'verizon_dataplan': tr_noop(
    "Apply Verizon cellular APN from the verizon/ data plan folder and enable the Wi‑Fi hotspot so your iPhone " +
    "can connect for V2I and navigation. Requires a Verizon SIM; copy verizon/ to /data/verizon on the device."
  ),
  'v2i_wifi': tr_noop(
    "Keep Wi‑Fi enabled on the comma device so your iPhone (AT&T hotspot or home Wi‑Fi) can reach V2I and navigation services."
  ),
  'v2i_att': tr_noop(
    "Use AT&T cellular data on the comma LTE modem. Inserts the AT&T APN (nxtgenphone by default). Requires an AT&T SIM and active data plan."
  ),
  'v2i_tmobile': tr_noop(
    "Use T-Mobile cellular data on the comma LTE modem. Inserts the T-Mobile APN (fast.t-mobile.com by default). Requires a T-Mobile SIM and active data plan."
  ),
  'v2i_verizon': tr_noop(
    "Use Verizon cellular data on the comma LTE modem. Inserts the Verizon APN (vzwinternet by default). Requires a Verizon SIM and active data plan."
  ),
  'v2i_cellular': tr_noop(
    "Allow V2I and phone navigation traffic over LTE when Wi‑Fi is unavailable. Disables cellular metered mode for these services."
  ),
  'alpha_longitudinal': tr_noop(
    "<b>WARNING: openpilot longitudinal control is in alpha for this car and will disable Automatic Emergency Braking (AEB).</b><br><br>" +
    "On this car, openpilot defaults to the car's built-in ACC instead of openpilot's longitudinal control. " +
    "Enable this to switch to openpilot longitudinal control. Enabling Experimental mode is recommended when enabling openpilot longitudinal control alpha. " +
    "Changing this setting will restart openpilot if the car is powered on."
  ),
}


class DeveloperLayout(Widget):
  def __init__(self):
    super().__init__()
    self._params = Params()
    self._is_release = self._params.get_bool("IsReleaseBranch")

    # Build items and keep references for callbacks/state updates
    self._adb_toggle = toggle_item(
      lambda: tr("Enable ADB"),
      description=lambda: tr(DESCRIPTIONS["enable_adb"]),
      initial_state=self._params.get_bool("AdbEnabled"),
      callback=self._on_enable_adb,
      enabled=ui_state.is_offroad,
    )

    # SSH enable toggle + SSH key management
    self._ssh_toggle = toggle_item(
      lambda: tr("Enable SSH"),
      description="",
      initial_state=self._params.get_bool("SshEnabled"),
      callback=self._on_enable_ssh,
    )
    self._ssh_keys = ssh_key_item(lambda: tr("SSH Keys"), description=lambda: tr(DESCRIPTIONS["ssh_key"]))

    self._joystick_toggle = toggle_item(
      lambda: tr("Joystick Debug Mode"),
      description="",
      initial_state=self._params.get_bool("JoystickDebugMode"),
      callback=self._on_joystick_debug_mode,
      enabled=ui_state.is_offroad,
    )

    self._long_maneuver_toggle = toggle_item(
      lambda: tr("Longitudinal Maneuver Mode"),
      description="",
      initial_state=self._params.get_bool("LongitudinalManeuverMode"),
      callback=self._on_long_maneuver_mode,
    )

    self._alpha_long_toggle = toggle_item(
      lambda: tr("openpilot Longitudinal Control (Alpha)"),
      description=lambda: tr(DESCRIPTIONS["alpha_longitudinal"]),
      initial_state=self._params.get_bool("AlphaLongitudinalEnabled"),
      callback=self._on_alpha_long_enabled,
      enabled=lambda: not ui_state.engaged,
    )

    self._ui_debug_toggle = toggle_item(
      lambda: tr("UI Debug Mode"),
      description="",
      initial_state=self._params.get_bool("ShowDebugInfo"),
      callback=self._on_enable_ui_debug,
    )
    self._on_enable_ui_debug(self._params.get_bool("ShowDebugInfo"))

    self._v2i_toggle = toggle_item(
      lambda: tr("Vehicle-to-Infrastructure (V2I)"),
      description=lambda: tr(DESCRIPTIONS["v2i"]),
      initial_state=self._params.get_bool("V2IEnabled"),
      callback=self._on_v2i_enabled,
      enabled=ui_state.is_offroad,
    )

    self._phone_nav_toggle = toggle_item(
      lambda: tr("iPhone Navigation (CarPlay)"),
      description=lambda: tr(DESCRIPTIONS["phone_nav"]),
      initial_state=self._params.get_bool("PhoneNavEnabled"),
      callback=self._on_phone_nav_enabled,
      enabled=ui_state.is_offroad,
    )

    self._att_dataplan_toggle = toggle_item(
      lambda: tr("AT&T Data Plan + Wi‑Fi Hotspot"),
      description=lambda: tr(DESCRIPTIONS["att_dataplan"]),
      initial_state=self._params.get_bool("AttDataPlanEnabled"),
      callback=self._on_att_dataplan_enabled,
      enabled=ui_state.is_offroad,
    )

    self._tmobile_dataplan_toggle = toggle_item(
      lambda: tr("T-Mobile Data Plan + Wi‑Fi Hotspot"),
      description=lambda: tr(DESCRIPTIONS["tmobile_dataplan"]),
      initial_state=self._params.get_bool("TmobileDataPlanEnabled"),
      callback=self._on_tmobile_dataplan_enabled,
      enabled=ui_state.is_offroad,
    )

    self._verizon_dataplan_toggle = toggle_item(
      lambda: tr("Verizon Data Plan + Wi‑Fi Hotspot"),
      description=lambda: tr(DESCRIPTIONS["verizon_dataplan"]),
      initial_state=self._params.get_bool("VerizonDataPlanEnabled"),
      callback=self._on_verizon_dataplan_enabled,
      enabled=ui_state.is_offroad,
    )

    self._v2i_wifi_toggle = toggle_item(
      lambda: tr("V2I Wi‑Fi Always On"),
      description=lambda: tr(DESCRIPTIONS["v2i_wifi"]),
      initial_state=self._params.get_bool("V2IWifiEnabled"),
      callback=self._on_v2i_wifi,
      enabled=ui_state.is_offroad,
    )

    self._v2i_att_toggle = toggle_item(
      lambda: tr("AT&T Data Plan (LTE)"),
      description=lambda: tr(DESCRIPTIONS["v2i_att"]),
      initial_state=(self._params.get("V2ICarrier") or "") == "att",
      callback=self._on_v2i_att,
      enabled=ui_state.is_offroad,
    )

    self._v2i_tmobile_toggle = toggle_item(
      lambda: tr("T-Mobile Data Plan (LTE)"),
      description=lambda: tr(DESCRIPTIONS["v2i_tmobile"]),
      initial_state=(self._params.get("V2ICarrier") or "") == "tmobile",
      callback=self._on_v2i_tmobile,
      enabled=ui_state.is_offroad,
    )

    self._v2i_verizon_toggle = toggle_item(
      lambda: tr("Verizon Data Plan (LTE)"),
      description=lambda: tr(DESCRIPTIONS["v2i_verizon"]),
      initial_state=(self._params.get("V2ICarrier") or "") == "verizon",
      callback=self._on_v2i_verizon,
      enabled=ui_state.is_offroad,
    )

    self._v2i_cellular_toggle = toggle_item(
      lambda: tr("V2I Over Cellular"),
      description=lambda: tr(DESCRIPTIONS["v2i_cellular"]),
      initial_state=self._params.get_bool("V2IAllowCellular"),
      callback=self._on_v2i_cellular,
      enabled=ui_state.is_offroad,
    )

    self._scroller = Scroller([
      self._adb_toggle,
      self._ssh_toggle,
      self._ssh_keys,
      self._joystick_toggle,
      self._long_maneuver_toggle,
      self._alpha_long_toggle,
      self._ui_debug_toggle,
      self._v2i_toggle,
      self._phone_nav_toggle,
      self._att_dataplan_toggle,
      self._tmobile_dataplan_toggle,
      self._verizon_dataplan_toggle,
      self._v2i_wifi_toggle,
      self._v2i_att_toggle,
      self._v2i_tmobile_toggle,
      self._v2i_verizon_toggle,
      self._v2i_cellular_toggle,
    ], line_separator=True, spacing=0)

    # Toggles should be not available to change in onroad state
    ui_state.add_offroad_transition_callback(self._update_toggles)

  def _render(self, rect):
    self._scroller.render(rect)

  def show_event(self):
    super().show_event()
    self._scroller.show_event()
    self._update_toggles()

  def _update_toggles(self):
    ui_state.update_params()

    # Hide non-release toggles on release builds
    # TODO: we can do an onroad cycle, but alpha long toggle requires a deinit function to re-enable radar and not fault
    for item in (self._joystick_toggle, self._long_maneuver_toggle, self._alpha_long_toggle):
      item.set_visible(not self._is_release)

    # CP gating
    if ui_state.CP is not None:
      alpha_avail = ui_state.CP.alphaLongitudinalAvailable
      if not alpha_avail or self._is_release:
        self._alpha_long_toggle.set_visible(False)
        self._params.remove("AlphaLongitudinalEnabled")
      else:
        self._alpha_long_toggle.set_visible(True)

      long_man_enabled = ui_state.has_longitudinal_control and ui_state.is_offroad()
      self._long_maneuver_toggle.action_item.set_enabled(long_man_enabled)
      if not long_man_enabled:
        self._long_maneuver_toggle.action_item.set_state(False)
        self._params.put_bool("LongitudinalManeuverMode", False)
    else:
      self._long_maneuver_toggle.action_item.set_enabled(False)
      self._alpha_long_toggle.set_visible(False)

    # TODO: make a param control list item so we don't need to manage internal state as much here
    # refresh toggles from params to mirror external changes
    for key, item in (
      ("AdbEnabled", self._adb_toggle),
      ("SshEnabled", self._ssh_toggle),
      ("JoystickDebugMode", self._joystick_toggle),
      ("LongitudinalManeuverMode", self._long_maneuver_toggle),
      ("AlphaLongitudinalEnabled", self._alpha_long_toggle),
      ("ShowDebugInfo", self._ui_debug_toggle),
      ("V2IEnabled", self._v2i_toggle),
      ("PhoneNavEnabled", self._phone_nav_toggle),
      ("AttDataPlanEnabled", self._att_dataplan_toggle),
      ("TmobileDataPlanEnabled", self._tmobile_dataplan_toggle),
      ("VerizonDataPlanEnabled", self._verizon_dataplan_toggle),
      ("V2IWifiEnabled", self._v2i_wifi_toggle),
      ("V2IAllowCellular", self._v2i_cellular_toggle),
    ):
      item.action_item.set_state(self._params.get_bool(key))
    carrier = self._params.get("V2ICarrier") or ""
    self._v2i_att_toggle.action_item.set_state(carrier == "att")
    self._v2i_tmobile_toggle.action_item.set_state(carrier == "tmobile")
    self._v2i_verizon_toggle.action_item.set_state(carrier == "verizon")

  def _on_enable_ui_debug(self, state: bool):
    self._params.put_bool("ShowDebugInfo", state)
    gui_app.set_show_touches(state)
    gui_app.set_show_fps(state)

  def _on_v2i_enabled(self, state: bool):
    self._params.put_bool("V2IEnabled", state)
    self._params.put_bool("OnroadCycleRequested", True)

  def _on_phone_nav_enabled(self, state: bool):
    self._params.put_bool("PhoneNavEnabled", state)
    self._params.put_bool("OnroadCycleRequested", True)

  def _on_att_dataplan_enabled(self, state: bool):
    self._params.put_bool("AttDataPlanEnabled", state)
    if state:
      self._params.put_bool("TmobileDataPlanEnabled", False)
      self._params.put_bool("VerizonDataPlanEnabled", False)
      self._params.put("V2ICarrier", "att")
      self._params.put_bool("AttWifiHotspot", True)
      if not self._params.get_bool("PhoneNavEnabled"):
        self._params.put_bool("PhoneNavEnabled", True)
      if not self._params.get_bool("V2IEnabled"):
        self._params.put_bool("V2IEnabled", True)
    self._params.put_bool("OnroadCycleRequested", True)

  def _on_tmobile_dataplan_enabled(self, state: bool):
    self._params.put_bool("TmobileDataPlanEnabled", state)
    if state:
      self._params.put_bool("AttDataPlanEnabled", False)
      self._params.put_bool("VerizonDataPlanEnabled", False)
      self._params.put("V2ICarrier", "tmobile")
      self._params.put_bool("TmobileWifiHotspot", True)
      if not self._params.get("V2ITmobileApn"):
        self._params.put("V2ITmobileApn", "fast.t-mobile.com")
      if not self._params.get_bool("PhoneNavEnabled"):
        self._params.put_bool("PhoneNavEnabled", True)
      if not self._params.get_bool("V2IEnabled"):
        self._params.put_bool("V2IEnabled", True)
    self._params.put_bool("OnroadCycleRequested", True)

  def _on_verizon_dataplan_enabled(self, state: bool):
    self._params.put_bool("VerizonDataPlanEnabled", state)
    if state:
      self._params.put_bool("AttDataPlanEnabled", False)
      self._params.put_bool("TmobileDataPlanEnabled", False)
      self._params.put("V2ICarrier", "verizon")
      self._params.put_bool("VerizonWifiHotspot", True)
      if not self._params.get("V2IVerizonApn"):
        self._params.put("V2IVerizonApn", "vzwinternet")
      if not self._params.get_bool("PhoneNavEnabled"):
        self._params.put_bool("PhoneNavEnabled", True)
      if not self._params.get_bool("V2IEnabled"):
        self._params.put_bool("V2IEnabled", True)
    self._params.put_bool("OnroadCycleRequested", True)

  def _on_v2i_wifi(self, state: bool):
    self._params.put_bool("V2IWifiEnabled", state)
    self._params.put_bool("OnroadCycleRequested", True)

  def _on_v2i_att(self, state: bool):
    if state:
      self._params.put("V2ICarrier", "att")
      self._v2i_tmobile_toggle.action_item.set_state(False)
      self._v2i_verizon_toggle.action_item.set_state(False)
      if not self._params.get("V2IAttApn"):
        self._params.put("V2IAttApn", "nxtgenphone")
    else:
      self._params.put("V2ICarrier", "none")
    self._params.put_bool("OnroadCycleRequested", True)

  def _on_v2i_tmobile(self, state: bool):
    if state:
      self._params.put("V2ICarrier", "tmobile")
      self._v2i_att_toggle.action_item.set_state(False)
      self._v2i_verizon_toggle.action_item.set_state(False)
      if not self._params.get("V2ITmobileApn"):
        self._params.put("V2ITmobileApn", "fast.t-mobile.com")
    else:
      self._params.put("V2ICarrier", "none")
    self._params.put_bool("OnroadCycleRequested", True)

  def _on_v2i_verizon(self, state: bool):
    if state:
      self._params.put("V2ICarrier", "verizon")
      self._v2i_att_toggle.action_item.set_state(False)
      self._v2i_tmobile_toggle.action_item.set_state(False)
      if not self._params.get("V2IVerizonApn"):
        self._params.put("V2IVerizonApn", "vzwinternet")
    else:
      self._params.put("V2ICarrier", "none")
    self._params.put_bool("OnroadCycleRequested", True)

  def _on_v2i_cellular(self, state: bool):
    self._params.put_bool("V2IAllowCellular", state)
    self._params.put_bool("OnroadCycleRequested", True)

  def _on_enable_adb(self, state: bool):
    self._params.put_bool("AdbEnabled", state)

  def _on_enable_ssh(self, state: bool):
    self._params.put_bool("SshEnabled", state)

  def _on_joystick_debug_mode(self, state: bool):
    self._params.put_bool("JoystickDebugMode", state)
    self._params.put_bool("LongitudinalManeuverMode", False)
    self._long_maneuver_toggle.action_item.set_state(False)

  def _on_long_maneuver_mode(self, state: bool):
    self._params.put_bool("LongitudinalManeuverMode", state)
    self._params.put_bool("JoystickDebugMode", False)
    self._joystick_toggle.action_item.set_state(False)

  def _on_alpha_long_enabled(self, state: bool):
    if state:
      def confirm_callback(result: DialogResult):
        if result == DialogResult.CONFIRM:
          self._params.put_bool("AlphaLongitudinalEnabled", True)
          self._params.put_bool("OnroadCycleRequested", True)
          self._update_toggles()
        else:
          self._alpha_long_toggle.action_item.set_state(False)

      # show confirmation dialog
      content = (f"<h1>{self._alpha_long_toggle.title}</h1><br>" +
                 f"<p>{self._alpha_long_toggle.description}</p>")

      dlg = ConfirmDialog(content, tr("Enable"), rich=True, callback=confirm_callback)
      gui_app.push_widget(dlg)

    else:
      self._params.put_bool("AlphaLongitudinalEnabled", False)
      self._params.put_bool("OnroadCycleRequested", True)
      self._update_toggles()
