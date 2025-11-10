# 🧰 macOS Development Environment Setup

This repository provides a **unified macOS bootstrap script** (`setup-env.sh`) for preparing a full software-engineering workstation from a clean virtual machine or new Mac.

It supports **four environment categories** — `BASE`, `JAVA`, `DOTNET`, and `EXTENSIONS` — and installs everything needed for professional .NET, Java, and Chrome/Safari extension development.

---

## ⚡️ Quick Start

Run from Terminal (bash or zsh):

```bash
bash setup-env.sh
```

> 💡 By default, this runs the **BASE** setup only.

### Run with specific environments

```bash
bash setup-env.sh --java
bash setup-env.sh --dotnet
bash setup-env.sh --extensions
```

Or install everything at once:

```bash
bash setup-env.sh --all
```

---

## 🧩 Overview of Categories

### 🟩 BASE

Installs the **core tools and shell configuration** required on any developer machine.

**Includes:**
- 🧱 [Homebrew](https://brew.sh) installation and update
- 🖥️ Modern **Bash** (from Homebrew) + Bash Completion
- 🧭 Sets Bash as default shell
- 🧩 Installs:
  - `git`
  - `openssh`
  - `google-chrome`
  - `github` (GitHub Desktop)
  - `windsurf` (AI-powered editor)
- 🧠 Adds Git-aware prompt showing branch + dirty status
- ⌨️ Enables history search with ↑ / ↓ arrows
- 🪣 Appends safe snippets to `~/.bashrc` and `~/.bash_profile`

**Example prompt:**
```
user@host ~/project [main*] $
```
(`*` means uncommitted changes)

---

### ☕ JAVA

Sets up a **Java 21 / Gradle / IntelliJ IDEA** environment for Spring Boot or enterprise development.

**Includes:**
- ☕ **Temurin JDK 21** via Homebrew (`brew install --cask temurin`)
- 💡 **IntelliJ IDEA Ultimate** via Homebrew (`brew install --cask intellij-idea`)
- 🧰 **JetBrains Toolbox**
- ⚙️ **Gradle** build system (`brew install gradle`)
- ✅ Configures:
  - `JAVA_HOME` (via `/usr/libexec/java_home`)
  - Adds `$JAVA_HOME/bin` to PATH
- 🧩 Installs recommended **VS Code** & **Windsurf** Java extensions:
  - `redhat.java`
  - `vscjava.vscode-java-pack`
  - `vscjava.vscode-spring-boot-dashboard`
  - `vscjava.vscode-spring-initializr`
  - `richardwillis.vscode-gradle`
  - `vscjava.vscode-java-test`

---

### ⚙️ DOTNET

Prepares the **.NET 10 RC2+ SDK** environment for modern backend development.

**Includes:**
- 🧩 Installs .NET via Homebrew (`brew install dotnet@10` or `dotnet`)
- ✅ Verifies with `dotnet --info`
- 📦 Installs recommended **VS Code / Windsurf** extensions:
  - `ms-dotnettools.csharp`
  - `formulahendry.code-runner`
  - `humao.rest-client`
  - `ms-vscode.vscode-browser-debug`

---

### 🧩 EXTENSIONS

Sets up everything needed for **browser extension development** (Chrome + Safari) using TypeScript, React, and Vite — plus a .NET companion API service.

**Includes:**
- 🧰 Node.js ≥ 20
- 📦 Global npm tools:
  - `typescript@^5.4`
  - `vite@^5`
  - `eslint`
  - `prettier`
  - `web-ext` (for local testing & packaging)
- 🧪 Postman for API testing
- 🧱 Xcode check for Safari extension converter
- 🧩 Installs recommended **VS Code / Windsurf** extensions:
  - `esbenp.prettier-vscode`
  - `dbaeumer.vscode-eslint`
  - `antfu.vite`
  - `kamikillerto.vscode-colorize`
  - `formulahendry.auto-rename-tag`
  - `ritwickdey.LiveServer`
  - `ms-dotnettools.csharp`
  - `humao.rest-client`
  - `aaravb.chrome-extension-developer-tools`
  - `ms-vscode.vscode-browser-debug`
  - `peterjausovec.vscode-docker`

---

## 📁 Folder Structure

```
project-root/
├── setup-env.sh              # Main environment bootstrap script
├── env/
│   ├── extensions-browser.json   # Recommended extensions for Chrome/Safari + Vite dev
│   ├── extensions-dotnet.json    # Recommended extensions for .NET 10+ backend dev
│   └── extensions-java.json      # Recommended extensions for Java 21 + Gradle + Spring
└── README.md
```

---

## 🗂️ `env/` Extension Manifests

Each file defines the recommended IDE extensions for its stack.  
They can be imported automatically by VS Code or manually by Windsurf.

### `env/extensions-browser.json`
For **browser extension** dev (TypeScript + React + Vite + .NET backend).

```json
{
  "recommendations": [
    "esbenp.prettier-vscode",
    "dbaeumer.vscode-eslint",
    "antfu.vite",
    "kamikillerto.vscode-colorize",
    "formulahendry.auto-rename-tag",
    "ritwickdey.LiveServer",
    "ms-dotnettools.csharp",
    "humao.rest-client",
    "aaravb.chrome-extension-developer-tools",
    "ms-vscode.vscode-browser-debug",
    "peterjausovec.vscode-docker"
  ]
}
```

---

### `env/extensions-dotnet.json`
For **.NET 10 RC2+** backend projects.

```json
{
  "recommendations": [
    "ms-dotnettools.csharp",
    "formulahendry.code-runner",
    "humao.rest-client",
    "ms-vscode.vscode-browser-debug"
  ]
}
```

---

### `env/extensions-java.json`
For **Java 21 + Gradle + Spring Boot** projects.

```json
{
  "recommendations": [
    "redhat.java",
    "vscjava.vscode-java-pack",
    "vscjava.vscode-spring-boot-dashboard",
    "vscjava.vscode-spring-initializr",
    "richardwillis.vscode-gradle",
    "vscjava.vscode-java-test"
  ]
}
```

---

## 🧭 CLI Options Summary

| Option | Description |
|--------|-------------|
| `--java` | Installs Java 21 + IntelliJ + Gradle + extensions |
| `--dotnet` | Installs .NET 10 RC2+ SDK + extensions |
| `--extensions` | Installs Node/Vite/TypeScript + browser extension stack |
| `--all` | Runs BASE + all other categories |
| `--vscode-ext "id1 id2"` | Install extra VS Code extensions |
| `--windsurf-ext "id1 id2"` | Install extra Windsurf extensions |
| `--idea-plugins "id1,id2"` | (Optional) JetBrains plugin hints |
| `--idea-config /path/to.zip` | (Optional) IDEA settings import |
| `-h`, `--help` | Show usage summary |

---

## 🔄 Idempotent Design

All installation steps are **safe to re-run**:
- Homebrew and npm installations skip if already present.
- `.bashrc` and `.bash_profile` updates use **unique markers** and never duplicate content.
- Extension installations check for existing IDs first.

---

## 🧠 Prompt and Shell Enhancements

**Prompt features:**
- Displays Git branch + dirty status
- Preserves colors and cursor positioning
- Adds intuitive history search (`↑` / `↓`)

Example:
```
andrey@macbook ~/PromptVCS [feature-setup*] $
```

---

## 🧩 Recommended Workflow

1. Clone your repo or open Terminal on a clean VM.  
2. Run:

   ```bash
   chmod +x setup-env.sh
   ./setup-env.sh --all
   ```

3. Restart your terminal (`exec $SHELL -l`) to apply shell and PATH changes.  
4. Open VS Code or Windsurf — accept extension recommendations.  
5. Start building:
   - Java: `gradle build`
   - .NET: `dotnet run`
   - Browser extension: `npm run dev && web-ext run`

---

## 🧱 Compatibility

| Component | Minimum Version |
|------------|----------------|
| macOS | 13 Ventura or newer |
| Node.js | 20.x |
| .NET SDK | 10.0 RC2 or later |
| Java | 21 (Temurin) |
| Bash | 5.x (via Homebrew) |

---

## 🧩 Author Notes

- The script was designed to run cleanly on **macOS 26.0.1** VMs.
- All installs are localized to Homebrew locations (`/opt/homebrew`).
- Windsurf extensions mirror VS Code IDs (compatible CLI format).
- Java section now uses **Gradle** as the default build tool instead of Maven.

---

**Maintained by:**  
_Andrey Tsygankov
Focus: .NET 9/10 RC, Java 21, AI tooling, Onshape API, CAD/PLM automation  

---

✅ **End of File — `README.md`**
