`direnv/envrc` is the reusable shell helper library. Project or workspace `.envrc` files call it with:

    . "$HOME/dotfiles/direnv/envrc"

Those `.envrc` files should stay fast, deterministic, and noninteractive.

For ordinary development projects, the normal use is project-specific Bash
history:

    useProjectHistory

`useProjectHistory` captures the directory where it is called and anchors one
`.bash_history` there. Moving into `src/`, `tst/`, `docs/`, or other
subdirectories must not create additional history files.

Other behavior is optional and explicit:

* Secrets
  Only projects that need API keys or other credentials should call
  `loadCentralSecrets` or `loadSecretsIfPresent`. Secret values stay outside
  the repository.

* Per-project environment variables
  Set `JAVA_HOME`, `GRADLE_OPTS`, `PATH`, feature flags, and similar values only
  inside projects that need them.

* Toolchain pinning per directory
  `useJava` and `useJavaFromFile` can select a JDK. The current `.java-home`
  helper records a machine-specific path and may later be supplemented or
  replaced by a portable Java-version mechanism.

* Gradle settings and cache policy
  Use helpers such as `useGradleCacheLocal` or `useGradleCacheShared` only when
  a project needs a nondefault cache policy.

* Workspace-level policy with inheritance
  A workspace `.envrc` can source the shared library once and apply common
  policy while projects keep their own deterministic overrides.

* Conditional behavior by directory type
  Helpers such as `isGitRepo`, `isGradleProject`, and `isMavenProject` keep
  project checks readable.

The shared helper library defines capabilities; merely sourcing it should not
silently enable secrets, Java selection, Gradle cache changes, or other
project-specific behavior.

Avoid slow, interactive, network-dependent, or heavy side-effect work in
`.envrc` files.
