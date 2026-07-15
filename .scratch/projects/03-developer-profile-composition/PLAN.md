# PLAN — Make the developer profile composable and integrate the repoman family

**Status:** Planned  
**Created:** 2026-07-12  
**Primary implementation repo:** `../nix-meta`  
**Supporting repo (only if needed):** this repository, `nixos-core`  
**Source issue:** `../02-profile-restructure/ISSUE.md`

---

## 1. Outcome

Any NixOS machine can opt into the developer workflow without inheriting a
different username, system tier, Home Manager owner, state version, or machine
configuration. In particular, `server` becomes:

```nix
profiles.minimal
profiles.terminal
profiles.developer
profiles.gpu-compute
profiles.agent
profiles.secrets
```

The profile stack has distinct responsibilities:

| Layer | Owns | Does not own |
|---|---|---|
| `minimal` | `nixos-core.base`, system user, host-neutral system defaults | interactive user environment |
| `terminal` | Home Manager bootstrap, shell/terminal UX, day-to-day CLI tools | language toolchains and repo workflow policy |
| `developer` | additive toolchains and opt-in developer workflow modules | system tier, host identity, Home Manager infrastructure, terminal configuration already owned by `terminal` |
| machine module | hostname, install-specific state version, hardware, services, host-specific Home Manager configuration | shared developer policy |

`repoman`, `nixbuild`, and later related tools have explicit ownership and
per-host configuration rather than being hardcoded to the retired WSL account.

---

## 2. Constraints and non-goals

- Implement the profile restructuring in **`nix-meta`**. `nixos-core` remains a
  system-module library and must not acquire Home Manager/repoman policy.
- Preserve the current server behavior, including its `andrew` Home Manager
  module for `zelligate` and its machine-owned `system.stateVersion = "26.05"`.
- Do not reintroduce the obsolete `nixos-core.common` namespace as a new
  canonical API. The current exported system tier is `nixos-core.base`.
- Do not make a developer profile enable desktop/GUI services or conflict with
  `zelligate`, `nix-paseo`, GPU compute, agent, or secrets profiles.
- Do not store credentials or GitHub auth material declaratively. `gh auth
  login` remains a one-time local user action.
- Do not assume all developer hosts use identical repositories, checkout roots,
  toolchains, or transport choices.

---

## 3. Baseline facts to preserve

1. `nix-meta/profiles/developer.nix` is dormant: `profiles/default.nix` does
   not export it and describes it as an old `common`-based skeleton.
2. `nixos-core/flake.nix` exports `base`, not `common`. Re-enabling the current
   developer profile would fail at its `nixos-core.nixosModules.common` import
   before any intended composition can occur.
3. `terminal.nix` already demonstrates the desired pattern:
   `username = config.nixos-core.base.username`, Home Manager import,
   `mkDefault` on shared bootstrap settings, and configuration under
   `home-manager.users.${username}`.
4. `machines/server.nix` imports Home Manager and owns an `andrew` user module
   for `zelligate`; its module and profile-provided modules must merge.
5. `terminal.nix` currently carries `gh` as the immediate operational fix. It
   should stay until the refactored developer profile is both exported and used
   by `server`.

---

## 4. Decisions to lock before implementation

### 4.1 Canonical system tier

Adopt **`nixos-core.base`** as canonical. Remove `common` references from the
dormant `developer` and `gui` profiles. Do not add a compatibility alias unless
a real, externally consumed configuration is discovered first.

**Discovery gate:** run a workspace and Git-history search for
`nixos-core.common`, `nixosModules.common`, and consumers of the old developer
profile. If an active WSL host is found, migrate it in the same change or keep a
short-lived, documented compatibility path with a removal date.

### 4.2 Profile shape

Start with one additive `developer` profile, retaining `terminal` as a separate
prerequisite. Do not prematurely create a `workstation` profile: it risks
blurring terminal, graphical desktop, and language-toolchain responsibilities.

Use a later split only when there is a concrete consumer that needs one of these
independently:

- `developer`: workflow modules (`repoman`, `nixbuild`) and broadly useful dev
  tools;
- `languages`: large or opinionated shared language toolchains;
- `workstation`: only if a stable graphical/editor bundle emerges.

### 4.3 Repoman configuration boundary

Define configuration under a dedicated **nix-meta profile option namespace**,
for example `nix-meta.developer` or `nix-meta.repoman`, rather than under
`nixos-core.base`. It is user-level workspace policy, not a base system concern.

Minimum configuration surface:

```nix
nix-meta.developer = {
  enable = true;
  packages = [ ];
  nixbuild = {
    enable = true;
    outputDir = null; # derive a user-relative default when null
  };
  repoman = {
    enable = true;
    baseDir = null;   # derive a user-relative default when null
    accounts = [ ];
    useSsh = true;
    maxConcurrent = 5;
    timeout = 300;
  };
};
```

Exact option names may follow existing project conventions, but types,
descriptions, and defaults must make a host override obvious. `accounts` must
default to an empty list: the profile may enable repoman support without
silently cloning or managing a particular organization.

### 4.4 Checkout-root and toolchain defaults

Use a documented, user-relative default for logs and checkout roots, such as
`"/home/${username}/Documents/Projects"` if that matches the fleet convention.
Do not retain `/home/nixos/code`.

Keep Node and Python in the initial profile only if they are genuinely desired
on every developer host. Prefer project-pinned `devenv` toolchains for
repo-specific versions. Rust, Android, CUDA SDKs, and other large toolchains
remain opt-in until a shared need is established.

---

## 5. Implementation phases

### Phase 0 — Inventory and compatibility check

**Repo:** `nix-meta` (read-only)

1. Search the full workspace for imports/exports of `profiles.developer`,
   `profiles.gui`, `nixos-core.common`, and `nixosModules.common`.
2. Inspect `nix-terminal` Home Manager option definitions for `repoman` and
   `nixbuild`: option types, defaults, and whether their modules safely merge
   when imported alongside `terminal`.
3. Confirm how Home Manager modules merge for `server`'s existing `andrew`
   `zelligate` module plus profile-supplied `andrew` modules.
4. Record active legacy-host requirements, if any, in this plan or the PR
   description before deleting the WSL-shaped assumptions.

**Exit criterion:** every active consumer and its username/tier is known; no
compatibility decision is based on the dormant file alone.

### Phase 1 — Restore one base-tier vocabulary

**Repo:** `nix-meta`

1. Update `profiles/developer.nix` to import
   `nixos-core.nixosModules.base`, or remove the import entirely if `minimal`
   is its required prerequisite and developer has no system-level base work.
2. Remove all `nixos-core.common = { ... };` configuration from developer.
   `minimal` already owns flakes, base system packages, and user creation.
3. Audit `profiles/gui.nix` and either port it from `common` to `base` or leave
   it explicitly unexported with a clear follow-up; do not leave a misleading
   non-functional skeleton presented as usable.
4. Update `profiles/default.nix` comments so the export status matches reality.

**Exit criterion:** there are no active `common` references in `nix-meta`, and
an exported developer profile evaluates against the current nixos-core flake.

### Phase 2 — Add a composable developer profile API

**Repo:** `nix-meta`

1. Add a small module that declares the developer options from §4.3. It may be
   `profiles/developer.nix` itself or a separate profile-options module; keep
   its public API in one location.
2. Read the user only from `config.nixos-core.base.username`.
3. Import Home Manager only as needed. Set `useGlobalPkgs`, `useUserPackages`,
   `backupFileExtension`, and `home.stateVersion` with `lib.mkDefault` when
   offering fallbacks. Do not set `system.stateVersion` here.
4. Configure only `home-manager.users.${username}`. Never create a literal
   `nixos` user entry.
5. Import `nix-terminal.homeManagerModules.nixbuild` and
   `nix-terminal.homeManagerModules.repoman` inside that user module. Do not
   re-import/configure `nix-terminal.homeManagerModules.terminal` or repeat its
   shell aliases, zsh, Atuin, git, or core package list.
6. Add developer packages through an additive list. Avoid supplying a second
   complete `programs.nix-terminal` attrset; compose only the attributes that
   developer owns.

**Exit criterion:** importing `minimal + terminal + developer` for a username
other than `nixos` yields one HM user and has no host-specific paths.

### Phase 3 — Integrate repoman and nixbuild policy

**Repo:** `nix-meta`

1. Wire `programs.nixbuild` from the developer options, deriving its output
   directory from the active user when no host override is supplied.
2. Wire `programs.repoman` from the developer options. Enablement, checkout
   root, accounts, SSH transport, concurrency, and timeout must be configurable
   outside the profile implementation.
3. Define `server`’s repoman accounts explicitly in `machines/server.nix` (or
   a narrowly scoped server policy file), including the desired organization
   repositories: `nix-meta`, `nixos-core`, `nix-terminal`, `nixvim`,
   `terminal-state`, `devman`, and any confirmed additions.
4. Decide whether `nix-nvim` is managed by repoman or only consumed as a flake
   input; do not add it to the checkout list merely because it is related.
5. Keep `zelligate` and `nix-paseo` configuration machine-owned. Verify the
   chosen repoman base directory is compatible with their workspace scanning
   rules and does not cause unwanted service exposure.

**Exit criterion:** no repoman setting references `/home/nixos`, a host can use
its own repo list, and developer imports do not modify zelligate/paseo settings.

### Phase 4 — Migrate server and relocate `gh`

**Repo:** `nix-meta`

1. Export `developer` from `profiles/default.nix`.
2. Add `profiles.developer` to the `server` `mkMachine` list after `terminal`.
3. Move `gh` from `terminal.nix` to developer’s additive package set. Keep it
   in terminal until the same change that makes server consume developer; do
   not create a deployment window without `gh`.
4. Populate server’s developer options with the intended repoman/nixbuild
   policy and paths for `andrew`.
5. Run `gh auth login` interactively on the deployed server; token renewal is
   operational state, not a declarative configuration task.

**Exit criterion:** the server gets `gh` and developer workflow tooling from
the developer profile, not from a terminal-profile exception.

### Phase 5 — Evaluate, build, and deploy safely

**Repo:** `nix-meta`

1. Run formatter/linter commands used by the repository.
2. Run `nix flake show` and `nix flake check`.
3. Build or dry-run the server toplevel:

   ```sh
   nix build .#nixosConfigurations.server.config.system.build.toplevel --dry-run
   ```

4. Inspect the evaluated server configuration to confirm:
   - `nixos-core.base.username == "andrew"`;
   - Home Manager has only the intended `andrew` configuration, with no
     `home-manager.users.nixos` entry introduced by developer;
   - `system.stateVersion` remains `26.05`;
   - `programs.nix-terminal`, `programs.nixbuild`, and `programs.repoman` are
     enabled/configured once at their respective ownership boundaries;
   - terminal aliases and zelligate service configuration remain present.
5. Deploy with the repository’s standard `nixos-rebuild switch --flake
   .#server` workflow only after the evaluation/build succeeds.
6. Post-deploy smoke test as `andrew`:

   ```sh
   command -v gh repoman nixbuild
   gh auth status
   repoman --help
   nixbuild --help
   systemctl --user status zelligate
   ```

**Exit criterion:** a successful rebuild and the smoke tests show the profile
composes on the running server without a Home Manager clobber or service
regression.

---

## 6. Acceptance matrix

| Scenario | Expected result |
|---|---|
| `minimal + terminal` | Existing headless interactive environment remains unchanged; `gh` is absent only after developer migration is complete. |
| `minimal + terminal + developer` with username `andrew` | One merged `andrew` HM configuration; dev packages and workflow modules added. |
| Same stack with another base username | No literal user/path leaks; user-scoped defaults follow the configured username. |
| `server` stack | zelligate and paseo remain configured from the machine module; developer adds no conflicting service ownership. |
| Profile imported without host repoman accounts | Evaluation succeeds; repoman has an empty/no-op account policy rather than stale WSL repositories. |
| Existing legacy WSL consumer, if found | Either migrated and verified in this change, or protected by an explicit temporary compatibility plan. |

---

## 7. Risks and mitigations

| Risk | Mitigation |
|---|---|
| Hidden legacy WSL consumer depends on old developer defaults | Phase 0 discovery before removal; migrate it or explicitly retain compatibility temporarily. |
| Home Manager duplicate imports/configuration create ambiguous ownership | Use module merging deliberately; import terminal only in terminal and workflow modules only in developer. |
| Machine-specific paths leak into shared profile | Derive defaults from username or require host options; review for `/home/nixos` and `/home/andrew` literals. |
| Developer becomes a catch-all package dump | Add only tools with fleet-wide developer value; leave repo-specific versions in devenv. |
| repoman checkout root changes zelligate exposure | Confirm workspace scan/opt-in behavior before choosing the server base directory. |
| State-version conflict or accidental bump | Never set `system.stateVersion` in shared profiles; keep `home.stateVersion` a `mkDefault`. |

---

## 8. Deferred follow-ups

- Generalize or retire the dormant `gui` profile after the common-to-base audit.
- Introduce `languages` only when a second consumer demonstrates that developer
  workflow and language toolchains need independent selection.
- Evaluate whether `devman`, `terminal-state`, and editor integrations deserve
  their own opt-in modules once their Nix/Home Manager interfaces are known.
- Document the final profile contract in `nix-meta`’s README once the migration
  lands, including which layer owns `gh`, repoman, and nixbuild.
