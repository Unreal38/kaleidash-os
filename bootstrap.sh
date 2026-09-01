#!/usr/bin/env bash
set -Eeuo pipefail

export LC_ALL=C

readonly REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly MANIFEST_DIR="$REPO_ROOT/manifests"
readonly PROFILE_DIR="$MANIFEST_DIR/profiles"
readonly VENDOR_OS_RELEASE="${KALEIDASH_VENDOR_OS_RELEASE:-/usr/lib/os-release}"
readonly FLATHUB_REPO_FILE="https://flathub.org/repo/flathub.flatpakrepo"

ACTION="plan"
ASSUME_YES=0
INSTALL_IDENTITY=1
ALL_PROFILES=0
declare -a PROFILES=()
declare -a LAYERS=()
declare -a DNF_PACKAGES=()
declare -a REPOSITORIES=()
declare -a FLATPAK_REMOTES=()
declare -a FLATPAKS=()
declare -a SYSTEM_SERVICES=()
declare -a USER_SERVICES=()
declare -a EXTERNAL_APPS=()

log() {
  printf '\033[1;35mKaleidashOS\033[0m %s\n' "$*"
}

warn() {
  printf '\033[1;33mKaleidashOS warning:\033[0m %s\n' "$*" >&2
}

die() {
  printf '\033[1;31mKaleidashOS error:\033[0m %s\n' "$*" >&2
  exit 1
}

usage() {
  cat <<'EOF'
Usage: ./bootstrap.sh [plan|install|profiles] [options]

Commands:
  plan                 Print the resolved installation plan without changing the system.
  install              Install the resolved packages and identity layer.
  profiles             List available optional profiles.

Options:
  --profile NAME       Include an optional profile. May be repeated.
  --all-profiles       Include every optional profile.
  --no-identity        Do not run the KaleidashOS identity installer.
  --yes                Pass non-interactive confirmation flags to package managers.
  -h, --help           Show this help.

Running without a command is equivalent to `plan`.
EOF
}

list_profiles() {
  local directory
  for directory in "$PROFILE_DIR"/*; do
    [[ -d "$directory" ]] || continue
    basename "$directory"
  done | sort
}

parse_arguments() {
  if [[ $# -gt 0 && "$1" != --* && "$1" != "-h" ]]; then
    ACTION="$1"
    shift
  fi

  case "$ACTION" in
    plan|install|profiles) ;;
    help)
      usage
      exit 0
      ;;
    *) die "unknown command: $ACTION" ;;
  esac

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --profile)
        [[ $# -ge 2 ]] || die "--profile requires a profile name"
        PROFILES+=("$2")
        shift 2
        ;;
      --all-profiles)
        ALL_PROFILES=1
        shift
        ;;
      --no-identity)
        INSTALL_IDENTITY=0
        shift
        ;;
      --yes)
        ASSUME_YES=1
        shift
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *) die "unknown option: $1" ;;
    esac
  done
}

require_fedora() {
  [[ -r "$VENDOR_OS_RELEASE" ]] || die "cannot read Fedora vendor metadata: $VENDOR_OS_RELEASE"

  # shellcheck disable=SC1090
  source "$VENDOR_OS_RELEASE"
  if [[ "${ID:-}" != "fedora" && " ${ID_LIKE:-} " != *" fedora "* ]]; then
    die "the bootstrap installer currently supports Fedora-derived systems only"
  fi

  FEDORA_VERSION_ID="${VERSION_ID:-unknown}"
  FEDORA_PRETTY_NAME="${PRETTY_NAME:-Fedora $FEDORA_VERSION_ID}"
  readonly FEDORA_VERSION_ID FEDORA_PRETTY_NAME
}

resolve_profiles() {
  local profile

  if [[ $ALL_PROFILES -eq 1 ]]; then
    mapfile -t PROFILES < <(list_profiles)
  fi

  if [[ ${#PROFILES[@]} -gt 0 ]]; then
    mapfile -t PROFILES < <(printf '%s\n' "${PROFILES[@]}" | sort -u)
  fi

  for profile in "${PROFILES[@]}"; do
    [[ "$profile" =~ ^[a-z0-9][a-z0-9-]*$ ]] || die "invalid profile name: $profile"
    [[ -d "$PROFILE_DIR/$profile" ]] || die "unknown profile: $profile"
  done
}

collect_file() {
  local filename="$1"
  local layer file

  for layer in "${LAYERS[@]}"; do
    file="$layer/$filename"
    [[ -f "$file" ]] || continue
    grep -Ev '^[[:space:]]*(#|$)' "$file" || true
  done
}

collect_manifests() {
  local profile

  LAYERS=(
    "$MANIFEST_DIR/base"
    "$MANIFEST_DIR/default-applications"
  )
  for profile in "${PROFILES[@]}"; do
    LAYERS+=("$PROFILE_DIR/$profile")
  done

  mapfile -t DNF_PACKAGES < <(
    { collect_file dnf.txt; collect_file dnf-additions.txt; } | sort -u
  )
  mapfile -t REPOSITORIES < <(collect_file repositories.txt | sort -u)
  mapfile -t FLATPAK_REMOTES < <(collect_file flatpak-remotes.tsv | sort -u)
  mapfile -t FLATPAKS < <(
    { collect_file flatpak.tsv; collect_file flatpak-additions.tsv; } | sort -u
  )
  mapfile -t SYSTEM_SERVICES < <(collect_file system-services.txt | sort -u)
  mapfile -t USER_SERVICES < <(collect_file user-services.txt | sort -u)
  mapfile -t EXTERNAL_APPS < <(collect_file external.txt | sort -u)
}

copr_project_from_id() {
  local repository="$1"
  local project

  project="${repository#copr:copr.fedorainfracloud.org:}"
  [[ "$project" != "$repository" && "$project" == *:* ]] \
    || die "cannot translate COPR repository ID: $repository"
  printf '%s/%s\n' "${project%%:*}" "${project#*:}"
}

validate_repository_recipes() {
  local repository
  for repository in "${REPOSITORIES[@]}"; do
    case "$repository" in
      copr:copr.fedorainfracloud.org:*) copr_project_from_id "$repository" >/dev/null ;;
      fedora-cisco-openh264|rpmfusion-free|rpmfusion-free-updates|rpmfusion-nonfree|rpmfusion-nonfree-updates|tailscale-stable|terra) ;;
      *) die "no bootstrap recipe exists for repository: $repository" ;;
    esac
  done
}

print_entries() {
  local heading="$1"
  shift
  local -a entries=("$@")
  local entry

  printf '\n%s (%d)\n' "$heading" "${#entries[@]}"
  for entry in "${entries[@]}"; do
    printf '  - %s\n' "$entry"
  done
}

print_plan() {
  local profile_text="none"
  local identity_text="install"

  if [[ ${#PROFILES[@]} -gt 0 ]]; then
    profile_text="$(IFS=,; printf '%s' "${PROFILES[*]}")"
  fi
  [[ $INSTALL_IDENTITY -eq 1 ]] || identity_text="skip"

  printf 'KaleidashOS bootstrap plan\n'
  printf 'Fedora substrate: %s\n' "$FEDORA_PRETTY_NAME"
  printf 'Optional profiles: %s\n' "$profile_text"
  printf 'Identity layer: %s\n' "$identity_text"
  print_entries "Repositories" "${REPOSITORIES[@]}"
  print_entries "DNF packages" "${DNF_PACKAGES[@]}"
  print_entries "Flatpak remotes" "${FLATPAK_REMOTES[@]}"
  print_entries "Flatpak applications" "${FLATPAKS[@]}"
  print_entries "System services" "${SYSTEM_SERVICES[@]}"
  print_entries "User services" "${USER_SERVICES[@]}"
  print_entries "External applications awaiting verified recipes" "${EXTERNAL_APPS[@]}"

  printf '\nNo versions are pinned and no Fedora update configuration is changed.\n'
  printf 'Run ./bootstrap.sh install to apply this plan.\n'
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || die "required command is missing: $1"
}

run_dnf() {
  local -a arguments=("$@")
  local -a confirmation=()
  [[ $ASSUME_YES -eq 0 ]] || confirmation=(-y)
  sudo dnf "${confirmation[@]}" "${arguments[@]}"
}

enable_repositories() {
  local repository project
  local need_rpmfusion_free=0
  local need_rpmfusion_nonfree=0

  log "Installing Fedora repository-management support"
  run_dnf install dnf5-plugins flatpak

  for repository in "${REPOSITORIES[@]}"; do
    case "$repository" in
      copr:copr.fedorainfracloud.org:*)
        project="$(copr_project_from_id "$repository")"
        log "Enabling COPR $project"
        run_dnf copr enable "$project"
        ;;
      fedora-cisco-openh264)
        log "Enabling Fedora Cisco OpenH264"
        sudo dnf config-manager enable fedora-cisco-openh264
        ;;
      rpmfusion-free|rpmfusion-free-updates)
        need_rpmfusion_free=1
        ;;
      rpmfusion-nonfree|rpmfusion-nonfree-updates)
        need_rpmfusion_nonfree=1
        ;;
      tailscale-stable)
        if sudo test -f /etc/yum.repos.d/tailscale.repo; then
          log "Tailscale stable repository is already configured"
        else
          log "Adding the Tailscale stable repository"
          sudo dnf config-manager addrepo \
            --from-repofile="https://pkgs.tailscale.com/stable/fedora/tailscale.repo"
        fi
        ;;
      terra)
        log "Enabling Terra"
        run_dnf install --nogpgcheck \
          --repofrompath 'terra,https://repos.fyralabs.com/terra$releasever' terra-release
        ;;
    esac
  done

  if [[ $need_rpmfusion_free -eq 1 ]]; then
    log "Enabling RPM Fusion Free"
    run_dnf install \
      "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$FEDORA_VERSION_ID.noarch.rpm"
  fi
  if [[ $need_rpmfusion_nonfree -eq 1 ]]; then
    log "Enabling RPM Fusion Nonfree"
    run_dnf install \
      "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$FEDORA_VERSION_ID.noarch.rpm"
  fi
}

install_dnf_packages() {
  [[ ${#DNF_PACKAGES[@]} -gt 0 ]] || return
  log "Installing ${#DNF_PACKAGES[@]} DNF packages"
  run_dnf install "${DNF_PACKAGES[@]}"
}

enable_flatpak_remotes() {
  local row scope remote url extra

  require_command flatpak

  for row in "${FLATPAK_REMOTES[@]}"; do
    IFS=$'\t' read -r scope remote url extra <<< "$row"
    [[ -z "${extra:-}" && -n "$url" ]] || die "invalid Flatpak remote row: $row"
    [[ "$remote" == "flathub" ]] || die "no bootstrap recipe exists for Flatpak remote: $remote"

    log "Adding $scope Flatpak remote $remote"
    if [[ "$scope" == "system" ]]; then
      sudo flatpak remote-add --system --if-not-exists "$remote" "$FLATHUB_REPO_FILE"
    elif [[ "$scope" == "user" ]]; then
      flatpak remote-add --user --if-not-exists "$remote" "$FLATHUB_REPO_FILE"
    else
      die "invalid Flatpak scope: $scope"
    fi
  done
}

install_flatpaks() {
  local row scope application origin branch extra
  local -a confirmation=()
  [[ $ASSUME_YES -eq 0 ]] || confirmation=(-y)

  for row in "${FLATPAKS[@]}"; do
    IFS=$'\t' read -r scope application origin branch extra <<< "$row"
    [[ -z "${extra:-}" && -n "$branch" ]] || die "invalid Flatpak application row: $row"
    log "Installing Flatpak $application ($scope)"
    if [[ "$scope" == "system" ]]; then
      sudo flatpak install --system "${confirmation[@]}" "$origin" "$application//$branch"
    elif [[ "$scope" == "user" ]]; then
      flatpak install --user "${confirmation[@]}" "$origin" "$application//$branch"
    else
      die "invalid Flatpak scope: $scope"
    fi
  done
}

install_identity() {
  [[ $INSTALL_IDENTITY -eq 1 ]] || return
  log "Installing the KaleidashOS identity layer"
  "$REPO_ROOT/identity/install.sh"
}

enable_services() {
  local service

  for service in "${SYSTEM_SERVICES[@]}"; do
    if [[ "$service" == "greetd.service" ]]; then
      warn "Deferring greetd activation until the Noctalia Greeter deployment recipe is available."
      continue
    fi
    if ! systemctl list-unit-files "$service" --no-legend 2>/dev/null | grep -Fq "$service"; then
      warn "Deferring unavailable system service: $service"
      continue
    fi
    log "Enabling system service $service"
    sudo systemctl enable "$service"
  done

  for service in "${USER_SERVICES[@]}"; do
    if ! systemctl --user list-unit-files "$service" --no-legend 2>/dev/null | grep -Fq "$service"; then
      warn "Deferring unavailable user service: $service"
      continue
    fi
    log "Enabling user service $service"
    systemctl --user enable "$service"
  done
}

print_pending_external_apps() {
  local application
  [[ ${#EXTERNAL_APPS[@]} -gt 0 ]] || return

  printf '\nExternal applications still need verified upstream recipes:\n'
  for application in "${EXTERNAL_APPS[@]}"; do
    printf '  - %s\n' "$application"
  done
}

install_system() {
  [[ $EUID -ne 0 ]] || die "run the installer as your normal desktop user, not root"
  for command_name in dnf grep sort sudo systemctl; do
    require_command "$command_name"
  done

  sudo -v
  enable_repositories
  install_dnf_packages
  enable_flatpak_remotes
  install_flatpaks
  install_identity
  enable_services
  print_pending_external_apps

  printf '\nKaleidashOS bootstrap completed. Reboot after the configuration milestone is deployed.\n'
}

main() {
  parse_arguments "$@"

  if [[ "$ACTION" == "profiles" ]]; then
    list_profiles
    exit 0
  fi

  require_fedora
  resolve_profiles
  "$MANIFEST_DIR/validate.sh"
  collect_manifests
  validate_repository_recipes

  if [[ "$ACTION" == "plan" ]]; then
    print_plan
  else
    install_system
  fi
}

main "$@"
