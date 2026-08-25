# Local Configuration & Clean Directory Structure Setup

This document provides a clean, localized template for organizing tool configurations, environment variables, and project settings using an `etc/` folder pattern instead of scattered root dotfiles.

---

## 1. Home Directory Cleanup (~/etc Layout)

To eliminate dotfile clutter from the root of your home directory, centralize your global settings into a non-hidden `~/etc` folder.

### Environment Variables Configuration
Add these exports to your shell initialization script to reroute configuration-heavy tools:

```bash
# Point configuration-heavy tools away from the home root
export XDG_CONFIG_HOME="$HOME/etc"
export XDG_DATA_HOME="$HOME/var/lib"
export XDG_STATE_HOME="$HOME/var/log"

# Force Git to look inside your localized etc folder
export GIT_CONFIG_GLOBAL="$HOME/etc/gitconfig"
```

### Clean Home Layout Architecture
```text
~/ (Home Root - Clean)
└── etc/
    ├── bashrc        # Centralized shell profile settings & aliases
    └── gitconfig     # Global Git configuration (User details, UI, etc.)
```

---

## 2. Project Directory Cleanup (Project etc/ Layout)

To keep your project root pristine, group project-level tool properties, environment overrides, and configurations inside a dedicated local `etc/` folder.

### Git Ignore Optimization (No Root `.gitignore`)
Instead of keeping a visible `.gitignore` file at your project root, append your local project exclusion rules directly to the internal Git exclude file. It behaves identically but stays completely out of sight:
* **Target File Path:** `.git/info/exclude`

### Clean Project Layout Architecture
```text
~/projects/my-app/
├── src/               # Application source files
└── etc/               # Project-specific configurations
    └── tool.properties # Build settings, environment variables, or local flags
```

---

## 3. Comparison Reference

| Target Scope | Traditional Cluttered Location | Clean Localized Location |
| :--- | :--- | :--- |
| **Global Git Settings** | `~/.gitconfig` | `~/etc/gitconfig` |
| **Global App Settings** | `~/.config/` | `~/etc/` |
| **Project Ignores** | `project/.gitignore` | `project/.git/info/exclude` |
| **Project Properties** | `project/config.properties` | `project/etc/config.properties` |
