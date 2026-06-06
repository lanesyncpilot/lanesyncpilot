#!/usr/bin/env bash
# =============================================================================
# LaneSync Pilot — in-car installer for comma 3X / comma four
# =============================================================================
#
#   bash <(curl -fsSL https://app.lanesyncpilot.ai/install.sh)
#   bash <(curl -fsSL https://raw.githubusercontent.com/lanesyncpilot/lanesyncpilot/main/install.sh)
#
# =============================================================================
set -euo pipefail

LANESYNC_VERSION="1.0.0"
LANESYNC_NAME="LaneSync Pilot"
OPENPILOT_BASE_VERSION="0.11.0"
REPO_URL="${LANESYNC_REPO_URL:-https://github.com/lanesyncpilot/lanesyncpilot.git}"
BRANCH="${LANESYNC_BRANCH:-main}"
WEBSITE="${LANESYNC_WEBSITE:-https://app.lanesyncpilot.ai}"
GITHUB_RAW="https://raw.githubusercontent.com/lanesyncpilot/lanesyncpilot/main/install.sh"
SUPPORT_EMAIL="${LANESYNC_SUPPORT_EMAIL:-support@lanesyncpilot.ai}"

REPO_DIR="/data/lanesync-repo"
OPENPILOT_DIR="/data/openpilot"
CONTINUE_SH="/data/continue.sh"
LOG_FILE="/data/lanesync-install.log"
MANIFEST_FILE="/data/lanesync-install.json"
STAMP="$(date +%Y%m%d-%H%M%S)"
MIN_FREE_MB=1500
HOTSPOT_IP="${LANESYNC_HOTSPOT_IP:-192.168.43.1}"

# Ports (LaneSync services)
PORT_V2I_UDP=7701
PORT_PHONENAV_HTTP=7710
PORT_DASHCAM_HTTP=7720

# Runtime flags
DO_UPDATE=0
DO_UNINSTALL=0
DO_REBOOT=1
DO_BACKUP=1
DO_DRY_RUN=0
DO_INTERACTIVE=0
DO_STATUS=0
DO_RESTORE=0
DO_PRUNE_BACKUPS=0
DO_ENABLE_SSH=0
DO_APPLY_CARRIER_NOW=0
DO_SKIP_CONFIRM=0
CARRIER=""
CARRIER_PROFILE="consumer"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

TOTAL_STEPS=14
CURRENT_STEP=0

# -----------------------------------------------------------------------------
# UI helpers
# -----------------------------------------------------------------------------

log() {
  local msg="[$(date '+%Y-%m-%d %H:%M:%S')] $*"
  echo -e "${CYAN}[lanesync]${NC} $*"
  [[ -w /data ]] && echo "$msg" >> "$LOG_FILE" 2>/dev/null || true
}

ok()   { echo -e "${GREEN}[ok]${NC} $*"; log "OK: $*"; }
warn() { echo -e "${YELLOW}[warn]${NC} $*"; log "WARN: $*"; }
die()  { echo -e "${RED}[error]${NC} $*" >&2; log "FATAL: $*"; exit 1; }

step() {
  CURRENT_STEP=$((CURRENT_STEP + 1))
  echo ""
  echo -e "${BOLD}${BLUE}[${CURRENT_STEP}/${TOTAL_STEPS}]${NC} ${BOLD}$*${NC}"
  log "STEP ${CURRENT_STEP}/${TOTAL_STEPS}: $*"
}

run() {
  if [[ "$DO_DRY_RUN" -eq 1 ]]; then
    echo -e "${DIM}    (dry-run) $*${NC}"
    return 0
  fi
  eval "$@"
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "Missing required command: $1"
}

hr() {
  echo -e "${DIM}────────────────────────────────────────────────────────────────${NC}"
}

prompt_yes_no() {
  local question="$1"
  local default="${2:-y}"
  if [[ "$DO_SKIP_CONFIRM" -eq 1 || "$DO_DRY_RUN" -eq 1 ]]; then
    return 0
  fi
  local hint="[Y/n]"
  [[ "$default" == "n" ]] && hint="[y/N]"
  read -r -p "$(echo -e "${BOLD}${question}${NC} ${hint}: ")" reply
  reply="${reply:-$default}"
  [[ "$reply" =~ ^[Yy] ]]
}

# -----------------------------------------------------------------------------
# Help
# -----------------------------------------------------------------------------

usage() {
  cat <<EOF
${BOLD}${LANESYNC_NAME} installer v${LANESYNC_VERSION}${NC}
Based on openpilot v${OPENPILOT_BASE_VERSION} · ${WEBSITE}

${BOLD}━━━ Quick install ━━━${NC}
  bash <(curl -fsSL ${WEBSITE}/install.sh)
  bash <(curl -fsSL ${GITHUB_RAW})

${BOLD}━━━ SSH from laptop ━━━${NC}
  ssh comma@<comma-ip> 'bash -s' < install.sh
  ssh comma@<comma-ip> 'bash -s' -- --carrier tmobile --apply-carrier < install.sh

${BOLD}━━━ Commands ━━━${NC}
  -h, --help                 Show this help
  -i, --interactive          Ask questions (carrier, SSH, confirm)
  -u, --update               Update existing install (git pull)
  -s, --status               Print install status and exit
  --uninstall                Remove LaneSync (keeps backups)
  --restore-backup           Restore latest /data/openpilot.bak.*
  --prune-backups            Remove openpilot backups older than 14 days
  -c, --carrier <name>       att | tmobile | verizon
  --carrier-profile <name>   consumer (default) or other profile in dataplan.json
  --apply-carrier            Run apply_dataplan.sh immediately (needs root)
  --enable-ssh               Enable SSH param on device
  -b, --branch <name>        Git branch (default: main)
  --no-reboot                Skip reboot at end
  --no-backup                Skip backup of existing /data/openpilot
  --yes                      Skip confirmation prompts
  --dry-run                  Print actions without changing anything

${BOLD}━━━ Environment variables ━━━${NC}
  LANESYNC_REPO_URL          Override git clone URL
  LANESYNC_BRANCH            Override branch
  LANESYNC_WEBSITE           Website URL shown in output
  LANESYNC_HOTSPOT_IP        Hotspot gateway (default 192.168.43.1)

${BOLD}━━━ What this installs ━━━${NC}
  Path          /data/openpilot  →  /data/lanesync-repo/lanesync-pilot
  Boot          /data/continue.sh launches openpilot
  V2I           UDP  ${PORT_V2I_UDP}   v2id, v2inetd
  Phone nav     HTTP ${PORT_PHONENAV_HTTP}  phonenavd (iPhone Shortcuts / Android app)
  Dashcam API   HTTP ${PORT_DASHCAM_HTTP}  dashcamd (mobile apps)
  Carriers      attd / tmobiled / verizond + Wi‑Fi hotspot

${BOLD}━━━ After install ━━━${NC}
  • Phone Wi‑Fi → comma hotspot (${HOTSPOT_IP})
  • Android app → ${WEBSITE}
  • Dashcam     → http://${HOTSPOT_IP}:${PORT_DASHCAM_HTTP}/clips
  • Developer   → Settings → Developer on comma UI
  • Docs        → lanesync-pilot/docs/LANESYNC.md

${BOLD}━━━ Troubleshooting ━━━${NC}
  bash <(curl -fsSL ${WEBSITE}/install.sh) --status
  cat ${LOG_FILE}
  bash <(curl -fsSL ${WEBSITE}/install.sh) --restore-backup

EOF
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h|--help) usage; exit 0 ;;
      -i|--interactive) DO_INTERACTIVE=1; shift ;;
      -u|--update) DO_UPDATE=1; shift ;;
      -s|--status) DO_STATUS=1; shift ;;
      --uninstall) DO_UNINSTALL=1; shift ;;
      --restore-backup) DO_RESTORE=1; shift ;;
      --prune-backups) DO_PRUNE_BACKUPS=1; shift ;;
      -c|--carrier)
        CARRIER="${2:-}"
        [[ -n "$CARRIER" ]] || die "--carrier requires att, tmobile, or verizon"
        shift 2
        ;;
      --carrier-profile)
        CARRIER_PROFILE="${2:-consumer}"
        shift 2
        ;;
      --apply-carrier) DO_APPLY_CARRIER_NOW=1; shift ;;
      --enable-ssh) DO_ENABLE_SSH=1; shift ;;
      -b|--branch)
        BRANCH="${2:-}"
        [[ -n "$BRANCH" ]] || die "--branch requires a branch name"
        shift 2
        ;;
      --no-reboot) DO_REBOOT=0; shift ;;
      --no-backup) DO_BACKUP=0; shift ;;
      --yes) DO_SKIP_CONFIRM=1; shift ;;
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
# Device info
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

detect_agnos_version() {
  if [[ -f /AGNOS ]]; then
    cat /AGNOS 2>/dev/null || echo "unknown"
  elif [[ -f /etc/agnos-version ]]; then
    cat /etc/agnos-version 2>/dev/null || echo "unknown"
  else
    echo "unknown"
  fi
}

detect_sim_status() {
  if command -v mmcli >/dev/null 2>&1; then
    mmcli -L 2>/dev/null | head -5 || echo "modem: unavailable"
  elif [[ -d /sys/class/net/wwan0 ]]; then
    echo "wwan0 interface present"
  else
    echo "no modem detected (Wi‑Fi-only install is fine)"
  fi
}

print_system_report() {
  step "System report"
  echo -e "  ${DIM}Hostname${NC}      $(hostname 2>/dev/null || echo n/a)"
  echo -e "  ${DIM}Device${NC}        $(detect_device_type)"
  echo -e "  ${DIM}AGNOS${NC}         $(detect_agnos_version)"
  echo -e "  ${DIM}Kernel${NC}        $(uname -r 2>/dev/null || echo n/a)"
  echo -e "  ${DIM}Uptime${NC}        $(uptime -p 2>/dev/null || uptime 2>/dev/null || echo n/a)"
  echo -e "  ${DIM}SIM / LTE${NC}     $(detect_sim_status)"
  if command -v df >/dev/null 2>&1; then
    echo -e "  ${DIM}Disk /data${NC}    $(df -h /data 2>/dev/null | awk 'NR==2 {print $3 " used, " $4 " free (" $5 ")"}')"
  fi
  if [[ -f "$MANIFEST_FILE" ]]; then
    echo -e "  ${DIM}Last install${NC}  $(grep -o '"installed_at":"[^"]*"' "$MANIFEST_FILE" 2>/dev/null | cut -d'"' -f4 || echo unknown)"
  fi
  hr
}

# -----------------------------------------------------------------------------
# Preflight
# -----------------------------------------------------------------------------

check_disk_space() {
  step "Checking disk space"
  need_cmd df
  local free_kb free_mb
  free_kb="$(df -k /data 2>/dev/null | awk 'NR==2 {print $4}')"
  free_mb=$((free_kb / 1024))
  log "Free on /data: ${free_mb} MB (minimum ${MIN_FREE_MB} MB)"
  if [[ "$free_mb" -lt "$MIN_FREE_MB" ]]; then
    die "Insufficient disk space. Need ${MIN_FREE_MB} MB, found ${free_mb} MB.
Try: bash <(curl -fsSL ${WEBSITE}/install.sh) --prune-backups
Or delete old routes under /data/media/0/realdata/"
  fi
  ok "${free_mb} MB free"
}

check_network() {
  step "Checking network"
  local ok_net=0
  for host in github.com raw.githubusercontent.com; do
    if ping -c 1 -W 4 "$host" >/dev/null 2>&1; then
      ok "Reachable: ${host}"
      ok_net=1
      break
    fi
  done
  if [[ "$ok_net" -eq 0 ]]; then
    if ping -c 1 -W 4 8.8.8.8 >/dev/null 2>&1; then
      warn "Internet up but GitHub unreachable — clone may still work"
    else
      warn "No network. Connect Wi‑Fi or insert SIM before continuing."
      if ! prompt_yes_no "Continue without network?" "n"; then
        die "Aborted — connect network and retry."
      fi
    fi
  fi
}

check_prerequisites() {
  step "Checking tools"
  local missing=0
  for cmd in git ln chmod mv cp mkdir printf cat; do
    if command -v "$cmd" >/dev/null 2>&1; then
      echo -e "    ${GREEN}✓${NC} ${cmd}"
    else
      echo -e "    ${RED}✗${NC} ${cmd}"
      missing=1
    fi
  done
  [[ "$missing" -eq 0 ]] || die "Missing required commands"
  ok "Prerequisites satisfied"
}

preflight() {
  print_banner
  if ! is_comma_device; then
    die "Must run on a comma device.

  ssh comma@<ip> 'bash -s' < install.sh
  bash <(curl -fsSL ${WEBSITE}/install.sh)"
  fi

  if [[ "$(id -u)" -ne 0 ]]; then
    warn "Elevating to root"
    exec sudo -E bash "$0" "$@"
  fi

  mkdir -p /data
  : > "$LOG_FILE" 2>/dev/null || true
  log "=== LaneSync install ${LANESYNC_VERSION} branch=${BRANCH} ==="

  print_system_report
  check_prerequisites
  check_disk_space
  check_network
}

print_banner() {
  echo ""
  echo -e "${GREEN}"
  cat <<'BANNER'
    __  _____             _____
   / / |_   _| __ __ _  _|___ / _ __   ___  _ __   __ _
  / /    | || '__/ _` |/ _ \ / _| '_ \ / _ \| '_ \ / _` |
 / /__   | || | | (_| | (_) | |_| | | | (_) | | | | (_| |
/_____|  |_||_|  \__,_|\___/ \__|_| |_|\___/|_| |_|\__,_|
BANNER
  echo -e "${NC}"
  echo -e "${BOLD}  LaneSync Pilot${NC}  in-car installer  ${DIM}v${LANESYNC_VERSION}${NC}"
  echo -e "  ${DIM}V2I · Android Auto · CarPlay · Dashcam · Safety · Cloud${NC}"
  hr
  echo -e "  Website     ${WEBSITE}"
  echo -e "  Repository  ${REPO_URL}"
  echo -e "  Branch      ${BRANCH}"
  [[ -n "$CARRIER" ]] && echo -e "  Carrier     ${CARRIER} (${CARRIER_PROFILE})"
  [[ "$DO_DRY_RUN" -eq 1 ]] && echo -e "  ${YELLOW}MODE: dry-run${NC}"
  [[ "$DO_INTERACTIVE" -eq 1 ]] && echo -e "  ${MAGENTA}MODE: interactive${NC}"
  hr
}

# -----------------------------------------------------------------------------
# Interactive wizard
# -----------------------------------------------------------------------------

run_interactive_wizard() {
  [[ "$DO_INTERACTIVE" -eq 1 ]] || return 0
  step "Interactive setup"

  echo ""
  echo "  Select your cellular carrier (for LTE + phone hotspot), or skip:"
  echo "    1) AT&T"
  echo "    2) T-Mobile"
  echo "    3) Verizon"
  echo "    4) None / Wi‑Fi only"
  read -r -p "  Choice [4]: " carrier_choice
  carrier_choice="${carrier_choice:-4}"
  case "$carrier_choice" in
    1) CARRIER="att" ;;
    2) CARRIER="tmobile" ;;
    3) CARRIER="verizon" ;;
    *) CARRIER="" ;;
  esac
  [[ -n "$CARRIER" ]] && ok "Carrier: ${CARRIER}"

  if prompt_yes_no "Enable SSH for easier laptop access?" "y"; then
    DO_ENABLE_SSH=1
  fi

  if [[ -n "$CARRIER" ]] && prompt_yes_no "Apply ${CARRIER} data plan now (before reboot)?" "y"; then
    DO_APPLY_CARRIER_NOW=1
  fi

  if prompt_yes_no "Reboot automatically when finished?" "y"; then
    DO_REBOOT=1
  else
    DO_REBOOT=0
  fi
}

confirm_install() {
  [[ "$DO_SKIP_CONFIRM" -eq 1 || "$DO_DRY_RUN" -eq 1 ]] && return 0
  step "Confirm installation"
  echo ""
  echo "  This will:"
  echo "    • Clone LaneSync Pilot from GitHub"
  echo "    • Install to ${OPENPILOT_DIR}"
  echo "    • Enable V2I, phone nav, and dashcam API"
  [[ -n "$CARRIER" ]] && echo "    • Configure ${CARRIER} cellular + hotspot"
  [[ "$DO_BACKUP" -eq 1 ]] && echo "    • Backup existing openpilot if present"
  echo ""
  prompt_yes_no "Proceed with install?" "y" || die "Install cancelled by user."
}

# -----------------------------------------------------------------------------
# Params
# -----------------------------------------------------------------------------

set_param() {
  local key="$1" value="$2"
  run mkdir -p /data/params/d
  if [[ "$DO_DRY_RUN" -eq 1 ]]; then
    echo -e "${DIM}    param ${key}=${value}${NC}"
    return 0
  fi
  printf '%s' "$value" > "/data/params/d/${key}"
  log "param ${key}=${value}"
}

get_param() {
  local key="$1" default="${2:-}"
  if [[ -f "/data/params/d/${key}" ]]; then
    cat "/data/params/d/${key}"
  else
    echo -n "$default"
  fi
}

enable_ssh() {
  [[ "$DO_ENABLE_SSH" -eq 1 ]] || return 0
  step "Enabling SSH"
  set_param "SshEnabled" "1"
  ok "SSH enabled — connect: ssh comma@${HOTSPOT_IP}"
}

# -----------------------------------------------------------------------------
# Backup / restore
# -----------------------------------------------------------------------------

list_backups() {
  ls -1dt /data/openpilot.bak.* 2>/dev/null || true
}

backup_existing() {
  if [[ "$DO_BACKUP" -eq 0 ]]; then
    warn "Backup skipped (--no-backup)"
    return
  fi
  step "Backing up existing openpilot"
  if [[ -e "$OPENPILOT_DIR" && ! -L "$OPENPILOT_DIR" ]]; then
    local backup="${OPENPILOT_DIR}.bak.${STAMP}"
    run mv "$OPENPILOT_DIR" "$backup"
    ok "Saved ${backup}"
  elif [[ -L "$OPENPILOT_DIR" ]]; then
    run rm -f "$OPENPILOT_DIR"
    ok "Removed old symlink"
  else
    ok "Nothing to backup"
  fi
}

restore_latest_backup() {
  step "Restoring from backup"
  local latest
  latest="$(list_backups | head -1)"
  [[ -n "$latest" ]] || die "No backups found matching /data/openpilot.bak.*"
  run rm -f "$OPENPILOT_DIR"
  run cp -a "$latest" "$OPENPILOT_DIR"
  ok "Restored ${latest} → ${OPENPILOT_DIR}"
  write_continue_sh
  warn "Reboot recommended"
}

prune_old_backups() {
  step "Pruning old backups (>14 days)"
  local count=0
  while IFS= read -r dir; do
    [[ -n "$dir" ]] || continue
    run rm -rf "$dir"
    log "removed ${dir}"
    count=$((count + 1))
  done < <(find /data -maxdepth 1 -name 'openpilot.bak.*' -mtime +14 2>/dev/null)
  ok "Removed ${count} old backup(s)"
}

# -----------------------------------------------------------------------------
# Git install
# -----------------------------------------------------------------------------

stop_onroad() {
  step "Process check"
  if pgrep -f "selfdrive/manager/manager.py" >/dev/null 2>&1; then
    warn "openpilot manager running — reboot required after install"
  else
    ok "Safe to install"
  fi
}

clone_repo() {
  step "Cloning repository"
  run rm -rf "$REPO_DIR"
  log "git clone ${REPO_URL} branch=${BRANCH}"
  if [[ "$DO_DRY_RUN" -eq 0 ]]; then
    if ! git clone --depth 1 --branch "$BRANCH" --recurse-submodules --shallow-submodules \
        "$REPO_URL" "$REPO_DIR" 2>&1 | tee -a "$LOG_FILE"; then
      die "Clone failed. Try: --branch main or check network."
    fi
  fi
  [[ "$DO_DRY_RUN" -eq 1 || -d "${REPO_DIR}/lanesync-pilot" ]] \
    || die "lanesync-pilot/ missing in repo"
  ok "Cloned to ${REPO_DIR}"
}

update_repo() {
  step "Updating repository"
  [[ -d "$REPO_DIR/.git" ]] || die "No install at ${REPO_DIR}. Run without --update."
  if [[ "$DO_DRY_RUN" -eq 1 ]]; then
    echo -e "${DIM}    (dry-run) git pull${NC}"
    return
  fi
  cd "$REPO_DIR"
  git fetch origin "$BRANCH" --depth 1
  git checkout "$BRANCH"
  git pull --ff-only origin "$BRANCH" 2>&1 | tee -a "$LOG_FILE"
  cd "${REPO_DIR}/lanesync-pilot"
  git submodule update --init --depth 1 --jobs "$(nproc 2>/dev/null || echo 2)"
  ok "Updated to latest ${BRANCH}"
}

link_openpilot() {
  step "Linking /data/openpilot"
  run ln -sfn "${REPO_DIR}/lanesync-pilot" "$OPENPILOT_DIR"
  ok "${OPENPILOT_DIR} → lanesync-pilot"
}

init_submodules() {
  step "Git submodules"
  if [[ "$DO_DRY_RUN" -eq 1 ]]; then
    echo -e "${DIM}    (dry-run) submodule update${NC}"
    return
  fi
  cd "${REPO_DIR}/lanesync-pilot"
  if git submodule update --init --depth 1 --jobs "$(nproc 2>/dev/null || echo 2)" \
      2>&1 | tee -a "$LOG_FILE"; then
    ok "Submodules ready"
  else
    warn "Submodule warnings — see ${LOG_FILE}"
  fi
}

write_continue_sh() {
  step "Boot launcher"
  if [[ "$DO_DRY_RUN" -eq 1 ]]; then
    echo -e "${DIM}    (dry-run) ${CONTINUE_SH}${NC}"
    return
  fi
  cat > "${CONTINUE_SH}.new" <<'EOF'
#!/usr/bin/env bash
# LaneSync Pilot — generated by install.sh (app.lanesyncpilot.ai)
cd /data/openpilot
exec ./launch_openpilot.sh
EOF
  chmod +x "${CONTINUE_SH}.new"
  mv "${CONTINUE_SH}.new" "$CONTINUE_SH"
  ok "${CONTINUE_SH}"
}

write_manifest() {
  step "Writing install manifest"
  if [[ "$DO_DRY_RUN" -eq 1 ]]; then return; fi
  cat > "$MANIFEST_FILE" <<EOF
{
  "name": "${LANESYNC_NAME}",
  "version": "${LANESYNC_VERSION}",
  "openpilot_base": "${OPENPILOT_BASE_VERSION}",
  "installed_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "branch": "${BRANCH}",
  "repo": "${REPO_URL}",
  "website": "${WEBSITE}",
  "carrier": "${CARRIER:-none}",
  "carrier_profile": "${CARRIER_PROFILE}",
  "ports": {
    "v2i_udp": ${PORT_V2I_UDP},
    "phonenav_http": ${PORT_PHONENAV_HTTP},
    "dashcam_http": ${PORT_DASHCAM_HTTP}
  },
  "paths": {
    "openpilot": "${OPENPILOT_DIR}",
    "repo": "${REPO_DIR}",
    "log": "${LOG_FILE}"
  }
}
EOF
  ok "${MANIFEST_FILE}"
}

# -----------------------------------------------------------------------------
# LaneSync features
# -----------------------------------------------------------------------------

enable_lanesync_features() {
  step "LaneSync feature params"

  set_param "LaneSyncVersion" "$LANESYNC_VERSION"
  set_param "V2IEnabled" "1"
  set_param "PhoneNavEnabled" "1"
  set_param "DashcamApiEnabled" "1"
  set_param "V2IPort" "${PORT_V2I_UDP}"
  set_param "PhoneNavPort" "${PORT_PHONENAV_HTTP}"
  set_param "DashcamApiPort" "${PORT_DASHCAM_HTTP}"

  echo ""
  echo -e "  ${BOLD}Service${NC}              ${BOLD}Port${NC}    ${BOLD}Daemon${NC}"
  hr
  echo -e "  V2I (RSU / SPaT)     ${PORT_V2I_UDP}     v2id, v2inetd"
  echo -e "  Phone navigation     ${PORT_PHONENAV_HTTP}    phonenavd"
  echo -e "  Dashcam API          ${PORT_DASHCAM_HTTP}    dashcamd"
  echo -e "  AT&T LTE             —       attd"
  echo -e "  T-Mobile LTE         —       tmobiled"
  echo -e "  Verizon LTE          —       verizond"
  hr
  ok "Features enabled"
}

enable_carrier() {
  [[ -n "$CARRIER" ]] || return 0
  step "Carrier: ${CARRIER}"

  set_param "AttDataPlanEnabled" "$([[ "$CARRIER" == "att" ]] && echo 1 || echo 0)"
  set_param "TmobileDataPlanEnabled" "$([[ "$CARRIER" == "tmobile" ]] && echo 1 || echo 0)"
  set_param "VerizonDataPlanEnabled" "$([[ "$CARRIER" == "verizon" ]] && echo 1 || echo 0)"
  set_param "AttDataPlanProfile" "$([[ "$CARRIER" == "att" ]] && echo "$CARRIER_PROFILE" || echo consumer)"
  set_param "TmobileDataPlanProfile" "$([[ "$CARRIER" == "tmobile" ]] && echo "$CARRIER_PROFILE" || echo consumer)"
  set_param "VerizonDataPlanProfile" "$([[ "$CARRIER" == "verizon" ]] && echo "$CARRIER_PROFILE" || echo consumer)"

  local carrier_dir="${REPO_DIR}/lanesync-pilot/${CARRIER}"
  if [[ "$DO_DRY_RUN" -eq 0 && -d "$carrier_dir" ]]; then
    run mkdir -p "/data/${CARRIER}"
    run cp -a "${carrier_dir}/." "/data/${CARRIER}/"
    [[ -f "/data/${CARRIER}/apply_dataplan.sh" ]] && run chmod +x "/data/${CARRIER}/apply_dataplan.sh"
    ok "Configs copied to /data/${CARRIER}"
  fi

  if [[ "$DO_APPLY_CARRIER_NOW" -eq 1 && -x "/data/${CARRIER}/apply_dataplan.sh" ]]; then
    log "Running apply_dataplan.sh ${CARRIER_PROFILE}"
    if [[ "$DO_DRY_RUN" -eq 0 ]]; then
      "/data/${CARRIER}/apply_dataplan.sh" "$CARRIER_PROFILE" 2>&1 | tee -a "$LOG_FILE" || \
        warn "apply_dataplan.sh returned non-zero — may need reboot"
    fi
  fi

  ok "${CARRIER} enabled (profile: ${CARRIER_PROFILE})"
}

# -----------------------------------------------------------------------------
# Verification
# -----------------------------------------------------------------------------

check_file() {
  local path="$1" label="$2"
  if [[ -e "$path" ]]; then
    echo -e "    ${GREEN}✓${NC} ${label}"
    return 0
  fi
  echo -e "    ${RED}✗${NC} ${label}"
  return 1
}

verify_install() {
  step "Verification"
  if [[ "$DO_DRY_RUN" -eq 1 ]]; then
    ok "Skipped (dry-run)"
    return
  fi

  local fail=0
  check_file "$OPENPILOT_DIR" "openpilot path" || fail=1
  check_file "${OPENPILOT_DIR}/launch_openpilot.sh" "launch_openpilot.sh" || fail=1
  check_file "$CONTINUE_SH" "continue.sh" || fail=1
  check_file "${OPENPILOT_DIR}/system/v2i/v2id.py" "v2id.py" || fail=1
  check_file "${OPENPILOT_DIR}/system/v2i/phonenavd.py" "phonenavd.py" || fail=1
  check_file "${OPENPILOT_DIR}/system/dashcam/dashcamd.py" "dashcamd.py" || fail=1
  check_file "${OPENPILOT_DIR}/mobile/android" "Android app sources" || fail=1
  check_file "${OPENPILOT_DIR}/docs/LANESYNC.md" "LANESYNC.md" || fail=1

  echo ""
  echo -e "  ${DIM}Params${NC}"
  echo -e "    LaneSyncVersion = $(get_param LaneSyncVersion '?')"
  echo -e "    V2IEnabled      = $(get_param V2IEnabled '?')"
  echo -e "    PhoneNavEnabled = $(get_param PhoneNavEnabled '?')"
  echo -e "    DashcamApiEnabled = $(get_param DashcamApiEnabled '?')"

  [[ "$fail" -eq 0 ]] && ok "Verification passed" || warn "Some checks failed — see ${LOG_FILE}"
}

print_status() {
  print_banner
  echo -e "${BOLD}Install status${NC}"
  hr

  if [[ -L "$OPENPILOT_DIR" ]]; then
    echo -e "  openpilot:  ${GREEN}symlink${NC} → $(readlink "$OPENPILOT_DIR")"
  elif [[ -d "$OPENPILOT_DIR" ]]; then
    echo -e "  openpilot:  ${YELLOW}directory${NC} (not LaneSync symlink)"
  else
    echo -e "  openpilot:  ${RED}not installed${NC}"
  fi

  [[ -d "$REPO_DIR" ]] && echo -e "  repo:       ${GREEN}${REPO_DIR}${NC}" || echo -e "  repo:       ${RED}missing${NC}"
  [[ -f "$MANIFEST_FILE" ]] && cat "$MANIFEST_FILE" || echo -e "  manifest:   none"
  echo ""
  echo -e "${BOLD}Backups${NC}"
  local backups
  backups="$(list_backups)"
  if [[ -n "$backups" ]]; then
    echo "$backups" | while read -r b; do echo "    $b"; done
  else
    echo "    (none)"
  fi
  hr
  echo -e "${BOLD}Params${NC}"
  echo "    LaneSyncVersion=$(get_param LaneSyncVersion n/a)"
  echo "    V2IEnabled=$(get_param V2IEnabled n/a)"
  echo "    PhoneNavEnabled=$(get_param PhoneNavEnabled n/a)"
  echo "    DashcamApiEnabled=$(get_param DashcamApiEnabled n/a)"
  hr
  exit 0
}

# -----------------------------------------------------------------------------
# Guides
# -----------------------------------------------------------------------------

print_post_install_guide() {
  echo ""
  echo -e "${BOLD}╔══════════════════════════════════════════════════════════════════╗${NC}"
  echo -e "${BOLD}║${NC}  ${GREEN}LaneSync Pilot ${LANESYNC_VERSION} installed${NC}                              ${BOLD}║${NC}"
  echo -e "${BOLD}╚══════════════════════════════════════════════════════════════════╝${NC}"

  cat <<GUIDE

${BOLD}━━━ In your car ━━━${NC}
  1. Reboot completes → openpilot starts from /data/continue.sh
  2. Home screen shows ${BOLD}LaneSync${NC} branding and version ${LANESYNC_VERSION}
  3. Engage on supported roads per normal openpilot usage

${BOLD}━━━ comma UI (on device) ━━━${NC}
  Settings → Developer
    • Vehicle-to-Infrastructure (V2I)     — ON
    • iPhone Navigation (CarPlay bridge)  — ON
    • AT&T / T-Mobile / Verizon           — pick one carrier
  Settings → Device → uninstall/reinstall uses custom URL when available:
    ${WEBSITE}

${BOLD}━━━ Phone — Android ━━━${NC}
  1. Install LaneSync Pilot app (Google Play / APK when published)
  2. Connect phone to comma Wi‑Fi hotspot
  3. App talks to ${WEBSITE} (cloud) and local dashcam API
  4. Android Auto navigation bridge via phonenavd (${PORT_PHONENAV_HTTP})

${BOLD}━━━ Phone — iPhone ━━━${NC}
  1. Join comma hotspot (${HOTSPOT_IP})
  2. Shortcuts automation → http://${HOTSPOT_IP}:${PORT_PHONENAV_HTTP}
  3. Guide: lanesync-pilot/tools/v2i/ios/README.md

${BOLD}━━━ Dashcam clips ━━━${NC}
  • Bookmark button on comma saves a segment
  • Local API:  http://${HOTSPOT_IP}:${PORT_DASHCAM_HTTP}/health
  • List clips: http://${HOTSPOT_IP}:${PORT_DASHCAM_HTTP}/clips
  • Cloud sync via ${WEBSITE} when backend is live

${BOLD}━━━ V2I testing (laptop on same Wi‑Fi) ━━━${NC}
  cd /data/openpilot
  python3 tools/v2i/v2i_sender.py --host ${HOTSPOT_IP} --demo
  python3 tools/v2i/phone_nav_sender.py --host ${HOTSPOT_IP}
  python3 tools/v2i/hud_mockup_server.py --comma-ip ${HOTSPOT_IP}

${BOLD}━━━ Maintenance ━━━${NC}
  Update:    bash <(curl -fsSL ${WEBSITE}/install.sh) --update
  Status:    bash <(curl -fsSL ${WEBSITE}/install.sh) --status
  Restore:   bash <(curl -fsSL ${WEBSITE}/install.sh) --restore-backup
  Uninstall: bash <(curl -fsSL ${WEBSITE}/install.sh) --uninstall
  Log:       ${LOG_FILE}
  Manifest:  ${MANIFEST_FILE}

${BOLD}━━━ Support ━━━${NC}
  Website:  ${WEBSITE}
  GitHub:   https://github.com/lanesyncpilot/lanesyncpilot
  Email:    ${SUPPORT_EMAIL}

${DIM}LaneSync Pilot is experimental. Not affiliated with comma.ai. Drive safely.${NC}

GUIDE
}

print_troubleshooting() {
  cat <<TROUBLE

${BOLD}━━━ Troubleshooting ━━━${NC}

${BOLD}Install failed during git clone${NC}
  • Connect comma to Wi‑Fi or ensure SIM has data
  • Retry: bash <(curl -fsSL ${WEBSITE}/install.sh)

${BOLD}openpilot does not start after reboot${NC}
  • Check: ls -la /data/openpilot /data/continue.sh
  • Restore: bash <(curl -fsSL ${WEBSITE}/install.sh) --restore-backup

${BOLD}Phone cannot reach dashcam API${NC}
  • Phone must be on comma hotspot (${HOTSPOT_IP})
  • curl http://${HOTSPOT_IP}:${PORT_DASHCAM_HTTP}/health

${BOLD}LTE / hotspot not working${NC}
  • bash <(curl -fsSL ${WEBSITE}/install.sh) -c tmobile --apply-carrier
  • Or run: /data/<carrier>/apply_dataplan.sh consumer
  • Reboot after inserting SIM

${BOLD}V2I not showing on HUD${NC}
  • params set V2IEnabled 1  (or use Developer toggle)
  • Send test: python3 tools/v2i/v2i_sender.py --host ${HOTSPOT_IP} --demo

TROUBLE
}

reboot_device() {
  if [[ "$DO_REBOOT" -eq 0 ]]; then
    warn "No reboot (--no-reboot). Run: reboot"
    return
  fi
  if [[ "$DO_DRY_RUN" -eq 1 ]]; then
    echo -e "${DIM}    (dry-run) reboot${NC}"
    return
  fi
  echo ""
  echo -e "${BOLD}Rebooting in 15 seconds…${NC}  ${DIM}Ctrl+C to cancel${NC}"
  for i in 15 10 5 4 3 2 1; do
    sleep 1
    echo -ne "\r  ${i}s   "
  done
  echo ""
  reboot
}

# -----------------------------------------------------------------------------
# Uninstall
# -----------------------------------------------------------------------------

do_uninstall() {
  preflight
  step "Uninstall"
  [[ -L "$OPENPILOT_DIR" ]] && run rm -f "$OPENPILOT_DIR" && ok "Removed symlink"
  [[ -d "$REPO_DIR" ]] && run rm -rf "$REPO_DIR" && ok "Removed repo"
  [[ -f "$MANIFEST_FILE" ]] && run rm -f "$MANIFEST_FILE"
  echo ""
  ok "Uninstalled. Backups: $(list_backups | wc -l | tr -d ' ') saved"
  print_troubleshooting
  exit 0
}

# -----------------------------------------------------------------------------
# Main flows
# -----------------------------------------------------------------------------

do_fresh_install() {
  run_interactive_wizard
  confirm_install
  stop_onroad
  backup_existing
  clone_repo
  link_openpilot
  init_submodules
  write_continue_sh
  enable_lanesync_features
  enable_carrier
  enable_ssh
  write_manifest
  verify_install
  print_post_install_guide
  print_troubleshooting
  reboot_device
}

do_update_install() {
  [[ -d "$REPO_DIR" ]] || die "Not installed. Run without --update."
  stop_onroad
  update_repo
  link_openpilot
  enable_lanesync_features
  enable_carrier
  enable_ssh
  write_manifest
  verify_install
  print_post_install_guide
  reboot_device
}

main() {
  parse_args "$@"

  if [[ "$DO_STATUS" -eq 1 ]]; then
    print_status
  fi

  if [[ "$DO_PRUNE_BACKUPS" -eq 1 ]]; then
    preflight
    prune_old_backups
    exit 0
  fi

  if [[ "$DO_RESTORE" -eq 1 ]]; then
    preflight
    restore_latest_backup
    exit 0
  fi

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
#!/usr/bin/env bash
# =============================================================================
# LaneSync Pilot — in-car installer for comma 3X / comma four
# =============================================================================
#
#   bash <(curl -fsSL https://app.lanesyncpilot.ai/install.sh)
#   bash <(curl -fsSL https://raw.githubusercontent.com/lanesyncpilot/lanesyncpilot/main/install.sh)
#
# =============================================================================
set -euo pipefail

LANESYNC_VERSION="1.0.0"
LANESYNC_NAME="LaneSync Pilot"
OPENPILOT_BASE_VERSION="0.11.0"
REPO_URL="${LANESYNC_REPO_URL:-https://github.com/lanesyncpilot/lanesyncpilot.git}"
BRANCH="${LANESYNC_BRANCH:-main}"
WEBSITE="${LANESYNC_WEBSITE:-https://app.lanesyncpilot.ai}"
GITHUB_RAW="https://raw.githubusercontent.com/lanesyncpilot/lanesyncpilot/main/install.sh"
SUPPORT_EMAIL="${LANESYNC_SUPPORT_EMAIL:-support@lanesyncpilot.ai}"

REPO_DIR="/data/lanesync-repo"
OPENPILOT_DIR="/data/openpilot"
CONTINUE_SH="/data/continue.sh"
LOG_FILE="/data/lanesync-install.log"
MANIFEST_FILE="/data/lanesync-install.json"
STAMP="$(date +%Y%m%d-%H%M%S)"
MIN_FREE_MB=1500
HOTSPOT_IP="${LANESYNC_HOTSPOT_IP:-192.168.43.1}"

# Ports (LaneSync services)
PORT_V2I_UDP=7701
PORT_PHONENAV_HTTP=7710
PORT_DASHCAM_HTTP=7720

# Runtime flags
DO_UPDATE=0
DO_UNINSTALL=0
DO_REBOOT=1
DO_BACKUP=1
DO_DRY_RUN=0
DO_INTERACTIVE=0
DO_STATUS=0
DO_RESTORE=0
DO_PRUNE_BACKUPS=0
DO_ENABLE_SSH=0
DO_APPLY_CARRIER_NOW=0
DO_SKIP_CONFIRM=0
CARRIER=""
CARRIER_PROFILE="consumer"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

TOTAL_STEPS=14
CURRENT_STEP=0

# -----------------------------------------------------------------------------
# UI helpers
# -----------------------------------------------------------------------------

log() {
  local msg="[$(date '+%Y-%m-%d %H:%M:%S')] $*"
  echo -e "${CYAN}[lanesync]${NC} $*"
  [[ -w /data ]] && echo "$msg" >> "$LOG_FILE" 2>/dev/null || true
}

ok()   { echo -e "${GREEN}[ok]${NC} $*"; log "OK: $*"; }
warn() { echo -e "${YELLOW}[warn]${NC} $*"; log "WARN: $*"; }
die()  { echo -e "${RED}[error]${NC} $*" >&2; log "FATAL: $*"; exit 1; }

step() {
  CURRENT_STEP=$((CURRENT_STEP + 1))
  echo ""
  echo -e "${BOLD}${BLUE}[${CURRENT_STEP}/${TOTAL_STEPS}]${NC} ${BOLD}$*${NC}"
  log "STEP ${CURRENT_STEP}/${TOTAL_STEPS}: $*"
}

run() {
  if [[ "$DO_DRY_RUN" -eq 1 ]]; then
    echo -e "${DIM}    (dry-run) $*${NC}"
    return 0
  fi
  eval "$@"
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "Missing required command: $1"
}

hr() {
  echo -e "${DIM}────────────────────────────────────────────────────────────────${NC}"
}

prompt_yes_no() {
  local question="$1"
  local default="${2:-y}"
  if [[ "$DO_SKIP_CONFIRM" -eq 1 || "$DO_DRY_RUN" -eq 1 ]]; then
    return 0
  fi
  local hint="[Y/n]"
  [[ "$default" == "n" ]] && hint="[y/N]"
  read -r -p "$(echo -e "${BOLD}${question}${NC} ${hint}: ")" reply
  reply="${reply:-$default}"
  [[ "$reply" =~ ^[Yy] ]]
}

# -----------------------------------------------------------------------------
# Help
# -----------------------------------------------------------------------------

usage() {
  cat <<EOF
${BOLD}${LANESYNC_NAME} installer v${LANESYNC_VERSION}${NC}
Based on openpilot v${OPENPILOT_BASE_VERSION} · ${WEBSITE}

${BOLD}━━━ Quick install ━━━${NC}
  bash <(curl -fsSL ${WEBSITE}/install.sh)
  bash <(curl -fsSL ${GITHUB_RAW})

${BOLD}━━━ SSH from laptop ━━━${NC}
  ssh comma@<comma-ip> 'bash -s' < install.sh
  ssh comma@<comma-ip> 'bash -s' -- --carrier tmobile --apply-carrier < install.sh

${BOLD}━━━ Commands ━━━${NC}
  -h, --help                 Show this help
  -i, --interactive          Ask questions (carrier, SSH, confirm)
  -u, --update               Update existing install (git pull)
  -s, --status               Print install status and exit
  --uninstall                Remove LaneSync (keeps backups)
  --restore-backup           Restore latest /data/openpilot.bak.*
  --prune-backups            Remove openpilot backups older than 14 days
  -c, --carrier <name>       att | tmobile | verizon
  --carrier-profile <name>   consumer (default) or other profile in dataplan.json
  --apply-carrier            Run apply_dataplan.sh immediately (needs root)
  --enable-ssh               Enable SSH param on device
  -b, --branch <name>        Git branch (default: main)
  --no-reboot                Skip reboot at end
  --no-backup                Skip backup of existing /data/openpilot
  --yes                      Skip confirmation prompts
  --dry-run                  Print actions without changing anything

${BOLD}━━━ Environment variables ━━━${NC}
  LANESYNC_REPO_URL          Override git clone URL
  LANESYNC_BRANCH            Override branch
  LANESYNC_WEBSITE           Website URL shown in output
  LANESYNC_HOTSPOT_IP        Hotspot gateway (default 192.168.43.1)

${BOLD}━━━ What this installs ━━━${NC}
  Path          /data/openpilot  →  /data/lanesync-repo/lanesync-pilot
  Boot          /data/continue.sh launches openpilot
  V2I           UDP  ${PORT_V2I_UDP}   v2id, v2inetd
  Phone nav     HTTP ${PORT_PHONENAV_HTTP}  phonenavd (iPhone Shortcuts / Android app)
  Dashcam API   HTTP ${PORT_DASHCAM_HTTP}  dashcamd (mobile apps)
  Carriers      attd / tmobiled / verizond + Wi‑Fi hotspot

${BOLD}━━━ After install ━━━${NC}
  • Phone Wi‑Fi → comma hotspot (${HOTSPOT_IP})
  • Android app → ${WEBSITE}
  • Dashcam     → http://${HOTSPOT_IP}:${PORT_DASHCAM_HTTP}/clips
  • Developer   → Settings → Developer on comma UI
  • Docs        → lanesync-pilot/docs/LANESYNC.md

${BOLD}━━━ Troubleshooting ━━━${NC}
  bash <(curl -fsSL ${WEBSITE}/install.sh) --status
  cat ${LOG_FILE}
  bash <(curl -fsSL ${WEBSITE}/install.sh) --restore-backup

EOF
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h|--help) usage; exit 0 ;;
      -i|--interactive) DO_INTERACTIVE=1; shift ;;
      -u|--update) DO_UPDATE=1; shift ;;
      -s|--status) DO_STATUS=1; shift ;;
      --uninstall) DO_UNINSTALL=1; shift ;;
      --restore-backup) DO_RESTORE=1; shift ;;
      --prune-backups) DO_PRUNE_BACKUPS=1; shift ;;
      -c|--carrier)
        CARRIER="${2:-}"
        [[ -n "$CARRIER" ]] || die "--carrier requires att, tmobile, or verizon"
        shift 2
        ;;
      --carrier-profile)
        CARRIER_PROFILE="${2:-consumer}"
        shift 2
        ;;
      --apply-carrier) DO_APPLY_CARRIER_NOW=1; shift ;;
      --enable-ssh) DO_ENABLE_SSH=1; shift ;;
      -b|--branch)
        BRANCH="${2:-}"
        [[ -n "$BRANCH" ]] || die "--branch requires a branch name"
        shift 2
        ;;
      --no-reboot) DO_REBOOT=0; shift ;;
      --no-backup) DO_BACKUP=0; shift ;;
      --yes) DO_SKIP_CONFIRM=1; shift ;;
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
# Device info
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

detect_agnos_version() {
  if [[ -f /AGNOS ]]; then
    cat /AGNOS 2>/dev/null || echo "unknown"
  elif [[ -f /etc/agnos-version ]]; then
    cat /etc/agnos-version 2>/dev/null || echo "unknown"
  else
    echo "unknown"
  fi
}

detect_sim_status() {
  if command -v mmcli >/dev/null 2>&1; then
    mmcli -L 2>/dev/null | head -5 || echo "modem: unavailable"
  elif [[ -d /sys/class/net/wwan0 ]]; then
    echo "wwan0 interface present"
  else
    echo "no modem detected (Wi‑Fi-only install is fine)"
  fi
}

print_system_report() {
  step "System report"
  echo -e "  ${DIM}Hostname${NC}      $(hostname 2>/dev/null || echo n/a)"
  echo -e "  ${DIM}Device${NC}        $(detect_device_type)"
  echo -e "  ${DIM}AGNOS${NC}         $(detect_agnos_version)"
  echo -e "  ${DIM}Kernel${NC}        $(uname -r 2>/dev/null || echo n/a)"
  echo -e "  ${DIM}Uptime${NC}        $(uptime -p 2>/dev/null || uptime 2>/dev/null || echo n/a)"
  echo -e "  ${DIM}SIM / LTE${NC}     $(detect_sim_status)"
  if command -v df >/dev/null 2>&1; then
    echo -e "  ${DIM}Disk /data${NC}    $(df -h /data 2>/dev/null | awk 'NR==2 {print $3 " used, " $4 " free (" $5 ")"}')"
  fi
  if [[ -f "$MANIFEST_FILE" ]]; then
    echo -e "  ${DIM}Last install${NC}  $(grep -o '"installed_at":"[^"]*"' "$MANIFEST_FILE" 2>/dev/null | cut -d'"' -f4 || echo unknown)"
  fi
  hr
}

# -----------------------------------------------------------------------------
# Preflight
# -----------------------------------------------------------------------------

check_disk_space() {
  step "Checking disk space"
  need_cmd df
  local free_kb free_mb
  free_kb="$(df -k /data 2>/dev/null | awk 'NR==2 {print $4}')"
  free_mb=$((free_kb / 1024))
  log "Free on /data: ${free_mb} MB (minimum ${MIN_FREE_MB} MB)"
  if [[ "$free_mb" -lt "$MIN_FREE_MB" ]]; then
    die "Insufficient disk space. Need ${MIN_FREE_MB} MB, found ${free_mb} MB.
Try: bash <(curl -fsSL ${WEBSITE}/install.sh) --prune-backups
Or delete old routes under /data/media/0/realdata/"
  fi
  ok "${free_mb} MB free"
}

check_network() {
  step "Checking network"
  local ok_net=0
  for host in github.com raw.githubusercontent.com; do
    if ping -c 1 -W 4 "$host" >/dev/null 2>&1; then
      ok "Reachable: ${host}"
      ok_net=1
      break
    fi
  done
  if [[ "$ok_net" -eq 0 ]]; then
    if ping -c 1 -W 4 8.8.8.8 >/dev/null 2>&1; then
      warn "Internet up but GitHub unreachable — clone may still work"
    else
      warn "No network. Connect Wi‑Fi or insert SIM before continuing."
      if ! prompt_yes_no "Continue without network?" "n"; then
        die "Aborted — connect network and retry."
      fi
    fi
  fi
}

check_prerequisites() {
  step "Checking tools"
  local missing=0
  for cmd in git ln chmod mv cp mkdir printf cat; do
    if command -v "$cmd" >/dev/null 2>&1; then
      echo -e "    ${GREEN}✓${NC} ${cmd}"
    else
      echo -e "    ${RED}✗${NC} ${cmd}"
      missing=1
    fi
  done
  [[ "$missing" -eq 0 ]] || die "Missing required commands"
  ok "Prerequisites satisfied"
}

preflight() {
  print_banner
  if ! is_comma_device; then
    die "Must run on a comma device.

  ssh comma@<ip> 'bash -s' < install.sh
  bash <(curl -fsSL ${WEBSITE}/install.sh)"
  fi

  if [[ "$(id -u)" -ne 0 ]]; then
    warn "Elevating to root"
    exec sudo -E bash "$0" "$@"
  fi

  mkdir -p /data
  : > "$LOG_FILE" 2>/dev/null || true
  log "=== LaneSync install ${LANESYNC_VERSION} branch=${BRANCH} ==="

  print_system_report
  check_prerequisites
  check_disk_space
  check_network
}

print_banner() {
  echo ""
  echo -e "${GREEN}"
  cat <<'BANNER'
    __  _____             _____
   / / |_   _| __ __ _  _|___ / _ __   ___  _ __   __ _
  / /    | || '__/ _` |/ _ \ / _| '_ \ / _ \| '_ \ / _` |
 / /__   | || | | (_| | (_) | |_| | | | (_) | | | | (_| |
/_____|  |_||_|  \__,_|\___/ \__|_| |_|\___/|_| |_|\__,_|
BANNER
  echo -e "${NC}"
  echo -e "${BOLD}  LaneSync Pilot${NC}  in-car installer  ${DIM}v${LANESYNC_VERSION}${NC}"
  echo -e "  ${DIM}V2I · Android Auto · Dashcam · Safety · Cloud${NC}"
  hr
  echo -e "  Website     ${WEBSITE}"
  echo -e "  Repository  ${REPO_URL}"
  echo -e "  Branch      ${BRANCH}"
  [[ -n "$CARRIER" ]] && echo -e "  Carrier     ${CARRIER} (${CARRIER_PROFILE})"
  [[ "$DO_DRY_RUN" -eq 1 ]] && echo -e "  ${YELLOW}MODE: dry-run${NC}"
  [[ "$DO_INTERACTIVE" -eq 1 ]] && echo -e "  ${MAGENTA}MODE: interactive${NC}"
  hr
}

# -----------------------------------------------------------------------------
# Interactive wizard
# -----------------------------------------------------------------------------

run_interactive_wizard() {
  [[ "$DO_INTERACTIVE" -eq 1 ]] || return 0
  step "Interactive setup"

  echo ""
  echo "  Select your cellular carrier (for LTE + phone hotspot), or skip:"
  echo "    1) AT&T"
  echo "    2) T-Mobile"
  echo "    3) Verizon"
  echo "    4) None / Wi‑Fi only"
  read -r -p "  Choice [4]: " carrier_choice
  carrier_choice="${carrier_choice:-4}"
  case "$carrier_choice" in
    1) CARRIER="att" ;;
    2) CARRIER="tmobile" ;;
    3) CARRIER="verizon" ;;
    *) CARRIER="" ;;
  esac
  [[ -n "$CARRIER" ]] && ok "Carrier: ${CARRIER}"

  if prompt_yes_no "Enable SSH for easier laptop access?" "y"; then
    DO_ENABLE_SSH=1
  fi

  if [[ -n "$CARRIER" ]] && prompt_yes_no "Apply ${CARRIER} data plan now (before reboot)?" "y"; then
    DO_APPLY_CARRIER_NOW=1
  fi

  if prompt_yes_no "Reboot automatically when finished?" "y"; then
    DO_REBOOT=1
  else
    DO_REBOOT=0
  fi
}

confirm_install() {
  [[ "$DO_SKIP_CONFIRM" -eq 1 || "$DO_DRY_RUN" -eq 1 ]] && return 0
  step "Confirm installation"
  echo ""
  echo "  This will:"
  echo "    • Clone LaneSync Pilot from GitHub"
  echo "    • Install to ${OPENPILOT_DIR}"
  echo "    • Enable V2I, phone nav, and dashcam API"
  [[ -n "$CARRIER" ]] && echo "    • Configure ${CARRIER} cellular + hotspot"
  [[ "$DO_BACKUP" -eq 1 ]] && echo "    • Backup existing openpilot if present"
  echo ""
  prompt_yes_no "Proceed with install?" "y" || die "Install cancelled by user."
}

# -----------------------------------------------------------------------------
# Params
# -----------------------------------------------------------------------------

set_param() {
  local key="$1" value="$2"
  run mkdir -p /data/params/d
  if [[ "$DO_DRY_RUN" -eq 1 ]]; then
    echo -e "${DIM}    param ${key}=${value}${NC}"
    return 0
  fi
  printf '%s' "$value" > "/data/params/d/${key}"
  log "param ${key}=${value}"
}

get_param() {
  local key="$1" default="${2:-}"
  if [[ -f "/data/params/d/${key}" ]]; then
    cat "/data/params/d/${key}"
  else
    echo -n "$default"
  fi
}

enable_ssh() {
  [[ "$DO_ENABLE_SSH" -eq 1 ]] || return 0
  step "Enabling SSH"
  set_param "SshEnabled" "1"
  ok "SSH enabled — connect: ssh comma@${HOTSPOT_IP}"
}

# -----------------------------------------------------------------------------
# Backup / restore
# -----------------------------------------------------------------------------

list_backups() {
  ls -1dt /data/openpilot.bak.* 2>/dev/null || true
}

backup_existing() {
  if [[ "$DO_BACKUP" -eq 0 ]]; then
    warn "Backup skipped (--no-backup)"
    return
  fi
  step "Backing up existing openpilot"
  if [[ -e "$OPENPILOT_DIR" && ! -L "$OPENPILOT_DIR" ]]; then
    local backup="${OPENPILOT_DIR}.bak.${STAMP}"
    run mv "$OPENPILOT_DIR" "$backup"
    ok "Saved ${backup}"
  elif [[ -L "$OPENPILOT_DIR" ]]; then
    run rm -f "$OPENPILOT_DIR"
    ok "Removed old symlink"
  else
    ok "Nothing to backup"
  fi
}

restore_latest_backup() {
  step "Restoring from backup"
  local latest
  latest="$(list_backups | head -1)"
  [[ -n "$latest" ]] || die "No backups found matching /data/openpilot.bak.*"
  run rm -f "$OPENPILOT_DIR"
  run cp -a "$latest" "$OPENPILOT_DIR"
  ok "Restored ${latest} → ${OPENPILOT_DIR}"
  write_continue_sh
  warn "Reboot recommended"
}

prune_old_backups() {
  step "Pruning old backups (>14 days)"
  local count=0
  while IFS= read -r dir; do
    [[ -n "$dir" ]] || continue
    run rm -rf "$dir"
    log "removed ${dir}"
    count=$((count + 1))
  done < <(find /data -maxdepth 1 -name 'openpilot.bak.*' -mtime +14 2>/dev/null)
  ok "Removed ${count} old backup(s)"
}

# -----------------------------------------------------------------------------
# Git install
# -----------------------------------------------------------------------------

stop_onroad() {
  step "Process check"
  if pgrep -f "selfdrive/manager/manager.py" >/dev/null 2>&1; then
    warn "openpilot manager running — reboot required after install"
  else
    ok "Safe to install"
  fi
}

clone_repo() {
  step "Cloning repository"
  run rm -rf "$REPO_DIR"
  log "git clone ${REPO_URL} branch=${BRANCH}"
  if [[ "$DO_DRY_RUN" -eq 0 ]]; then
    if ! git clone --depth 1 --branch "$BRANCH" --recurse-submodules --shallow-submodules \
        "$REPO_URL" "$REPO_DIR" 2>&1 | tee -a "$LOG_FILE"; then
      die "Clone failed. Try: --branch main or check network."
    fi
  fi
  [[ "$DO_DRY_RUN" -eq 1 || -d "${REPO_DIR}/lanesync-pilot" ]] \
    || die "lanesync-pilot/ missing in repo"
  ok "Cloned to ${REPO_DIR}"
}

update_repo() {
  step "Updating repository"
  [[ -d "$REPO_DIR/.git" ]] || die "No install at ${REPO_DIR}. Run without --update."
  if [[ "$DO_DRY_RUN" -eq 1 ]]; then
    echo -e "${DIM}    (dry-run) git pull${NC}"
    return
  fi
  cd "$REPO_DIR"
  git fetch origin "$BRANCH" --depth 1
  git checkout "$BRANCH"
  git pull --ff-only origin "$BRANCH" 2>&1 | tee -a "$LOG_FILE"
  cd "${REPO_DIR}/lanesync-pilot"
  git submodule update --init --depth 1 --jobs "$(nproc 2>/dev/null || echo 2)"
  ok "Updated to latest ${BRANCH}"
}

link_openpilot() {
  step "Linking /data/openpilot"
  run ln -sfn "${REPO_DIR}/lanesync-pilot" "$OPENPILOT_DIR"
  ok "${OPENPILOT_DIR} → lanesync-pilot"
}

init_submodules() {
  step "Git submodules"
  if [[ "$DO_DRY_RUN" -eq 1 ]]; then
    echo -e "${DIM}    (dry-run) submodule update${NC}"
    return
  fi
  cd "${REPO_DIR}/lanesync-pilot"
  if git submodule update --init --depth 1 --jobs "$(nproc 2>/dev/null || echo 2)" \
      2>&1 | tee -a "$LOG_FILE"; then
    ok "Submodules ready"
  else
    warn "Submodule warnings — see ${LOG_FILE}"
  fi
}

write_continue_sh() {
  step "Boot launcher"
  if [[ "$DO_DRY_RUN" -eq 1 ]]; then
    echo -e "${DIM}    (dry-run) ${CONTINUE_SH}${NC}"
    return
  fi
  cat > "${CONTINUE_SH}.new" <<'EOF'
#!/usr/bin/env bash
# LaneSync Pilot — generated by install.sh (app.lanesyncpilot.ai)
cd /data/openpilot
exec ./launch_openpilot.sh
EOF
  chmod +x "${CONTINUE_SH}.new"
  mv "${CONTINUE_SH}.new" "$CONTINUE_SH"
  ok "${CONTINUE_SH}"
}

write_manifest() {
  step "Writing install manifest"
  if [[ "$DO_DRY_RUN" -eq 1 ]]; then return; fi
  cat > "$MANIFEST_FILE" <<EOF
{
  "name": "${LANESYNC_NAME}",
  "version": "${LANESYNC_VERSION}",
  "openpilot_base": "${OPENPILOT_BASE_VERSION}",
  "installed_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "branch": "${BRANCH}",
  "repo": "${REPO_URL}",
  "website": "${WEBSITE}",
  "carrier": "${CARRIER:-none}",
  "carrier_profile": "${CARRIER_PROFILE}",
  "ports": {
    "v2i_udp": ${PORT_V2I_UDP},
    "phonenav_http": ${PORT_PHONENAV_HTTP},
    "dashcam_http": ${PORT_DASHCAM_HTTP}
  },
  "paths": {
    "openpilot": "${OPENPILOT_DIR}",
    "repo": "${REPO_DIR}",
    "log": "${LOG_FILE}"
  }
}
EOF
  ok "${MANIFEST_FILE}"
}

# -----------------------------------------------------------------------------
# LaneSync features
# -----------------------------------------------------------------------------

enable_lanesync_features() {
  step "LaneSync feature params"

  set_param "LaneSyncVersion" "$LANESYNC_VERSION"
  set_param "V2IEnabled" "1"
  set_param "PhoneNavEnabled" "1"
  set_param "DashcamApiEnabled" "1"
  set_param "V2IPort" "${PORT_V2I_UDP}"
  set_param "PhoneNavPort" "${PORT_PHONENAV_HTTP}"
  set_param "DashcamApiPort" "${PORT_DASHCAM_HTTP}"

  echo ""
  echo -e "  ${BOLD}Service${NC}              ${BOLD}Port${NC}    ${BOLD}Daemon${NC}"
  hr
  echo -e "  V2I (RSU / SPaT)     ${PORT_V2I_UDP}     v2id, v2inetd"
  echo -e "  Phone navigation     ${PORT_PHONENAV_HTTP}    phonenavd"
  echo -e "  Dashcam API          ${PORT_DASHCAM_HTTP}    dashcamd"
  echo -e "  AT&T LTE             —       attd"
  echo -e "  T-Mobile LTE         —       tmobiled"
  echo -e "  Verizon LTE          —       verizond"
  hr
  ok "Features enabled"
}

enable_carrier() {
  [[ -n "$CARRIER" ]] || return 0
  step "Carrier: ${CARRIER}"

  set_param "AttDataPlanEnabled" "$([[ "$CARRIER" == "att" ]] && echo 1 || echo 0)"
  set_param "TmobileDataPlanEnabled" "$([[ "$CARRIER" == "tmobile" ]] && echo 1 || echo 0)"
  set_param "VerizonDataPlanEnabled" "$([[ "$CARRIER" == "verizon" ]] && echo 1 || echo 0)"
  set_param "AttDataPlanProfile" "$([[ "$CARRIER" == "att" ]] && echo "$CARRIER_PROFILE" || echo consumer)"
  set_param "TmobileDataPlanProfile" "$([[ "$CARRIER" == "tmobile" ]] && echo "$CARRIER_PROFILE" || echo consumer)"
  set_param "VerizonDataPlanProfile" "$([[ "$CARRIER" == "verizon" ]] && echo "$CARRIER_PROFILE" || echo consumer)"

  local carrier_dir="${REPO_DIR}/lanesync-pilot/${CARRIER}"
  if [[ "$DO_DRY_RUN" -eq 0 && -d "$carrier_dir" ]]; then
    run mkdir -p "/data/${CARRIER}"
    run cp -a "${carrier_dir}/." "/data/${CARRIER}/"
    [[ -f "/data/${CARRIER}/apply_dataplan.sh" ]] && run chmod +x "/data/${CARRIER}/apply_dataplan.sh"
    ok "Configs copied to /data/${CARRIER}"
  fi

  if [[ "$DO_APPLY_CARRIER_NOW" -eq 1 && -x "/data/${CARRIER}/apply_dataplan.sh" ]]; then
    log "Running apply_dataplan.sh ${CARRIER_PROFILE}"
    if [[ "$DO_DRY_RUN" -eq 0 ]]; then
      "/data/${CARRIER}/apply_dataplan.sh" "$CARRIER_PROFILE" 2>&1 | tee -a "$LOG_FILE" || \
        warn "apply_dataplan.sh returned non-zero — may need reboot"
    fi
  fi

  ok "${CARRIER} enabled (profile: ${CARRIER_PROFILE})"
}

# -----------------------------------------------------------------------------
# Verification
# -----------------------------------------------------------------------------

check_file() {
  local path="$1" label="$2"
  if [[ -e "$path" ]]; then
    echo -e "    ${GREEN}✓${NC} ${label}"
    return 0
  fi
  echo -e "    ${RED}✗${NC} ${label}"
  return 1
}

verify_install() {
  step "Verification"
  if [[ "$DO_DRY_RUN" -eq 1 ]]; then
    ok "Skipped (dry-run)"
    return
  fi

  local fail=0
  check_file "$OPENPILOT_DIR" "openpilot path" || fail=1
  check_file "${OPENPILOT_DIR}/launch_openpilot.sh" "launch_openpilot.sh" || fail=1
  check_file "$CONTINUE_SH" "continue.sh" || fail=1
  check_file "${OPENPILOT_DIR}/system/v2i/v2id.py" "v2id.py" || fail=1
  check_file "${OPENPILOT_DIR}/system/v2i/phonenavd.py" "phonenavd.py" || fail=1
  check_file "${OPENPILOT_DIR}/system/dashcam/dashcamd.py" "dashcamd.py" || fail=1
  check_file "${OPENPILOT_DIR}/mobile/android" "Android app sources" || fail=1
  check_file "${OPENPILOT_DIR}/docs/LANESYNC.md" "LANESYNC.md" || fail=1

  echo ""
  echo -e "  ${DIM}Params${NC}"
  echo -e "    LaneSyncVersion = $(get_param LaneSyncVersion '?')"
  echo -e "    V2IEnabled      = $(get_param V2IEnabled '?')"
  echo -e "    PhoneNavEnabled = $(get_param PhoneNavEnabled '?')"
  echo -e "    DashcamApiEnabled = $(get_param DashcamApiEnabled '?')"

  [[ "$fail" -eq 0 ]] && ok "Verification passed" || warn "Some checks failed — see ${LOG_FILE}"
}

print_status() {
  print_banner
  echo -e "${BOLD}Install status${NC}"
  hr

  if [[ -L "$OPENPILOT_DIR" ]]; then
    echo -e "  openpilot:  ${GREEN}symlink${NC} → $(readlink "$OPENPILOT_DIR")"
  elif [[ -d "$OPENPILOT_DIR" ]]; then
    echo -e "  openpilot:  ${YELLOW}directory${NC} (not LaneSync symlink)"
  else
    echo -e "  openpilot:  ${RED}not installed${NC}"
  fi

  [[ -d "$REPO_DIR" ]] && echo -e "  repo:       ${GREEN}${REPO_DIR}${NC}" || echo -e "  repo:       ${RED}missing${NC}"
  [[ -f "$MANIFEST_FILE" ]] && cat "$MANIFEST_FILE" || echo -e "  manifest:   none"
  echo ""
  echo -e "${BOLD}Backups${NC}"
  local backups
  backups="$(list_backups)"
  if [[ -n "$backups" ]]; then
    echo "$backups" | while read -r b; do echo "    $b"; done
  else
    echo "    (none)"
  fi
  hr
  echo -e "${BOLD}Params${NC}"
  echo "    LaneSyncVersion=$(get_param LaneSyncVersion n/a)"
  echo "    V2IEnabled=$(get_param V2IEnabled n/a)"
  echo "    PhoneNavEnabled=$(get_param PhoneNavEnabled n/a)"
  echo "    DashcamApiEnabled=$(get_param DashcamApiEnabled n/a)"
  hr
  exit 0
}

# -----------------------------------------------------------------------------
# Guides
# -----------------------------------------------------------------------------

print_post_install_guide() {
  echo ""
  echo -e "${BOLD}╔══════════════════════════════════════════════════════════════════╗${NC}"
  echo -e "${BOLD}║${NC}  ${GREEN}LaneSync Pilot ${LANESYNC_VERSION} installed${NC}                              ${BOLD}║${NC}"
  echo -e "${BOLD}╚══════════════════════════════════════════════════════════════════╝${NC}"

  cat <<GUIDE

${BOLD}━━━ In your car ━━━${NC}
  1. Reboot completes → openpilot starts from /data/continue.sh
  2. Home screen shows ${BOLD}LaneSync${NC} branding and version ${LANESYNC_VERSION}
  3. Engage on supported roads per normal openpilot usage

${BOLD}━━━ comma UI (on device) ━━━${NC}
  Settings → Developer
    • Vehicle-to-Infrastructure (V2I)     — ON
    • iPhone Navigation (CarPlay bridge)  — ON
    • AT&T / T-Mobile / Verizon           — pick one carrier
  Settings → Device → uninstall/reinstall uses custom URL when available:
    ${WEBSITE}

${BOLD}━━━ Phone — Android ━━━${NC}
  1. Install LaneSync Pilot app (Google Play / APK when published)
  2. Connect phone to comma Wi‑Fi hotspot
  3. App talks to ${WEBSITE} (cloud) and local dashcam API
  4. Android Auto navigation bridge via phonenavd (${PORT_PHONENAV_HTTP})

${BOLD}━━━ Phone — iPhone ━━━${NC}
  1. Join comma hotspot (${HOTSPOT_IP})
  2. Shortcuts automation → http://${HOTSPOT_IP}:${PORT_PHONENAV_HTTP}
  3. Guide: lanesync-pilot/tools/v2i/ios/README.md

${BOLD}━━━ Dashcam clips ━━━${NC}
  • Bookmark button on comma saves a segment
  • Local API:  http://${HOTSPOT_IP}:${PORT_DASHCAM_HTTP}/health
  • List clips: http://${HOTSPOT_IP}:${PORT_DASHCAM_HTTP}/clips
  • Cloud sync via ${WEBSITE} when backend is live

${BOLD}━━━ V2I testing (laptop on same Wi‑Fi) ━━━${NC}
  cd /data/openpilot
  python3 tools/v2i/v2i_sender.py --host ${HOTSPOT_IP} --demo
  python3 tools/v2i/phone_nav_sender.py --host ${HOTSPOT_IP}
  python3 tools/v2i/hud_mockup_server.py --comma-ip ${HOTSPOT_IP}

${BOLD}━━━ Maintenance ━━━${NC}
  Update:    bash <(curl -fsSL ${WEBSITE}/install.sh) --update
  Status:    bash <(curl -fsSL ${WEBSITE}/install.sh) --status
  Restore:   bash <(curl -fsSL ${WEBSITE}/install.sh) --restore-backup
  Uninstall: bash <(curl -fsSL ${WEBSITE}/install.sh) --uninstall
  Log:       ${LOG_FILE}
  Manifest:  ${MANIFEST_FILE}

${BOLD}━━━ Support ━━━${NC}
  Website:  ${WEBSITE}
  GitHub:   https://github.com/lanesyncpilot/lanesyncpilot
  Email:    ${SUPPORT_EMAIL}

${DIM}LaneSync Pilot is experimental. Not affiliated with comma.ai. Drive safely.${NC}

GUIDE
}

print_troubleshooting() {
  cat <<TROUBLE

${BOLD}━━━ Troubleshooting ━━━${NC}

${BOLD}Install failed during git clone${NC}
  • Connect comma to Wi‑Fi or ensure SIM has data
  • Retry: bash <(curl -fsSL ${WEBSITE}/install.sh)

${BOLD}openpilot does not start after reboot${NC}
  • Check: ls -la /data/openpilot /data/continue.sh
  • Restore: bash <(curl -fsSL ${WEBSITE}/install.sh) --restore-backup

${BOLD}Phone cannot reach dashcam API${NC}
  • Phone must be on comma hotspot (${HOTSPOT_IP})
  • curl http://${HOTSPOT_IP}:${PORT_DASHCAM_HTTP}/health

${BOLD}LTE / hotspot not working${NC}
  • bash <(curl -fsSL ${WEBSITE}/install.sh) -c tmobile --apply-carrier
  • Or run: /data/<carrier>/apply_dataplan.sh consumer
  • Reboot after inserting SIM

${BOLD}V2I not showing on HUD${NC}
  • params set V2IEnabled 1  (or use Developer toggle)
  • Send test: python3 tools/v2i/v2i_sender.py --host ${HOTSPOT_IP} --demo

TROUBLE
}

reboot_device() {
  if [[ "$DO_REBOOT" -eq 0 ]]; then
    warn "No reboot (--no-reboot). Run: reboot"
    return
  fi
  if [[ "$DO_DRY_RUN" -eq 1 ]]; then
    echo -e "${DIM}    (dry-run) reboot${NC}"
    return
  fi
  echo ""
  echo -e "${BOLD}Rebooting in 15 seconds…${NC}  ${DIM}Ctrl+C to cancel${NC}"
  for i in 15 10 5 4 3 2 1; do
    sleep 1
    echo -ne "\r  ${i}s   "
  done
  echo ""
  reboot
}

# -----------------------------------------------------------------------------
# Uninstall
# -----------------------------------------------------------------------------

do_uninstall() {
  preflight
  step "Uninstall"
  [[ -L "$OPENPILOT_DIR" ]] && run rm -f "$OPENPILOT_DIR" && ok "Removed symlink"
  [[ -d "$REPO_DIR" ]] && run rm -rf "$REPO_DIR" && ok "Removed repo"
  [[ -f "$MANIFEST_FILE" ]] && run rm -f "$MANIFEST_FILE"
  echo ""
  ok "Uninstalled. Backups: $(list_backups | wc -l | tr -d ' ') saved"
  print_troubleshooting
  exit 0
}

# -----------------------------------------------------------------------------
# Main flows
# -----------------------------------------------------------------------------

do_fresh_install() {
  run_interactive_wizard
  confirm_install
  stop_onroad
  backup_existing
  clone_repo
  link_openpilot
  init_submodules
  write_continue_sh
  enable_lanesync_features
  enable_carrier
  enable_ssh
  write_manifest
  verify_install
  print_post_install_guide
  print_troubleshooting
  reboot_device
}

do_update_install() {
  [[ -d "$REPO_DIR" ]] || die "Not installed. Run without --update."
  stop_onroad
  update_repo
  link_openpilot
  enable_lanesync_features
  enable_carrier
  enable_ssh
  write_manifest
  verify_install
  print_post_install_guide
  reboot_device
}

main() {
  parse_args "$@"

  if [[ "$DO_STATUS" -eq 1 ]]; then
    print_status
  fi

  if [[ "$DO_PRUNE_BACKUPS" -eq 1 ]]; then
    preflight
    prune_old_backups
    exit 0
  fi

  if [[ "$DO_RESTORE" -eq 1 ]]; then
    preflight
    restore_latest_backup
    exit 0
  fi

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
