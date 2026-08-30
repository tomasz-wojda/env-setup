# Testing and Verification Reference

Complete technical reference for all test suites, matrix verification runners, and health check scripts in `env-setup`.

---

## 1. Overview of Verification Subsystems

`env-setup` implements a two-tier verification architecture:
1. **Module Health Check Scripts (`verify.sh`)**: Non-destructive diagnostic scripts verifying directory presence, symlink integrity, executable formats, and binary output.
2. **Automated Test Matrix Suites (`scripts/`)**: End-to-end integration test runners executing real-world workloads, matrix compatibility evaluations, and shell subshell validation.

---

## 2. Test Matrix Suites

### 2.1 Shell Functions Test Suite (`scripts/test-shell-functions.sh`)
- **Execution**: `./scripts/test-shell-functions.sh`
- **Engine**: Spawns clean interactive Zsh subshell (`zsh -i -c ...`), sources `env-setup.env.zsh`.
- **Assertions**:
  - Validates function definitions: `ls`, `ssh`, `gss`, `glo`, `gcam`, `switchGroovy`, `switchJava`, `groovy3-6`, `java17-26` (14 assertions).
  - Validates `gcam --dry-run` parameter parsing and command formatting.
  - Validates full dynamic activation of `groovy3`, `groovy4`, `groovy5`, and `groovy6`, asserting resulting `JAVA_HOME`, `GROOVY_HOME`, and symlink state.

### 2.2 Groovy Multi-JDK Matrix Test (`scripts/test-all-groovy-jdks.sh`)
- **Execution**: `./scripts/test-all-groovy-jdks.sh`
- **Description**: Iterates through all installed Groovy major versions (3, 4, 5, 6) and tests execution against all installed OpenJDK runtimes (17, 21, 25, 26).
- **Workload**: Executes real Groovy inline script `println "Groovy ${GroovySystem.version} on Java ${System.getProperty('java.version')}"` asserting compatibility boundaries and reporting matrix table.

---

## 3. Module Verification Scripts

### 3.1 `groovy/verify.sh`
- **Purpose**: Verifies all Groovy installations, configured JDK symlinks, and default active version.
- **Commands**:
  ```bash
  cd groovy && ./verify.sh
  ```
- **Exit Codes**: `0` on all checks passed; `1` on missing runtime or broken symlink.

### 3.2 `java/verify.sh`
- **Purpose**: Verifies all JDK major versions in `/opt/java`, `/opt/java/current` symlink, and runs `java -version`.
- **Commands**:
  ```bash
  cd java && ./verify.sh
  ```

### 3.3 `brew/verify.sh`
- **Purpose**: Verifies Homebrew binary presence, installed CLI formulae, and macOS casks.
- **Commands**:
  ```bash
  cd brew && ./verify.sh
  ```

### 3.4 `shell/verify.sh`
- **Purpose**: Verifies `zsh` and `nano` binary availability, `~/.zshrc` hook integrity, and shell function availability in Zsh.
- **Commands**:
  ```bash
  cd shell && ./verify.sh
  ```

---

## 4. Comprehensive Validation One-Liner

To run the entire verification and test suite in sequence:

```bash
./java/verify.sh && ./groovy/verify.sh && ./shell/verify.sh && ./scripts/test-shell-functions.sh
```