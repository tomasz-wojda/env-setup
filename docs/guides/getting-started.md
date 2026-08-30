# Getting Started and Operator Guide

Step-by-step installation, daily workflow, and troubleshooting guide for `env-setup`.

---

## 1. System Prerequisites

### 1.1 macOS
- macOS 12+ (Apple Silicon or Intel).
- Xcode Command Line Tools (`xcode-select --install`).
- Standard user account with `sudo` rights.

### 1.2 Linux (WSL2 / Dedicated Server / VM)
- Any modern Linux distribution (Rocky Linux, RHEL, Ubuntu, Debian, Arch Linux, openSUSE).
- Standard developer user with ownership of `/opt/groovy` and `/opt/java`:
  ```bash
  sudo mkdir -p /opt/groovy /opt/java
  sudo chown -R $(id -u):$(id -g) /opt/groovy /opt/java
  ```

---

## 2. Bootstrapping Installation

Run the setup scripts in sequential order:

```bash
# 1. Setup Java/OpenJDK runtimes (17, 21, 25, 26)
cd java && ./setup.sh

# 2. Setup Groovy runtimes (3, 4, 5, 6)
cd ../groovy && ./setup.sh

# 3. Setup Shell environment, Zsh, Nano, and ~/.zshrc hook
cd ../shell && ./setup.sh

# 4. (Optional) Setup Homebrew / Linuxbrew packages
cd ../brew && ./setup.sh
```

After setup, source your `~/.zshrc` or start a new Zsh session:

```bash
exec zsh
```

---

## 3. Daily Workflows

### 3.1 Switching Groovy Versions
```bash
groovy3    # Activates Groovy 3.0.25 and auto-maps OpenJDK 25
groovy4    # Activates Groovy 4.0.33 and auto-maps OpenJDK 26
groovy5    # Activates Groovy 5.0.8 and auto-maps OpenJDK 26
groovy6    # Activates Groovy 6.0.0-beta-1 and auto-maps OpenJDK 26
```

### 3.2 Switching Java Versions Independently
```bash
java17     # Activates OpenJDK 17 LTS
java21     # Activates OpenJDK 21 LTS
java25     # Activates OpenJDK 25
java26     # Activates OpenJDK 26
```

### 3.3 Git Helpers
```bash
gss                    # Short git status
glo                    # Recent 10 oneline commits
gcam "feat: message"   # Add all changes and commit
gcam -d "test commit"  # Dry-run commit command
```

---

## 4. Troubleshooting

### Problem: `which javac: no javac in PATH`
- **Cause**: Active JDK does not contain `javac` in PATH if `JAVA_HOME` is not pointing to `/opt/java/current`.
- **Solution**: Execute `switchJava 26` or `groovy6` to re-export `JAVA_HOME` and update `PATH`.

### Problem: Line ending errors (`‘bash\r’: No such file or directory`)
- **Cause**: Files checked out with Windows CRLF line endings on WSL mounts.
- **Solution**: The repository includes `.gitattributes` enforcing `eol=lf`. Run `git checkout -f` or `git add --renormalize .` to normalize working tree files.