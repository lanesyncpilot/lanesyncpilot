#!/usr/bin/env bash
# =============================================================================
# LaneSync Pilot — in-car installer for comma 3X / comma four
# =============================================================================
#
# Install LaneSync Pilot on your comma device from the web:
#
#   bash <(curl -fsSL https://app.lanesyncpilot.ai/install.sh)
#
# Or directly from GitHub:
#
#   bash <(curl -fsSL https://raw.githubusercontent.com/lanesyncpilot/lanesyncpilot/main/install.sh)
#
# Options:
#   --help              Show full help
#   --update            Pull latest without full reinstall
#   --uninstall         Remove LaneSync install (keeps backups)
#   --carrier <name>    Enable AT&T, T-Mobile, or Verizon data plan + hotspot
#   --no-reboot         Skip automatic reboot at the end
#   --no-backup         Do not backup existing /data/openpilot
#   --dry-run           Print steps without making changes
#
# Examples:
#   bash install.sh --carrier tmobile
#   bash install.sh --update --no-reboot
#   ssh comma@192.168.0.11 'bash -s' < install.sh
#
# =============================================================================
set -euo pipefail

LANESYNC_VERSION="1.0.0"
LANESYNC_NAME="LaneSync Pilot"
REPO_URL="${LANESYNC_REPO_URL:-https://github.com/lanesyncpilot/lanesyncpilot.git}"
BRANCH="${LANESYNC_BRANCH:-main}"
WEBSITE="${LANESYNC_WEBSITE:-https://app.lanesyncpilot.ai}"
GITHUB_RAW="https://raw.githubusercontent.com/lanesyncpilot/lanesyncpilot/main/install.sh"

REPO_DIR="/data/lanesync-repo"
OPENPILOT_DIR="/data/openpilot"
CONTINUE_SH="/data/continue.sh"
LOG_FILE="/data/lanesync-install.log"
STAMP="$(date +%Y%m%d-%H%M%S)"
MIN_FREE_MB=1500

# Runtime flags (set by parse_args)
DO_UPDATE=0
DO_UNINSTALL=0
DO_REBOOT=1
DO_BACKUP=1
DO_DRY_RUN=0
CARRIER=""

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BLUE='\033[0;34m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

# -----------------------------------------------------------------------------
# Logging
# -----------------------------------------------------------------------------

log() {
  local msg="[$(date '+%H:%M:%S')] $*"
  echo -e "${CYAN}[lanesync]${NC} $*"
  [[ -w /data ]] && echo "$msg" >> "$LOG_FILE" 2>/dev/null || true
}

ok()   { echo -e "${GREEN}[ok]${NC} $*"; log "OK: $*"; }
warn() { echo -e "${YELLOW}[warn]${NC} $*"; log "WARN: $*"; }
die()  { echo -e "${RED}[error]${NC} $*" >&2; log "ERROR: $*"; exit 1; }
step() { echo -e "\n${BOLD}${BLUE}==>${NC} ${BOLD}$*${NC}"; log "STEP: $*"; }

run() {
  if [[ "$DO_DRY_RUN" -eq 1 ]]; then
    echo -e "${DIM}  (dry-run) $*${NC}"
    return 0
  fi
  eval "$@"
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "Missing required command: $1"
}

# -----------------------------------------------------------------------------
# Help
# -----------------------------------------------------------------------------

usage() {
  cat <<EOF
${BOLD}${LANESYNC_NAME} installer v${LANESYNC_VERSION}${NC}

${BOLD}Quick install (on comma device):${NC}
  bash <(curl -fsSL ${WEBSITE}/install.sh)
  bash <(curl -fsSL ${GITHUB_RAW})

${BOLD}From your laptop over SSH:${NC}
  ssh comma@<comma-ip> 'bash -s' < install.sh
  ssh comma@<comma-ip> 'bash -s' -- --carrier verizon < install.sh

${BOLD}Options:${NC}
  -h, --help              Show this help
  -u, --update            Update an existing LaneSync install (git pull)
  --uninstall             Remove LaneSync symlink and repo (keeps backups)
  -c, --carrier <name>    Enable carrier: att | tmobile | verizon
  --no-reboot             Do not reboot when finished
  --no-backup             Skip backing up existing /data/openpilot
  --dry-run               Show what would happen without changing anything

${BOLD}What gets installed:${NC}
  • openpilot fork at /data/openpilot (symlinked from /data/lanesync-repo)
  • V2I daemon (UDP 7701) — traffic signals, hazards, speed advisories
  • Phone navigation bridge (HTTP 7710) — iPhone Shortcuts / Android Auto app
  • Dashcam API (HTTP 7720) — saved clips for mobile apps
  • LaneSync version ${LANESYNC_VERSION} on device home screen

${BOLD}After install:${NC}
  • Connect phone to comma Wi‑Fi hotspot (192.168.43.1)
  • Android app: ${WEBSITE}
  • Dashcam API: http://192.168.43.1:7720
  • Developer toggles: Settings → Developer on device UI

${BOLD}Documentation:${NC}
  ${WEBSITE}
  https://github.com/lanesyncpilot/lanesyncpilot

EOF
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h|--help) usage; exit 0 ;;
      -u|--update) DO_UPDATE=1; shift ;;
      --uninstall) DO_UNINSTALL=1; shift ;;
      -c|--carrier)
        CARRIER="${2:-}"
        [[ -n "$CARRIER" ]] || die "--carrier requires att, tmobile, or verizon"
        shift 2
        ;;
      --no-reboot) DO_REBOOT=0; shift ;;
      --no-backup) DO_BACKUP=0; shift ;;
      --dry-run) DO_DRY_RUN=1; shift ;;
      *) die "Unknown option: $1 (try --help)" ;;
    esac
  done

  case "$CARRIER" in
    ""|att|tmobile|verizon) ;;
    *) die "Invalid carrier '$CARRIER'. Use: att, tmobile, or verizon" ;;
  esac
}

# -----------------------------------------------------------------------------
# Device detection & preflight
# -----------------------------------------------------------------------------

is_comma_device() {
  [[ -d /data ]] && { [[ -d /system/etc/selinux ]] || [[ -f /AGNOS ]]; }
}

detect_device_type() {
  if [[ -f /data/params/d/HardwareSerial ]]; then
    cat /data/params/d/HardwareSerial 2>/dev/null || echo "unknown"
  elif [[ -f /proc/device-tree/model ]]; then
    tr -d '\0' < /proc/device-tree/model 2>/dev/null || echo "comma"
  else
    echo "comma"
  fi
}

check_disk_space() {
  step "Checking free disk space"
  need_cmd df
  local free_kb
  free_kb="$(df -k /data 2>/dev/null | awk 'NR==2 {print $4}')"
  local free_mb=$((free_kb / 1024))
  log "Free space on /data: ${free_mb} MB"
  if [[ "$free_mb" -lt "$MIN_FREE_MB" ]]; then
    die "Need at least ${MIN_FREE_MB} MB free on /data (found ${free_mb} MB).
Remove old routes or backups under /data before installing."
  fi
  ok "Disk space OK (${free_mb} MB free)"
}

check_network() {
  step "Checking network connectivity"
  if ping -c 1 -W 3 github.com >/dev/null 2>&1; then
    ok "Network reachable (github.com)"
  elif ping -c 1 -W 3 8.8.8.8 >/dev/null 2>&1; then
    warn "Internet works but github.com did not respond to ping — continuing anyway"
  else
    warn "No network detected. Install may fail during git clone.
Connect comma to Wi‑Fi or insert a SIM with data, then retry."
  fi
}

check_prerequisites() {
  step "Checking prerequisites"
  need_cmd git
  need_cmd ln
  need_cmd chmod
  need_cmd mv
  ok "Required tools present"
}

preflight() {
  print_banner
  if ! is_comma_device; then
    die "This installer must run on a comma device (/data partition not found).

${BOLD}Run from your Mac over SSH:${NC}
  ssh comma@<your-comma-ip> 'bash -s' < install.sh

${BOLD}Or on the comma terminal:${NC}
  bash <(curl -fsSL ${WEBSITE}/install.sh)"
  fi

  if [[ "$(id -u)" -ne 0 ]]; then
    warn "Not running as root — elevating with sudo"
    exec sudo -E bash "$0" "$@"
  fi

  mkdir -p /data
  : > "$LOG_FILE" 2>/dev/null || true
  log "Install started (version ${LANESYNC_VERSION}, branch ${BRANCH})"

  local device
  device="$(detect_device_type)"
  log "Device: ${device}"

  check_prerequisites
  check_disk_space
  check_network
}

print_banner() {
  echo ""
  echo -e "${BOLD}╔══════════════════════════════════════════════════════════════╗${NC}"
  echo -e "${BOLD}║${NC}  ${GREEN}LaneSync Pilot${NC} — in-car installer v${LANESYNC_VERSION}               ${BOLD}║${NC}"
  echo -e "${BOLD}║${NC}  V2I · Navigation · Dashcam · Safety                         ${BOLD}║${NC}"
  echo -e "${BOLD}╚══════════════════════════════════════════════════════════════╝${NC}"
  echo ""
  echo -e "  ${DIM}Website${NC}     ${WEBSITE}"
  echo -e "  ${DIM}Repository${NC}  ${REPO_URL}"
  echo -e "  ${DIM}Branch${NC}      ${BRANCH}"
  [[ -n "$CARRIER" ]] && echo -e "  ${DIM}Carrier${NC}     ${CARRIER}"
  [[ "$DO_DRY_RUN" -eq 1 ]] && echo -e "  ${YELLOW}DRY RUN — no changes will be made${NC}"
  echo ""
}

# -----------------------------------------------------------------------------
# Params
# -----------------------------------------------------------------------------

set_param() {
  local key="$1"
  local value="$2"
  run mkdir -p /data/params/d
  if [[ "$DO_DRY_RUN" -eq 1 ]]; then
    echo -e "${DIM}  (dry-run) params ${key}=${value}${NC}"
    return 0
  fi
  printf '%s' "$value" > "/data/params/d/${key}"
  log "param ${key}=${value}"
}

get_param() {
  local key="$1"
  local default="${2:-}"
  if [[ -f "/data/params/d/${key}" ]]; then
    cat "/data/params/d/${key}"
  else
    echo -n "$default"
  fi
}

# -----------------------------------------------------------------------------
# Install steps
# -----------------------------------------------------------------------------

stop_onroad() {
  step "Checking running processes"
  if pgrep -f "selfdrive/manager/manager.py" >/dev/null 2>&1; then
    warn "openpilot manager is running — a reboot is required after install"
    log "manager.py is active"
  else
    ok "No active manager process"
  fi
}

backup_existing() {
  if [[ "$DO_BACKUP" -eq 0 ]]; then
    warn "Skipping backup (--no-backup)"
    return
  fi

  step "Backing up existing installation"
  if [[ -e "$OPENPILOT_DIR" && ! -L "$OPENPILOT_DIR" ]]; then
    local backup="${OPENPILOT_DIR}.bak.${STAMP}"
    log "Moving ${OPENPILOT_DIR} → ${backup}"
    run mv "$OPENPILOT_DIR" "$backup"
    ok "Backed up to ${backup}"
  elif [[ -L "$OPENPILOT_DIR" ]]; then
    log "Removing existing symlink ${OPENPILOT_DIR}"
    run rm -f "$OPENPILOT_DIR"
    ok "Removed old symlink"
  else
    ok "No existing /data/openpilot to backup"
  fi
}

clone_repo() {
  step "Downloading LaneSync Pilot from GitHub"
  need_cmd git
  run rm -rf "$REPO_DIR"
  log "git clone --depth 1 --branch ${BRANCH} ${REPO_URL}"
  if [[ "$DO_DRY_RUN" -eq 0 ]]; then
    if ! git clone --depth 1 --branch "$BRANCH" --recurse-submodules --shallow-submodules \
        "$REPO_URL" "$REPO_DIR" 2>&1 | tee -a "$LOG_FILE"; then
      die "git clone failed. Check network and branch name (${BRANCH})."
    fi
  fi
  [[ "$DO_DRY_RUN" -eq 1 || -d "${REPO_DIR}/lanesync-pilot" ]] \
    || die "lanesync-pilot folder missing in repository"
  ok "Repository cloned to ${REPO_DIR}"
}

update_repo() {
  step "Updating existing LaneSync install"
  [[ -d "$REPO_DIR/.git" ]] || die "No existing install at ${REPO_DIR}. Run without --update first."
  if [[ "$DO_DRY_RUN" -eq 1 ]]; then
    echo -e "${DIM}  (dry-run) git pull in ${REPO_DIR}${NC}"
    return
  fi
  cd "$REPO_DIR"
  git fetch origin "$BRANCH" --depth 1
  git checkout "$BRANCH"
  git pull --ff-only origin "$BRANCH" 2>&1 | tee -a "$LOG_FILE" || die "git pull failed"
  cd "${REPO_DIR}/lanesync-pilot"
  git submodule update --init --depth 1 --jobs "$(nproc 2>/dev/null || echo 2)"
  ok "Updated to latest ${BRANCH}"
}

link_openpilot() {
  step "Linking openpilot into /data"
  log "ln -sfn ${REPO_DIR}/lanesync-pilot ${OPENPILOT_DIR}"
  run ln -sfn "${REPO_DIR}/lanesync-pilot" "$OPENPILOT_DIR"
  ok "${OPENPILOT_DIR} → ${REPO_DIR}/lanesync-pilot"
}

init_submodules() {
  step "Initializing git submodules"
  if [[ "$DO_DRY_RUN" -eq 1 ]]; then
    echo -e "${DIM}  (dry-run) git submodule update in lanesync-pilot${NC}"
    return
  fi
  cd "${REPO_DIR}/lanesync-pilot"
  log "Running git submodule update --init"
  if ! git submodule update --init --depth 1 --jobs "$(nproc 2>/dev/null || echo 2)" \
      2>&1 | tee -a "$LOG_FILE"; then
    warn "Some submodules failed — device may still work; check ${LOG_FILE}"
  else
    ok "Submodules initialized"
  fi
}

write_continue_sh() {
  step "Configuring boot launcher"
  log "Writing ${CONTINUE_SH}"
  if [[ "$DO_DRY_RUN" -eq 1 ]]; then
    echo -e "${DIM}  (dry-run) write ${CONTINUE_SH}${NC}"
    return
  fi
  cat > "${CONTINUE_SH}.new" <<'EOF'
#!/usr/bin/env bash
# LaneSync Pilot — auto-generated by install.sh
cd /data/openpilot
exec ./launch_openpilot.sh
EOF
  chmod +x "${CONTINUE_SH}.new"
  mv "${CONTINUE_SH}.new" "$CONTINUE_SH"
  ok "continue.sh installed"
}

enable_lanesync_features() {
  step "Enabling LaneSync features"

  set_param "LaneSyncVersion" "$LANESYNC_VERSION"
  set_param "V2IEnabled" "1"
  set_param "PhoneNavEnabled" "1"
  set_param "DashcamApiEnabled" "1"
  set_param "V2IPort" "7701"
  set_param "PhoneNavPort" "7710"
  set_param "DashcamApiPort" "7720"

  ok "Core features enabled:"
  echo -e "    ${DIM}V2I${NC}           UDP port 7701  (v2id)"
  echo -e "    ${DIM}Phone nav${NC}     HTTP port 7710  (phonenavd)"
  echo -e "    ${DIM}Dashcam API${NC}   HTTP port 7720  (dashcamd)"
}

enable_carrier() {
  [[ -n "$CARRIER" ]] || return 0

  step "Configuring ${CARRIER} data plan + Wi‑Fi hotspot"

  case "$CARRIER" in
    att)
      set_param "AttDataPlanEnabled" "1"
      set_param "TmobileDataPlanEnabled" "0"
      set_param "VerizonDataPlanEnabled" "0"
      ;;
    tmobile)
      set_param "TmobileDataPlanEnabled" "1"
      set_param "AttDataPlanEnabled" "0"
      set_param "VerizonDataPlanEnabled" "0"
      ;;
    verizon)
      set_param "VerizonDataPlanEnabled" "1"
      set_param "AttDataPlanEnabled" "0"
      set_param "TmobileDataPlanEnabled" "0"
      ;;
  esac

  local carrier_dir="${REPO_DIR}/lanesync-pilot/${CARRIER}"
  if [[ "$DO_DRY_RUN" -eq 0 && -d "$carrier_dir" ]]; then
    log "Copying carrier configs to /data/${CARRIER}"
    run mkdir -p "/data/${CARRIER}"
    run cp -a "${carrier_dir}/." "/data/${CARRIER}/"
    if [[ -f "/data/${CARRIER}/apply_dataplan.sh" ]]; then
      run chmod +x "/data/${CARRIER}/apply_dataplan.sh"
      log "Run /data/${CARRIER}/apply_dataplan.sh consumer after reboot if LTE does not connect"
    fi
  fi

  ok "${CARRIER} data plan enabled (mutually exclusive with other carriers)"
  warn "Insert ${CARRIER} SIM and reboot if cellular hotspot does not start automatically"
}

verify_install() {
  step "Verifying installation"

  local errors=0

  if [[ "$DO_DRY_RUN" -eq 1 ]]; then
    ok "Dry run complete — verification skipped"
    return 0
  fi

  if [[ ! -L "$OPENPILOT_DIR" && ! -d "$OPENPILOT_DIR" ]]; then
    warn "Missing ${OPENPILOT_DIR}"
    errors=$((errors + 1))
  else
    ok "openpilot path exists"
  fi

  if [[ ! -f "${OPENPILOT_DIR}/launch_openpilot.sh" ]]; then
    warn "launch_openpilot.sh not found"
    errors=$((errors + 1))
  else
    ok "launch_openpilot.sh present"
  fi

  if [[ ! -x "$CONTINUE_SH" ]]; then
    warn "continue.sh missing or not executable"
    errors=$((errors + 1))
  else
    ok "continue.sh ready"
  fi

  if [[ "$(get_param V2IEnabled 0)" != "1" ]]; then
    warn "V2IEnabled param not set"
    errors=$((errors + 1))
  else
    ok "V2IEnabled=1"
  fi

  if [[ "$(get_param LaneSyncVersion "")" != "$LANESYNC_VERSION" ]]; then
    warn "LaneSyncVersion mismatch"
    errors=$((errors + 1))
  else
    ok "LaneSyncVersion=${LANESYNC_VERSION}"
  fi

  if [[ -f "${OPENPILOT_DIR}/system/v2i/v2id.py" ]]; then
    ok "V2I daemon source present"
  else
    warn "system/v2i/v2id.py not found"
    errors=$((errors + 1))
  fi

  if [[ -f "${OPENPILOT_DIR}/system/dashcam/dashcamd.py" ]]; then
    ok "Dashcam daemon source present"
  else
    warn "system/dashcam/dashcamd.py not found"
    errors=$((errors + 1))
  fi

  if [[ "$errors" -gt 0 ]]; then
    warn "Verification finished with ${errors} warning(s) — check ${LOG_FILE}"
  else
    ok "All verification checks passed"
  fi
}

# -----------------------------------------------------------------------------
# Uninstall
# -----------------------------------------------------------------------------

do_uninstall() {
  print_banner
  preflight

  step "Uninstalling LaneSync Pilot"

  if [[ -L "$OPENPILOT_DIR" ]]; then
    run rm -f "$OPENPILOT_DIR"
    ok "Removed symlink ${OPENPILOT_DIR}"
  elif [[ -d "$OPENPILOT_DIR" ]]; then
    warn "${OPENPILOT_DIR} is a real directory — not removing (may be stock openpilot)"
  fi

  if [[ -d "$REPO_DIR" ]]; then
    run rm -rf "$REPO_DIR"
    ok "Removed ${REPO_DIR}"
  fi

  echo ""
  ok "LaneSync uninstall complete. Backups under /data/openpilot.bak.* were kept."
  echo "To reinstall: bash <(curl -fsSL ${WEBSITE}/install.sh)"
  exit 0
}

# -----------------------------------------------------------------------------
# Post-install guide
# -----------------------------------------------------------------------------

print_post_install_guide() {
  echo ""
  echo -e "${BOLD}╔══════════════════════════════════════════════════════════════╗${NC}"
  echo -e "${BOLD}║${NC}  ${GREEN}LaneSync Pilot installed successfully${NC}                     ${BOLD}║${NC}"
  echo -e "${BOLD}╚══════════════════════════════════════════════════════════════╝${NC}"
  echo ""
  echo -e "${BOLD}1. First drive${NC}"
  echo "   • Mount comma in your car and connect the harness"
  echo "   • After reboot, openpilot should start automatically"
  echo "   • Home screen shows ${BOLD}LaneSync${NC} and version ${LANESYNC_VERSION}"
  echo ""
  echo -e "${BOLD}2. Enable / tune features${NC}"
  echo "   • On-device: ${BOLD}Settings → Developer${NC}"
  echo "   • V2I, phone nav, dashcam API are already enabled by this installer"
  echo "   • Carrier toggles: AT&T / T-Mobile / Verizon (one at a time)"
  echo ""
  echo -e "${BOLD}3. Phone connection${NC}"
  echo "   • Join comma Wi‑Fi hotspot (default gateway 192.168.43.1)"
  echo "   • ${BOLD}Android:${NC} LaneSync Pilot app → ${WEBSITE}"
  echo "   • ${BOLD}iPhone nav:${NC} Shortcuts automation → phonenavd port 7710"
  echo "     Guide: lanesync-pilot/tools/v2i/ios/README.md"
  echo ""
  echo -e "${BOLD}4. Dashcam clips${NC}"
  echo "   • Press the bookmark button on comma to save a segment"
  echo "   • API: http://192.168.43.1:7720/clips"
  echo "   • Android app downloads clips over hotspot or cloud (when live)"
  echo ""
  echo -e "${BOLD}5. Test from a laptop (same Wi‑Fi as comma)${NC}"
  echo "   python3 tools/v2i/v2i_sender.py --host 192.168.43.1 --demo"
  echo "   python3 tools/v2i/phone_nav_sender.py --host 192.168.43.1"
  echo ""
  echo -e "${BOLD}6. Update later${NC}"
  echo "   bash <(curl -fsSL ${WEBSITE}/install.sh) --update"
  echo ""
  echo -e "${BOLD}7. Logs${NC}"
  echo "   Install log: ${LOG_FILE}"
  echo "   openpilot logs: /data/log/"
  echo ""
  echo -e "${DIM}Support: ${WEBSITE} · github.com/lanesyncpilot/lanesyncpilot${NC}"
  echo ""
}

reboot_device() {
  if [[ "$DO_REBOOT" -eq 0 ]]; then
    warn "Skipping reboot (--no-reboot). Reboot manually to start LaneSync Pilot."
    return
  fi
  if [[ "$DO_DRY_RUN" -eq 1 ]]; then
    echo -e "${DIM}  (dry-run) would reboot now${NC}"
    return
  fi
  echo -e "${BOLD}Rebooting in 10 seconds…${NC} ${DIM}(Ctrl+C to cancel)${NC}"
  sleep 10
  reboot
}

# -----------------------------------------------------------------------------
# Main flows
# -----------------------------------------------------------------------------

do_fresh_install() {
  stop_onroad
  backup_existing
  clone_repo
  link_openpilot
  init_submodules
  write_continue_sh
  enable_lanesync_features
  enable_carrier
  verify_install
  print_post_install_guide
  reboot_device
}

do_update_install() {
  [[ -d "$REPO_DIR" ]] || die "No existing install. Run without --update first."
  stop_onroad
  update_repo
  link_openpilot
  enable_lanesync_features
  enable_carrier
  verify_install
  print_post_install_guide
  reboot_device
}

main() {
  parse_args "$@"

  if [[ "$DO_UNINSTALL" -eq 1 ]]; then
    do_uninstall
  fi

  preflight

  if [[ "$DO_UPDATE" -eq 1 ]]; then
    do_update_install
  else
    do_fresh_install
  fi
}

main "$@"
