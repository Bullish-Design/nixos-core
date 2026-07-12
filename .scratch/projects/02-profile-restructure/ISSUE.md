# ISSUE — nix-meta/nixos-core profile structure doesn't compose; restructure + fold in the repoman family

**Filed:** 2026-07-11 · **Surfaced by:** trying to install `gh` on `server` (andrew's dev box).
**Repos:** `nix-meta` (machine/profile composition) + `nixos-core` (system modules).

---

## TL;DR

`server` is andrew's development machine but does **not** use `profiles.developer`, and
`developer.nix` **cannot** be added to it as-is — it's hardcoded for the WSL `nixos` user and
re-declares infrastructure (`home-manager`, `nix-terminal`, `repoman`, `nixbuild`,
`system.stateVersion`) that the server already owns for `andrew`. The immediate need (`gh`) was
worked around by adding it to `profiles/terminal.nix` `extraPackages`, but the underlying
structure invites this confusion. We want to **restructure the profiles** so the "developer"
capability composes onto any host, and to **integrate more of the repoman family** consistently.

---

## What happened (repro)

1. Needed the GitHub CLI (`gh`) on `server` — a running agent had to create a GitHub repo +
   push, which git-over-SSH can't do (`gh` was absent; the cached `~/.config/gh` token was also
   expired → HTTP 401).
2. First instinct: "add `gh` to `developer.nix`." But `server` never imports `developer.nix`.
3. Second instinct: "add `profiles.developer` to the server's machine list." That would break.

## Current state (evidence)

- **Machines defined:** only `server`. `nix-meta/flake.nix:73`:
  ```nix
  server = mkMachine "server" [ profiles.minimal profiles.terminal profiles.gpu-compute profiles.agent profiles.secrets ];
  ```
  → `gpu-compute` is already active; `developer` is **not** used by any machine.

- **`profiles/developer.nix` is WSL-shaped and won't compose onto `server`:**
  - imports/configures **`nixos-core.common`** (line 9, 17) while the server tier uses
    **`nixos-core.base`** (`profiles/minimal.nix`, `machines/server.nix` set `nixos-core.base`).
  - hardcodes **`home-manager.users.nixos`** (line 31) — server's user is `andrew`.
  - re-declares `home-manager`, `nix-terminal` (corePackages/extraPackages/zsh/atuin),
    `programs.nixbuild`, `programs.repoman`, and `system.stateVersion` (line 14) — all of which
    the server already provides for `andrew` via `profiles/terminal.nix` + `machines/server.nix`.
  - `programs.repoman.accounts` pins a specific repo list for the `nixos` user.
  → Importing it onto `server` yields a home-manager config for a non-existent `nixos` user and
    conflicting definitions.

- **`profiles/terminal.nix` is the model to follow.** It reads the username SSOT
  (`username = config.nixos-core.base.username;`, line ~9) so it targets whatever host imports it
  (correctly `andrew` on the server), imports HM dedup-safely, and uses `lib.mkDefault` so the
  machine's own values win. This is exactly the composition discipline `developer.nix` lacks.

- **The server already has most of "developer" via `terminal.nix`:** the nix-terminal core kit
  (ripgrep/fd/bat/eza/fzf/jq/curl/wget/htop) + starship + atuin + git aliases. What
  `developer.nix` adds on top is really just `nodejs`, `python3` (usually per-repo via devenv) and
  `repoman`/`nixbuild` (already wired for `andrew` elsewhere).

## Immediate fix applied

- Added `gh` to `nix-meta/profiles/terminal.nix` `extraPackages` (next to `yazi`) — per-user,
  composes onto the server via the username SSOT. (NOT `developer.nix`.)
- Note: `gh auth login` still needs to be run once on the box (the cached token is expired).

---

## Proposed direction (for a restructure session)

Goals: (a) a "developer" capability that composes onto ANY host (no hardcoded user/tier), (b)
consistent integration of the **repoman family**, (c) eliminate the `common` vs `base` +
duplicate-HM confusion.

1. **Pick ONE nixos-core tier name** (`base` vs `common`) and make every profile use it. Today
   `minimal`/`server` use `nixos-core.base`; `developer` uses `nixos-core.common`. Decide which is
   canonical (`base` seems to be the live one) and delete/alias the other.

2. **Refactor `developer.nix` into a composable profile** modeled on `terminal.nix`:
   - read `config.nixos-core.base.username` (no hardcoded `nixos`),
   - `lib.mkDefault` everything that a machine might pin (`stateVersion`, HM toggles),
   - import HM dedup-safely,
   - carry only the *additive* developer bits (language toolchains, repoman family) so it stacks
     on top of `terminal` instead of re-declaring it.

3. **Integrate the repoman family consistently.** Home-manager modules already available from
   `nix-terminal`: `terminal`, `nixbuild`, `repoman`. Related repos in the org: `repoman`,
   `devman`, `terminal-state`, plus `nix-nvim`/`nixvim`. Decide which belong in a shared
   `developer`/`workstation` profile vs per-host, and parameterize `repoman.accounts`/`baseDir`
   instead of hardcoding the WSL values. (The server also runs `zelligate`/`nix-paseo` — make sure
   the developer profile composes with those, not against them.)

4. **Add `server` to the developer set once it composes** — it IS a dev box; it should get the
   refactored `developer`/`workstation` profile rather than piecemeal `extraPackages` additions
   like this `gh` one (which can then move into the profile).

## Open questions

- `base` vs `common`: which is the canonical nixos-core tier, and can the other be removed?
- Should "developer" be one profile or split (e.g. `workstation` = shell+editor+repoman family,
  `languages` = node/python/rust toolchains)?
- How should `repoman.accounts` be parameterized per host (option in `nixos-core.base`? a separate
  `nixos-core.repoman` module)?
- Does anything still consume `developer.nix` as-is (the WSL `nixos` box)? If so, the refactor must
  keep that host working while generalizing.
