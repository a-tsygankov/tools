#!/usr/bin/env bash
set -euo pipefail

# ============================================================
#  macOS Development Environment Bootstrapper
#  Categories:
#    BASE       → Core macOS developer tools
#    JAVA       → JDK 21 + IntelliJ IDEA (Gradle build)
#    DOTNET     → .NET 10 RC2+ SDK
#    EXTENSIONS → Chrome/Safari extension dev (TS + React + Vite + .NET backend)
# ============================================================

# ---------- CLI Arguments ----------
DO_BASE=false
DO_JAVA=false
DO_DOTNET=false
DO_EXT=false

VS_CODE_EXTS=""
WINDSURF_EXTS=""
IDEA_PLUGINS=""
IDEA_CONFIG=""

print_help() {
  cat <<'EOF'
Usage:
  setup-env.sh [--java] [--dotnet] [--extensions] [--all]
               [--vscode-ext "id1 id2"] [--windsurf-ext "id1 id2"]
               [--idea-plugins "id1,id2"] [--idea-config /path/to.zip]
  setup-env.sh -h | --help

Behavior:
  - With no flags → installs BASE only.
  - With flags    → always runs BASE first, then chosen sections.
EOF
}

if [[ $# -eq 0 ]]; then
  DO_BASE=true
else
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --java) DO_JAVA=true; shift ;;
      --dotnet) DO_DOTNET=true; shift ;;
      --extensions) DO_EXT=true; shift ;;
      --all) DO_JAVA=true; DO_DOTNET=true; DO_EXT=true; shift ;;
      --vscode-ext) VS_CODE_EXTS="${2:-}"; shift 2 ;;
      --windsurf-ext) WINDSURF_EXTS="${2:-}"; shift 2 ;;
      --idea-plugins) IDEA_PLUGINS="${2:-}"; shift 2 ;;
      --idea-config) IDEA_CONFIG="${2:-}"; shift 2 ;;
      -h|--help) print_help; exit 0 ;;
      *) echo "Unknown argument: $1"; print_help; exit 1 ;;
    esac
  done
  DO_BASE=true
fi

# ---------- Helpers ----------
info()  { printf "\033[1;34m[INFO]\033[0m %s\n" "$*"; }
warn()  { printf "\033[1;33m[WARN]\033[0m %s\n" "$*"; }

have_cmd() { command -v "$1" >/dev/null 2>&1; }

brew_install() {
  local pkg="$1"
  if brew list --formula --versions "$pkg" >/dev/null 2>&1; then
    info "Already installed: $pkg"
  else
    info "Installing $pkg..."
    brew install "$pkg"
  fi
}

brew_cask_install() {
  local cask="$1"
  if brew list --cask --versions "$cask" >/dev/null 2>&1; then
    info "Already installed: $cask"
  else
    info "Installing $cask..."
    brew install --cask "$cask" || warn "Skipping $cask (possibly already installed)"
  fi
}

npm_global_install() {
  local pkg="$1"
  if npm ls -g --depth=0 "$pkg" >/dev/null 2>&1; then
    info "npm global already: $pkg"
  else
    info "Installing npm global: $pkg"
    npm install -g "$pkg"
  fi
}

ensure_code_cli() {
  if have_cmd code; then return 0; fi
  info "Installing VS Code..."
  brew_cask_install visual-studio-code
  if [[ -x "/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code" ]]; then
    ln -sf "/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code" /opt/homebrew/bin/code || true
  fi
}

ensure_windsurf_cli() {
  if have_cmd windsurf; then return 0; fi
  local ws="$HOME/.codeium/windsurf/bin/windsurf"
  if [[ -x "$ws" ]]; then
    export PATH="$HOME/.codeium/windsurf/bin:$PATH"
  else
    warn "Windsurf CLI not found — ensure it’s installed via cask or manually."
  fi
}

install_vscode_extensions() {
  local list="$1"
  ensure_code_cli
  if ! have_cmd code; then warn "VS Code CLI unavailable"; return; fi
  for ext in $list; do
    if code --list-extensions | grep -Fxq "$ext"; then
      info "VS Code ext present: $ext"
    else
      info "Installing VS Code ext: $ext"
      code --install-extension "$ext" --force
    fi
  done
}

install_windsurf_extensions() {
  local list="$1"
  ensure_windsurf_cli
  if ! have_cmd windsurf; then warn "Windsurf CLI unavailable"; return; fi
  for ext in $list; do
    if windsurf --list-extensions | grep -Fxq "$ext"; then
      info "Windsurf ext present: $ext"
    else
      info "Installing Windsurf ext: $ext"
      windsurf --install-extension "$ext" || warn "Failed: $ext"
    fi
  done
}

append_once() {
  local file="$1" mark="$2" payload="$3"
  mkdir -p "$(dirname "$file")"
  touch "$file"
  if ! grep -Fq "$mark" "$file"; then
    echo -e "\n# >>> $mark >>>\n$payload\n# <<< $mark <<<" >>"$file"
  fi
}

# ============================================================
#  BASE SETUP
# ============================================================
run_base() {
  info "Running BASE setup..."

  if ! have_cmd brew; then
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  fi
  export PATH="/opt/homebrew/bin:$PATH"
  brew update

  brew_install bash
  brew_install bash-completion@2
  brew_install git
  brew_install openssh
  brew_cask_install google-chrome || true
  brew_cask_install github || true
  # --- Install Windsurf only if missing ---
  if have_cmd windsurf; then
    info "Windsurf CLI detected."
  elif [[ -d "/Applications/Windsurf.app" ]]; then
    info "Windsurf already installed in /Applications."
  elif brew list --cask --versions windsurf >/dev/null 2>&1; then
    info "Windsurf already installed via Homebrew."
  else
    info "Installing Windsurf via Homebrew..."
    brew_cask_install windsurf || warn "Could not install Windsurf automatically."
  fi

  # Default bash shell
  local brew_bash="/opt/homebrew/bin/bash"
  if [[ -x "$brew_bash" ]]; then
    if ! grep -Fxq "$brew_bash" /etc/shells; then
      echo "$brew_bash" | sudo tee -a /etc/shells >/dev/null
    fi

    if [[ "$SHELL" != "$brew_bash" ]]; then
      if [ -t 0 ]; then
        info "Changing login shell to $brew_bash (you may need to re-log)..."
        chsh -s "$brew_bash" || warn "Could not change shell automatically."
      else
        warn "Skipping chsh (non-interactive mode). Run manually if needed: chsh -s $brew_bash"
      fi
    else
      info "Default shell already set to brew bash."
    fi
  fi

  # Git prompt & history bindings
  local BASHRC_SNIPPET
  read -r -d '' BASHRC_SNIPPET <<'EOS'
# --- Enhanced Git Prompt ---
get_git_info() {
  if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    local branch=$(git symbolic-ref --short HEAD 2>/dev/null || git rev-parse --short HEAD 2>/dev/null)
    local dirty=""
    [[ -n $(git status --porcelain 2>/dev/null) ]] && dirty="*"
    echo "[$branch$dirty]"
  fi
}
DARKGRAY='\[\e[1;30m\]'
BLUE='\[\e[1;34m\]'
YELLOW='\[\e[1;33m\]'
RESET='\[\e[0m\]'
PS1="${DARKGRAY}\u@\h ${BLUE}\w ${YELLOW}\$(get_git_info)${RESET} \$ "
bind '"\e[A": history-search-backward'
bind '"\e[B": history-search-forward'
EOS
  append_once "$HOME/.bashrc" "ENV:BASE-BASH_RC" "$BASHRC_SNIPPET"

  info "BASE setup complete."
}

# ============================================================
#  EXTENSIONS (Chrome + Safari + Vite + React + TypeScript)
# ============================================================
run_extensions() {
  info "------ Starting EXTENSIONS phase ------"
  info "Setting up browser-extension dev stack..."

  brew_install node
  npm_global_install "typescript@^5.4"
  npm_global_install "vite@^5"
  npm_global_install eslint
  npm_global_install prettier
  npm_global_install web-ext
  brew_cask_install postman || true

  ensure_code_cli
  ensure_windsurf_cli

  # Safari converter requires Xcode 15+
  if ! xcodebuild -version >/dev/null 2>&1; then
    warn "Xcode 15+ not detected — install to enable Safari extension packaging."
  fi

  local EXT_BASE="
esbenp.prettier-vscode
dbaeumer.vscode-eslint
antfu.vite
kamikillerto.vscode-colorize
formulahendry.auto-rename-tag
ritwickdey.LiveServer
ms-dotnettools.csharp
humao.rest-client
aaravb.chrome-extension-developer-tools
ms-vscode.vscode-browser-debug
peterjausovec.vscode-docker
"
  install_vscode_extensions "$EXT_BASE"
  install_windsurf_extensions "$EXT_BASE"

  info "Extension dev setup complete (TS + React + Vite + .NET)."
}

# ============================================================
#  Orchestration
# ============================================================
main() {
  info "Selected categories:"
  if [ "$DO_BASE" = true ]; then echo "  BASE"; fi
  if [ "$DO_JAVA" = true ]; then echo "  JAVA"; fi
  if [ "$DO_DOTNET" = true ]; then echo "  DOTNET"; fi
  if [ "$DO_EXT" = true ]; then echo "  EXTENSIONS"; fi

  if [ "$DO_BASE" = true ]; then
    run_base || warn "BASE setup reported warnings but continuing..."
  fi

  if [ "$DO_JAVA" = true ]; then
    info "------ Starting JAVA phase ------"
    run_java || warn "JAVA setup reported warnings but continuing..."
  fi

  if [ "$DO_DOTNET" = true ]; then
    info "------ Starting DOTNET phase ------"
    run_dotnet || warn "DOTNET setup reported warnings but continuing..."
  fi

  if [ "$DO_EXT" = true ]; then
    info "------ Starting EXTENSIONS phase ------"
    run_extensions || warn "EXTENSIONS setup reported warnings but continuing..."
  fi

  info "✅ Environment setup complete. Restart your terminal or run: exec \$SHELL -l"
}
main "$@"
