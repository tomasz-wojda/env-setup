# `env-setup` — Modular Runtime Orchestration & Environment Management

`env-setup` is a modular, high-performance runtime manager and developer environment orchestration framework designed for macOS and Linux (WSL2 / dedicated hosts). It provides deterministic multi-version lifecycle management for **Apache Groovy** (3.0.x, 4.0.x, 5.0.x, 6.0.x) and **OpenJDK** (17, 21, 25, 26), coupled with automated JDK compatibility pairing, platform-abstracted package management, and unified shell extensions.

---

## Terminal Demonstration

![env-setup Installation and Workflow Demo](docs/assets/env-setup-demo.gif)

---

## Key Capabilities

- **Deterministic Multi-Runtime Isolation**: Installs and isolates multiple major versions of OpenJDK (`/opt/java`) and Apache Groovy (`/opt/groovy`) without polluting global system paths.
- **Automated JDK Compatibility Matrix**: Dynamic Groovy switchers automatically pair and activate compatible JDK runtimes (e.g., Groovy 3 binds OpenJDK 25; Groovy 4, 5, and 6 bind OpenJDK 26).
- **Independent Version Switchers**: Direct CLI switcher commands (`java17`, `java21`, `java25`, `java26`, `groovy3`, `groovy4`, `groovy5`, `groovy6`, `switchJava <major>`, `switchGroovy <major>`) instantly swap active symlinks and environment variables.
- **Modular Architecture**: Self-contained subsystems for `java/`, `groovy/`, `shell/`, and `brew/` with dedicated `setup.sh`, `verify.sh`, and `config.defaults`.
- **Zsh Productivity Layer**: Sourced via `~/.zshrc` hook or `env-setup.env.zsh`, providing auto-coloring, fast directory navigation, and optimized Git aliases (`gss`, `glo`, `gcam`).
- **Cross-Platform Support**: Built-in platform abstraction layer (`lib/platform.sh`) supporting macOS (Homebrew) and Linux distributions (Rocky Linux, RHEL, Ubuntu, Debian, Arch Linux).

---

## Subsystem Architecture

```
env-setup/
├── java/                     # OpenJDK runtime manager (17, 21, 25, 26)
├── groovy/                   # Apache Groovy runtime manager (3, 4, 5, 6)
├── shell/                    # Shell hooks, CLI tool provisioning (Zsh, Nano)
├── brew/                     # Homebrew / Linuxbrew package management
├── scripts/                  # Integration test runners and matrix test suites
├── docs/                     # Comprehensive technical documentation & guides
│   ├── assets/               # Media assets and terminal demo recordings
│   ├── architecture/         # System design and filesystem specification
│   ├── specifications/       # Functional specifications and version matrices
│   ├── modules/              # Subsystem deep-dives
│   ├── reference/            # Test and verification reference
│   └── guides/               # Getting started and operator guide
├── env-setup.env.zsh         # Unified Zsh environment loader
├── skills_used.md            # Applied engineering skills and methodologies
└── README.md                 # Primary project portal
```

---

## Quickstart Installation

### 1. Prerequisites
Ensure target runtime directories exist and have proper user ownership:

```bash
sudo mkdir -p /opt/groovy /opt/java
sudo chown -R $(id -u):$(id -g) /opt/groovy /opt/java
```

### 2. Bootstrap Installation

Clone the repository and execute the module setup scripts in sequence:

```bash
git clone https://github.com/tomasz-wojda/env-setup.git
cd env-setup

# 1. Provision OpenJDK runtimes
cd java && ./setup.sh

# 2. Provision Apache Groovy runtimes
cd ../groovy && ./setup.sh

# 3. Provision Shell environment & Zsh hooks
cd ../shell && ./setup.sh

# 4. (Optional) Provision Homebrew / Linuxbrew packages
cd ../brew && ./setup.sh
```

### 3. Activate Environment

Reload your shell or start a new Zsh session:

```bash
exec zsh
```

---

## CLI Operations Reference

### Groovy & Java Runtime Switching

| Command | Active Groovy | Auto-Paired JDK | `JAVA_HOME` / `GROOVY_HOME` |
|---|---|---|---|
| `groovy3` | 3.0.25 | OpenJDK 25 | `/opt/groovy/current` / `/opt/java/current` |
| `groovy4` | 4.0.33 | OpenJDK 26 | `/opt/groovy/current` / `/opt/java/current` |
| `groovy5` | 5.0.8 | OpenJDK 26 | `/opt/groovy/current` / `/opt/java/current` |
| `groovy6` | 6.0.0-beta-1 | OpenJDK 26 | `/opt/groovy/current` / `/opt/java/current` |

### Independent JDK Switching

| Command | Activated JDK Runtime | Target Path |
|---|---|---|
| `java17` | OpenJDK 17 LTS | `/opt/java/openjdk-17` |
| `java21` | OpenJDK 21 LTS | `/opt/java/openjdk-21` |
| `java25` | OpenJDK 25 | `/opt/java/openjdk-25` |
| `java26` | OpenJDK 26 | `/opt/java/openjdk-26` |

### Git Workflow Shortcuts

| Shortcut | Expanded Command | Purpose |
|---|---|---|
| `gss` | `git status -s` | Fast, concise status output |
| `glo` | `git log --oneline -n 10` | Recent 10 commit summaries |
| `gcam "msg"` | `git add -A && git commit -m "msg"` | Stage all modifications and commit |
| `gcam -d "msg"` | — | Dry-run preview of commit operation |

---

## Verification & Diagnostics

Run the integrated verification scripts to validate runtime integrity:

```bash
# Verify individual subsystems
./java/verify.sh
./groovy/verify.sh
./shell/verify.sh
./brew/verify.sh

# Run end-to-end Groovy/JDK matrix test suite
./scripts/test-all-groovy-jdks.sh
```

---

## Documentation Portal

Comprehensive technical documentation is available in the [`docs/`](docs/) directory:

- [**System Design & Architecture**](docs/architecture/system-design.md)
- [**Functional Specifications**](docs/specifications/functional-spec.md)
- [**Subsystem Guides**](docs/index.md):
  - [Java Module](docs/modules/java-module.md)
  - [Groovy Module](docs/modules/groovy-module.md)
  - [Shell Module](docs/modules/shell-module.md)
  - [Homebrew Module](docs/modules/brew-module.md)
- [**Getting Started Guide**](docs/guides/getting-started.md)
- [**Testing & Verification Suite**](docs/reference/testing-and-verification.md)
- [**Engineering Skills & Methodologies**](skills_used.md)
- [**Implementation Milestone Checklist**](docs/checklist.md)

---

## License

Internal developer environment configuration and tooling.
