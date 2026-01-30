Here are the “other things you can do with direnv” that we covered (the list you told me not to forget), organized the same way:

* **Per-project environment variables**
  Set `JAVA_HOME`, `GRADLE_OPTS`, `PATH`, feature flags, etc., that appear only inside a project.

* **Toolchain pinning per directory**
  Lock an old repo to JDK 17 and a new one to JDK 25, without manually switching shells.

* **Secrets without committing secrets**
  `source .env.secrets` (ignored/untracked) to load API keys/tokens locally.

* **Derived environment (computed values + setup)**
  Compute vars from `$PWD`, create dirs (`mkdir -p .logs`), validate assumptions (fail fast if `build.gradle` missing).

* **Workspace-level policy with inheritance**
  One `.envrc` at the workspace root; children inherit, but still get **per-project** behavior via `$PWD`.

* **Safety rails via explicit trust boundary**
  Putting “dangerous” env like `AWS_PROFILE=prod` in `.envrc` is safe-ish because it requires `direnv allow`.

* **Automatic cleanup on exit**
  When you `cd` out, env changes revert automatically—no “undo” scripts.

* **Conditional behavior by directory type**
  If `.git/` exists, do X; if `pom.xml`, set Maven flags; if Gradle, set Gradle cache, etc.

* **Multi-tool coordination**
  Keep Java/Gradle/tests/IDE launches consistent by centralizing env decisions in the project boundary.

* **What not to do with direnv**
  Avoid slow, interactive, network-y, or heavy side-effect work in `.envrc`. Keep it fast and deterministic.

If you want, I can turn this into a **ready-to-commit `~/dotfiles/direnv/envrc` library** with a couple of reusable functions (e.g., `useJava`, `useGradleCache`, `useProjectHistory`, `loadSecretsIfPresent`) tailored to your Eclipse/Gradle workflow.
