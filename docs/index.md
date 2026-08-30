# `env-setup` Documentation Portal

Welcome to the technical documentation for `env-setup`, a modular runtime orchestration and environment management framework for macOS and Linux.

---

## 1. Documentation Index

### 1.1 Architecture & Design
- [`docs/architecture/system-design.md`](file:///rocky/home/gmb/repos/env-setup/docs/architecture/system-design.md): System design, core principles, filesystem layout, and platform abstraction layer.
- [`docs/specifications/functional-spec.md`](file:///rocky/home/gmb/repos/env-setup/docs/specifications/functional-spec.md): Functional matrix, compatibility constraints, and dynamic switcher specifications.

### 1.2 Subsystem Modules
- [`docs/modules/groovy-module.md`](file:///rocky/home/gmb/repos/env-setup/docs/modules/groovy-module.md): Apache Groovy multi-version orchestration subsystem (`groovy/`).
- [`docs/modules/java-module.md`](file:///rocky/home/gmb/repos/env-setup/docs/modules/java-module.md): OpenJDK multi-major management subsystem (`java/`).
- [`docs/modules/brew-module.md`](file:///rocky/home/gmb/repos/env-setup/docs/modules/brew-module.md): Homebrew and Linuxbrew package management subsystem (`brew/`).
- [`docs/modules/shell-module.md`](file:///rocky/home/gmb/repos/env-setup/docs/modules/shell-module.md): Shell hooks, CLI tool provisioning (`zsh`, `nano`), and interactive utilities (`shell/`).

### 1.3 Testing, Operations, and Skills
- [`docs/guides/getting-started.md`](file:///rocky/home/gmb/repos/env-setup/docs/guides/getting-started.md): Installation prerequisites, quickstart setup, daily workflows, and troubleshooting.
- [`docs/reference/testing-and-verification.md`](file:///rocky/home/gmb/repos/env-setup/docs/reference/testing-and-verification.md): Verification suites, automated test matrix runners, and diagnostic scripts.
- [`docs/checklist.md`](file:///rocky/home/gmb/repos/env-setup/docs/checklist.md): Comprehensive implementation checklist tracking all historical and active milestones.
- [`skills_used.md`](file:///rocky/home/gmb/repos/env-setup/skills_used.md): Inventory of engineering methodologies and agentic execution skills applied.

---

## 2. Quick Navigation

```
env-setup/
├── skills_used.md                            <-- Applied Skills & Methodologies
├── docs/
│   ├── index.md                              <-- (You are here)
│   ├── checklist.md                          <-- Implementation Checklists
│   ├── architecture/
│   │   └── system-design.md                  <-- System Architecture
│   ├── specifications/
│   │   └── functional-spec.md                <-- Functional Specifications
│   ├── modules/
│   │   ├── groovy-module.md                  <-- Groovy Module
│   │   ├── java-module.md                    <-- Java Module
│   │   ├── brew-module.md                    <-- Brew Module
│   │   └── shell-module.md                   <-- Shell Module
│   ├── reference/
│   │   └── testing-and-verification.md       <-- Test Suites & Verification
│   └── guides/
│       └── getting-started.md                <-- Operator & Setup Guide
```