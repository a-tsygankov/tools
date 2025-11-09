#!/usr/bin/env bash
set -euo pipefail

# ============================================================
#  macOS Dev Environment Bootstrapper
#  Categories: BASE (implemented), JAVA (placeholder), DOTNET (placeholder), EXTENSIONS (placeholder)
#  Usage: see --help
# ============================================================

# ---------- Configurable defaults / placeholders ----------
# You can pass these via CLI too (see help).
VSCODE_EXTENSIONS_DEFAULT=""
WINDSURF_EXTENSIONS_DEFAULT=""
IDEA_PLUGINS_DEFAULT=""
IDEA_CONFIG_ARCHIVE=""  # e.g., path or URL to pre-baked settings .zip (placeholder)

# ---------- CLI parsing ----------
DO_BASE=false
DO_JAVA=false
DO_DOTNET=false
DO_EXT=false

VS_CODE_EXTS="${VSCODE_EXTENSIONS_DEFAULT}"
WINDSURF_EXTS="${WINDSURF_EXTENSIONS_DEFAULT}"
IDEA_PLUGINS="${IDEA_PLUGINS_DEFAULT}"
IDEA_CONFIG="${IDEA_CONFIG_ARCHIVE}"

print_help() {
  cat <<'EOF'
macOS Environment Setup

Usage:
  setup-env.sh [--java] [--dotnet] [--extensions] [--all]
               [--vscode-ext "ext1 ext2"] [--windsurf-ext "extA extB"]
               [--idea-plugins "id1,id2"] [--idea-config /path/to.zip]
  setup-env.sh -h | --help

Behavior:
  - No category flags: runs BASE only.
  - With any category flag: runs BASE first, then the requested categories.

Categories:
  BASE        Installs and configures core tooling:
              - Homebrew (and /opt/homebrew in PATH)
              - Bash (brew), set as default shell, bash-completion
              - Append and dedupe .bash_profile / .bashrc snippets
              - History, aliases, readline bindings (Ctrl-R, history-search)
              - OpenSSH (ssh), Git, GitHub Desktop, Google Chrome, Windsurf

  JAVA        (placeholder) JDK, IntelliJ IDEA, JAVA_HOME, corporate key injection
  DOTNET      (placeholder) .NET 10 RC2 SDK installation
  EXTENSIONS  (placeholder) Install editor/IDE extensions (VS Code, Windsurf, IntelliJ)
              Arguments:
                --vscode-ext "foo.bar baz.qux"
                --windsurf-ext "publisher.extension ..."
                --idea-plugins "id1,id2"
                --idea-config /path/to/settings.zip

Examples:
  ./setup-env.sh
  ./setup-env.sh --java --vscode-ext "ms-dotnettools.csharp"
  ./setup-env.sh --all --windsurf-ext "codeium.windsurf-ai"
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
  # If any category specified, run BASE first.
  DO_BASE=true
fi

# ---------- Logging helpers ----------
info()  { printf "\033[1;34m[INFO]\033[0m %s\n" "$*"; }
warn()  { printf "\033[1;33m[WARN]\033[0m %s\n" "$*"; }
error() { printf "\033[1;31m[ERR ]\033[0m %s\n" "$*" >&2; }

# ---------- Utility helpers ----------
append_once() {
  # $1=file $2=marker-id $3=content-to-append
  local file="$1" mark="$2" payload="$3"
  mkdir -p "$(dirname "$file")"
  touch "$file"
  if ! grep -Fq "$mark" "$file"; then
    {
      echo ""
      echo "# >>> $mark >>>"
      echo "$payload"
      echo "# <<< $mark <<<"
    } >> "$file"
    info "Updated $(basename "$file") with block: $mark"
  else
    info "$(basename "$file") already contains block: $mark"
  fi
}

ensure_line_in_file() {
  # idempotently ensure a single line exists in file
  local file="$1" line="$2"
  mkdir -p "$(dirname "$file")"
  touch "$file"
  if ! grep -Fxq "$line" "$file"; then
    echo "$line" >> "$file"
    info "Added line to $(basename "$file"): $line"
  fi
}

have_cmd() { command -v "$1" >/dev/null 2>&1; }

brew_install() {
  local formula="$1"
  if brew list --formula --versions "$formula" >/dev/null 2>&1; then
    info "brew formula already installed: $formula"
  else
    info "Installing formula: $formula"
    brew install "$formula"
  fi
}

brew_cask_install() {
  local cask="$1"
  if brew list --cask --versions "$cask" >/dev/null 2>&1; then
    info "brew cask already installed: $cask"
  else
    info "Installing cask: $cask"
    brew install --cask "$cask" || warn "Failed installing cask $cask (continuing)"
  fi
}

# ---------- BASE implementation ----------
run_base() {
  info "Starting BASE setup…"

  # 1) Homebrew
  if ! have_cmd brew; then
    info "Installing Homebrew…"
    NONINTERACTIVE=1 /bin/bash -c \
      "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  else
    info "Homebrew already installed."
  fi

  # Ensure brew in PATH for this script run
  if [[ -d /opt/homebrew/bin ]]; then
    export PATH="/opt/homebrew/bin:$PATH"
  fi

  # Update/doctor
  info "Updating Homebrew…"
  brew update || true

  # 2) Install core formulae and casks
  brew_install bash                   # modern bash
  brew_install bash-completion@2
  brew_install git
  brew_install openssh

  brew_cask_install google-chrome
  brew_cask_install github            # GitHub Desktop
  brew_cask_install windsorfake || true
  # Prefer correct cask name:
  if ! brew list --cask --versions windsorfake >/dev/null 2>&1; then
    # Try known token "windsurf"
    brew_cask_install windsurf || true
  fi
  # If both failed, notify:
  if ! brew list --cask --versions windsurf >/dev/null 2>&1 && \
     ! brew list --cask --versions windsorfake >/dev/null 2>&1; then
    warn "Windsurf cask may be unavailable in your tap. You can install manually later."
  fi

  # 3) Make brew bash the default shell
  local BREW_BASH="/opt/homebrew/bin/bash"
  if [[ -x "$BREW_BASH" ]]; then
    if ! grep -Fxq "$BREW_BASH" /etc/shells; then
      info "Adding $BREW_BASH to /etc/shells (requires sudo)…"
      echo "$BREW_BASH" | sudo tee -a /etc/shells >/dev/null
    fi
    if [[ "$SHELL" != "$BREW_BASH" ]]; then
      info "Changing login shell to $BREW_BASH (you may need to re-log)…"
      chsh -s "$BREW_BASH" || warn "Could not change shell automatically."
    else
      info "Default shell already set to brew bash."
    fi
  else
    warn "Brew bash not found at $BREW_BASH"
  fi

  # 4) SSH: ensure key exists
  if [[ ! -f "$HOME/.ssh/id_ed25519" ]]; then
    info "Generating SSH key (ed25519)…"
    mkdir -p "$HOME/.ssh"
    chmod 700 "$HOME/.ssh"
    ssh-keygen -t ed25519 -f "$HOME/.ssh/id_ed25519" -N "" -C "${USER}@$(hostname)"
    info "SSH public key:"
    cat "$HOME/.ssh/id_ed25519.pub" || true
  else
    info "SSH key already exists."
  fi

  # 5) Git basic config (safe defaults; idempotent)
  git config --global init.defaultBranch main || true
  git config --global pull.rebase false || true
  git config --global fetch.prune true || true
  git config --global core.autocrlf input || true
  git config --global push.default simple || true

  # 6) Append to ~/.bash_profile (idempotent, with your provided snippet)
  local BASH_PROFILE_SNIPPET
  read -r -d '' BASH_PROFILE_SNIPPET <<'EOS'
# Source .bashrc for consistency
if [ -f ~/.bashrc ]; then
  source ~/.bashrc
fi
HISTSIZE=30000
HISTFILESIZE=30000

HISTCONTROL=ignoredups:erasedups
HISTIGNORE="ls:cd:cd -:pwd:exit:clear"
shopt -s histappend  # append to history instead of overwriting

# Added by Windsurf
export PATH="~/.codeium/windsurf/bin:$PATH"
EOS

  append_once "$HOME/.bash_profile" "ENV:BASE-BASH_PROFILE" "$BASH_PROFILE_SNIPPET"

  # 7) Append to ~/.bashrc (idempotent, with your provided snippet + extras)
  local BASH_RC_SNIPPET
  read -r -d '' BASH_RC_SNIPPET <<'EOS'
# If you have a ~/bin, prepend it
if [ -d ~/bin ]; then
  export PATH="~/bin:$PATH"
fi

# Homebrew path (Apple Silicon)
if [ -d /opt/homebrew/bin ]; then
  export PATH="/opt/homebrew/bin:$PATH"
fi

# Git branch in prompt
parse_git_branch() {
  git branch 2>/dev/null | sed -n '/\* /s///p'
}

# Prompt colors
DARKGRAY='\[\e[1;30m\]'
BLUE='\[\e[1;34m\]'
YELLOW='\[\e[1;33m\]'
RESET='\[\e[0m\]'

# PS1 prompt
PS1="${DARKGRAY}\u@\h ${BLUE}\w ${YELLOW}·\$(parse_git_branch)${RESET} \$ "

# Better LS with colors
alias ls='ls -G'
alias ll='ls -lah'
alias la='ls -A'
alias ..='cd ..'
#export PATH="$HOME/Library/Python/<PYTHON_VERSION>/bin:${PATH}"

# Git shortcuts
alias gs='git status'
alias gc='git commit'
#alias gp='git push'
#alias gl='git pull'
#alias gd='git diff'

# Bash completion if installed
if [ -f /opt/homebrew/etc/profile.d/bash_completion.sh ]; then
  source /opt/homebrew/etc/profile.d/bash_completion.sh
fi

# Readline quality-of-life:
# - Ctrl-R already enables incremental history search; these improve arrows to do prefix search.
bind '"\e[A": history-search-backward'
bind '"\e[B": history-search-forward'
bind 'set show-all-if-ambiguous on'
bind 'TAB: menu-complete'
EOS

  append_once "$HOME/.bashrc" "ENV:BASE-BASH_RC" "$BASH_RC_SNIPPET"

  # 8) Ensure /opt/homebrew/bin appears early for current session
  if [[ -d /opt/homebrew/bin ]]; then
    case ":$PATH:" in
      *":/opt/homebrew/bin:"*) : ;; # already present
      *) export PATH="/opt/homebrew/bin:$PATH" ;;
    esac
  fi

  info "BASE setup complete."
}

# ---------- JAVA placeholder ----------
run_java() {
  info "JAVA section (placeholder). Planned actions:"
  cat <<'EOF'
  - Install Temurin/OpenJDK via Homebrew (e.g., brew install --cask temurin)
  - Install IntelliJ IDEA via Homebrew (brew install --cask intellij-idea)
  - Set JAVA_HOME in bash profile (via /usr/libexec/java_home or fixed path)
  - Apply corporate license key (secure retrieval/placement)
  - (Optional) Import IDEA settings (see --idea-config)
EOF
}

# ---------- DOTNET placeholder ----------
run_dotnet() {
  info "DOTNET section (placeholder). Planned actions:"
  cat <<'EOF'
  - Install .NET 10 RC2 SDK
    * If available via Homebrew casks/formulae, prefer that.
    * Otherwise, download official installer pkg and run silently.
  - Verify 'dotnet --info'
  - (Optional) Add global.json for SDK pinning in your workspace(s)
EOF
}

# ---------- EXTENSIONS implementation ----------
run_extensions() {
  info "EXTENSIONS setup for Chrome+Safari TS/React/Vite + .NET companion…"

  # 0) Homebrew update (safe to re-run)
  info "Ensuring Homebrew is up to date…"
  brew update || true

  # 1) Core runtimes & tools
  # Node ≥20 (brew node is current LTS), optional pnpm, HTTP clients, Docker Desktop (optional)
  brew_install node
  # If you prefer pnpm over npm, uncomment:
  # brew_install pnpm
  brew_install httpie
  # Postman (optional GUI)
  brew_cask_install postman || true
  # Docker Desktop (optional)
  # brew_cask_install docker || true

  # 2) Global npm CLIs for extension dev
  # TypeScript, Vite, linters/formatters, and web-ext for running/testing
  npm_global_install "typescript@^5.4"
  npm_global_install "ts-node"
  npm_global_install "vite@^5"
  npm_global_install "eslint"
  npm_global_install "prettier"
  npm_global_install "web-ext"

  # 3) Editors/IDEs (CLI availability)
  # VS Code (provides 'code' CLI)
  ensure_code_cli
  # Windsurf already installed in BASE; make sure CLI is reachable
  ensure_windsurf_cli

  # JetBrains Toolbox (optional; easiest way to manage IDEA/WebStorm/Rider)
  brew_cask_install jetbrains-toolbox || true
  # You can open Toolbox once to install IntelliJ/WebStorm/Rider as needed.

  # 4) Xcode (Safari converter)
  if xcodebuild -version >/dev/null 2>&1; then
    info "Xcode detected: $(xcodebuild -version | head -n 1)"
    if xcrun --find safari-web-extension-converter >/dev/null 2>&1; then
      info "Safari Web Extension Converter available."
    else
      warn "Safari converter not found via xcrun; ensure Xcode Command Line Tools are installed."
      xcode-select --install || true
    fi
  else
    warn "Xcode not detected. Install Xcode 15+ from App Store to enable Safari packaging."
  fi

  # 5) Editor/IDE extensions
  # Defaults per your instruction sheet (VS Code / Windsurf)
  local DEFAULT_VSCODE_EXTS="\
esbenp.prettier-vscode \
dbaeumer.vscode-eslint \
antfu.vite \
kamikillerto.vscode-colorize \
formulahendry.auto-rename-tag \
ritwickdey.LiveServer \
ms-dotnettools.csharp \
humao.rest-client"

  local DEFAULT_WINDSURF_EXTS="\
esbenp.prettier-vscode \
dbaeumer.vscode-eslint \
antfu.vite \
kamikillerto.vscode-colorize \
formulahendry.auto-rename-tag \
ritwickdey.LiveServer \
ms-dotnettools.csharp \
humao.rest-client"

  # Merge CLI-provided lists with defaults (avoid duplicates)
  # VS Code
  if [[ -n "${VS_CODE_EXTS// /}" ]]; then
    info "Installing requested VS Code extensions…"
    install_vscode_extensions "$VS_CODE_EXTS"
  fi
  info "Installing recommended VS Code extensions…"
  install_vscode_extensions "$DEFAULT_VSCODE_EXTS"

  # Windsurf
  if [[ -n "${WINDSURF_EXTS// /}" ]]; then
    info "Installing requested Windsurf extensions…"
    install_windsurf_extensions "$WINDSURF_EXTS"
  fi
  info "Installing recommended Windsurf extensions…"
  install_windsurf_extensions "$DEFAULT_WINDSURF_EXTS"

  # 6) JetBrains IDEA plugins (note: Toolbox-driven; CLI varies per IDE)
  if [[ -n "${IDEA_PLUGINS// /}" ]] || [[ -n "${IDEA_CONFIG// /}" ]]; then
    warn "JetBrains plugin/config automation is environment-specific."
    echo "Requested plugins: ${IDEA_PLUGINS}"
    echo "Requested config zip: ${IDEA_CONFIG}"
    cat <<'JETBRAINS_NOTE'
Tips:
  - Use JetBrains Toolbox to install IntelliJ/WebStorm/Rider.
  - Plugins can be scripted by placing .zip/.jar into:
      ~/Library/Application Support/JetBrains/<IDEA*/plugins/
    or via Settings Sync / Import Settings.
  - You can also drive plugin installs using the IDE's Toolbox/IDE scripts.
JETBRAINS_NOTE
  fi

  # 7) Quick project scaffold hint (printed once; non-invasive)
  cat <<'NEXT_STEPS'
Next steps (manual, per your structure):
  - extension/ : npm install && npm run dev/build && web-ext run
  - backend/   : dotnet new webapi && dotnet run
  - Safari:     xcrun safari-web-extension-converter ./extension/dist (after build)
NEXT_STEPS

  info "EXTENSIONS setup complete."
}

# ---------- Additional helpers (put near other helpers) ----------
npm_global_install() {
  # $1=package[@version]
  local pkg="$1"
  if npm ls -g --depth=0 "$pkg" >/dev/null 2>&1; then
    info "npm (global) already has: $pkg"
  else
    info "Installing npm (global): $pkg"
    npm install -g "$pkg"
  fi
}

ensure_code_cli() {
  if have_cmd code; then return 0; fi
  info "VS Code CLI not found; installing Visual Studio Code via Homebrew cask…"
  brew_cask_install visual-studio-code
  # brew usually puts 'code' on PATH; as a fallback, try to link it:
  if ! have_cmd code && [[ -x "/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code" ]]; then
    local link_target="/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code"
    local link_path="/opt/homebrew/bin/code"
    ln -sf "$link_target" "$link_path" || true
  fi
  have_cmd code || warn "VS Code CLI still not available; restart shell or add it to PATH."
}

ensure_windsurf_cli() {
  if have_cmd windsurf; then return 0; fi
  # Windsurf adds itself to PATH via ~/.codeium/windsurf/bin in your bash profile snippet.
  local ws="$HOME/.codeium/windsurf/bin/windsurf"
  if [[ -x "$ws" ]]; then
    return 0
  else
    warn "Windsurf CLI not detected. If installed via cask or manually, ensure it's on PATH."
  fi
}

install_vscode_extensions() {
  # expects space-separated IDs in $1
  local list="$1"
  ensure_code_cli
  if ! have_cmd code; then
    warn "Skipping VS Code extension installation (code CLI not available)."
    return
  fi
  for ext in $list; do
    if code --list-extensions | grep -Fxq "$ext"; then
      info "VS Code extension already installed: $ext"
    else
      info "Installing VS Code extension: $ext"
      code --install-extension "$ext" --force
    fi
  done
}

install_windsurf_extensions() {
  # expects space-separated IDs in $1
  local list="$1"
  ensure_windsurf_cli
  if ! have_cmd windsurf; then
    warn "Skipping Windsurf extension installation (windsurf CLI not available)."
    return
  fi
  for ext in $list; do
    if windsurf --list-extensions | grep -Fxq "$ext"; then
      info "Windsurf extension already installed: $ext"
    else
      info "Installing Windsurf extension: $ext"
      windsurf --install-extension "$ext" || warn "Failed to install Windsurf ext: $ext"
    fi
  done
}


# ---------- Orchestration ----------
main() {
  if "$DO_BASE"; then run_base; fi
  if "$DO_JAVA"; then run_java; fi
  if "$DO_DOTNET"; then run_dotnet; fi
  if "$DO_EXT"; then run_extensions; fi

  info "Done."
  warn "Open a new terminal session (or 'exec $SHELL -l') to apply shell changes."
}

main "$@"
