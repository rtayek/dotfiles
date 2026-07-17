`direnv/envrc` is the reusable shell helper library. Project or workspace `.envrc` files call it with:

    . "$HOME/dotfiles/direnv/envrc"

Those `.envrc` files should stay fast, deterministic, and noninteractive.

Project-level uses this setup is meant to support:

* Per-project environment variables
  Set `JAVA_HOME`, `GRADLE_OPTS`, `PATH`, feature flags, and similar values only inside the project that needs them.

* Toolchain pinning per directory
  Lock one repo to an older JDK and another to a newer JDK without manually switching shells.

* Gradle settings and cache policy
  Use helpers such as `useGradleCacheLocal` or `useGradleCacheShared` to decide where Gradle state belongs.

* Per-project history
  Call `useProjectHistory` from a trusted project or workspace `.envrc` when that directory should use a local `.bash_history`.

* Secrets without committing secrets
  Load ignored local files or central secrets with helpers such as `loadSecretsIfPresent` and `loadCentralSecrets`.

* Workspace-level policy with inheritance
  A workspace `.envrc` can source the shared library once and apply common policy while projects keep their own deterministic overrides.

* Conditional behavior by directory type
  Helpers such as `isGitRepo`, `isGradleProject`, and `isMavenProject` keep project checks readable.

Avoid slow, interactive, network-dependent, or heavy side-effect work in `.envrc` files.
