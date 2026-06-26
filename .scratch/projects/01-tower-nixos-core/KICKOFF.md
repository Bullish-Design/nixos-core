# KICKOFF — nixos-core: add `desktop`, `nvidia-compute`, `input-kanata` modules + parameterize `username`

You are starting a FRESH session in the **nixos-core** repo (`~/Documents/Projects/nixos-core`).
This repo today is "WSL only" — it exposes `nixosModules.{wsl-upstream, common, wsl}`. The Tower Dotfiles
project promotes it into the real system-level NixOS module library shared by both the framework laptop and
the headless tower. Your job is to ADD three system modules and PARAMETERIZE the username, then export them
from `flake.nix`. This is the implementation session — the planning is done.

────────────────────────────────────────────────────────────────────────

## 0. Where this fits

- **Master plan (read for context):** `/home/andrew/.dotfiles/.scratch/projects/37-tower-dotfiles/PLAN.md`
  — §4 (architecture/repo map: `nixos-core = common · desktop · nvidia-compute · input-kanata`), §5 (machine
  composition + `username → andrew` parameterization), §8 Phase 1 (username param) and Phase 4
  (`profiles.gpu-compute` = headless compute-only NVIDIA), §10 (headless NVIDIA minimal module set + GPU
  power-limiting), §11 (risks).
- **Decision log (read for the locked NVIDIA decisions):**
  `/home/andrew/.claude/projects/-home-andrew--dotfiles/memory/tower-dotfiles-project.md`.
- **Phases this packet implements:** **Phase 1** (username `nixos → andrew`, parameterized) and **Phase 4**
  (`nvidia-compute` for the tower's `profiles.gpu-compute`). `desktop` and `input-kanata` are the system halves
  of the laptop's Phase 2 desktop layer, extracted here so the framework machine can import them.

nixos-core is a **focused library flake**. It owns *system* NixOS modules only. The Home-Manager desktop env
(niri/noctalia/walker) lives in the separate `nix-desktop` repo; the `desktop` module here is the **system**
counterpart that pairs with it (enables `programs.niri`, the display manager, audio). Consumed downstream by
`nix-meta` profiles: `developer` / `gui` (import `desktop` + `input-kanata`) and `gpu-compute`
(imports `nvidia-compute`).

## 1. Current repo shape (READ-ONLY baseline — study before touching)

```
nixos-core/
  flake.nix              # inputs: nixpkgs, nixos-wsl. outputs.nixosModules = { wsl-upstream, common, wsl }
  modules/
    common.nix           # options.nixos-core.common.{enableFlakes,experimentalFeatures,systemPackages}
    wsl.nix              # options.nixos-core.wsl.enable → wsl.enable
  README.md
```

**Established conventions to MATCH (do not invent a new style):**
- Every module is `import ./modules/<name>.nix` and registered under `outputs.nixosModules.<name>` in `flake.nix`.
- Options live under the `nixos-core.<module>` namespace (e.g. `nixos-core.common.*`, `nixos-core.wsl.enable`).
- Modules are `{ config, lib, pkgs, ... }:` with `with lib;`, gating `config` behind an `mkEnableOption` /
  `mkIf` so importing a module is inert until enabled. Follow `modules/common.nix` and `modules/wsl.nix` exactly.

## 2. Work items (TARGET PATHS in this repo)

> All new files go under `modules/`. A flat `modules/<name>.nix` matches the existing layout. Where a module
> needs supporting data files (kanata fragments), use a `modules/<name>/` subdir with a `default.nix` entry
> (mirror the source's `input/kanata/` structure).

### 2a. `modules/nvidia-compute.nix` — headless compute-only NVIDIA  *(Phase 4, the tower-critical one)*

New module, options under `nixos-core.nvidiaCompute`. Gate everything behind `enable = mkEnableOption …`.
This is the slice the tower depends on. It is **compute-only** — explicitly **NO display stack**:

- `hardware.nvidia.open = true;` (RTX 3060 = Ampere GA106, open kernel module supported).
- Production driver (`hardware.nvidia.package = config.boot.kernelPackages.nvidiaPackages.production;`),
  **not** beta/stable-unless-needed — pin per the decision log.
- `hardware.nvidia.modesetting.enable` — set the minimal value for a headless box; the goal is the kernel
  module + KMS only as needed, **never** a Wayland/X compositor path.
- **MUST NOT set `services.xserver.videoDrivers`** (that pulls the display stack). No xserver, no displayManager.
- `hardware.graphics.enable = true;` with CUDA userspace; enable the **NVIDIA container toolkit**
  (`hardware.nvidia-container-toolkit.enable = true;`) so vLLM runs in Docker with `--gpus`.
- CUDA capability **8.6** (Ampere GA106) wherever a cap list is needed.
- Add `nvidia-smi` / CUDA tooling to `environment.systemPackages` as appropriate (e.g. `pkgs.cudaPackages`
  bits, `config.hardware.nvidia.package` provides `nvidia-smi`).
- **Declarative GPU power-limiting** (PLAN §10): a **oneshot systemd service** that runs
  `nvidia-smi -pm 1` then `nvidia-smi -pl <watts>` (target ~70% ≈ 120–130 W). Expose the limit as an option
  (e.g. `nixos-core.nvidiaCompute.powerLimitWatts = mkOption { type = types.nullable types.int; default = null; }`)
  so it's tunable per model and disable-able. **Keep the VRAM/memory clock high — do NOT underclock memory.**
  Run `After = multi-user.target` / after the driver is loaded; `Type = oneshot`, `RemainAfterExit = true`.
- Consider an option to minimize framebuffer-console VRAM (PLAN §10: "zero/minimize fbcon VRAM") — e.g.
  kernel params / disabling `fbcon`. Note it even if you leave the exact mechanism as a TODO.

**No-iGPU caveat (PLAN §11):** the Xeon-W has no integrated graphics. This module must be valid on a box with
*only* NVIDIA cards and *no* display — so do not assume a fallback GPU and do not enable any compositor.

### 2b. `modules/desktop.nix` — system desktop layer  *(laptop / Phase 2 system half)*

New module, options under `nixos-core.desktop`, gated by `enable`. This is the **system** layer that pairs with
the `nix-desktop` HM modules. Port the desktop/audio system config that currently lives in
`~/.dotfiles/configuration.nix` + `~/.dotfiles/modules/nixos/desktop/*`:

- `programs.niri.enable = true;` (from `desktop/niri-session.nix`). The `services.nirinit` block depends on the
  external `nirinit` flake input — see Dependencies (§4); either thread that input through or leave nirinit
  wiring to the consuming profile and note it.
- Display manager + session: `services.xserver.enable`, `services.displayManager.gdm.enable`,
  `services.displayManager.defaultSession = "niri"` (from `configuration.nix:85,95,96`). Decide whether GNOME
  desktop (`services.desktopManager.gnome.enable`, line 97) belongs here or is laptop-policy — keep it
  optional.
- XKB (`services.xserver.xkb`, lines 100–104) and `console.useXkbConfig` (line 156).
- Audio: PipeWire stack — `services.pulseaudio.enable = false;`, `security.rtkit.enable = true;`,
  `services.pipewire = { enable; alsa.enable; alsa.support32Bit; pulse.enable; }` (lines 109–117).
- From `desktop/noctalia-support.nix`: `hardware.bluetooth.enable`, `services.upower.enable`,
  `services.power-profiles-daemon.enable` (laptop-flavored — keep behind an option or a sub-toggle so the tower
  never pulls power-profiles-daemon).
- `services.printing.enable` (CUPS, line 107) — optional sub-toggle.

Make the laptop-only bits (power-profiles-daemon, bluetooth, printing) individually toggle-able so this module
stays composable; the tower must be able to import nothing from here.

### 2c. `modules/input-kanata.nix` (+ `modules/input-kanata/` data) — keyboard remap  *(laptop)*

Port `~/.dotfiles/modules/nixos/input/kanata/` wholesale. That tree is:
`default.nix` (concatenates fragments → `services.kanata.keyboards.main`), `generated-config.nix`, and
`fragments/*.kbd` (100-defsrc, 200-base, 250-homerow-mods, 300-nav, 350-sidebar, 400-resize, 500-leader,
900-safety). Bring the **fragments verbatim**. Wrap the `services.kanata` setup behind
`nixos-core.inputKanata.enable`. Keep the `extraDefCfg` (`process-unmapped-keys yes`, `concurrent-tap-hold
yes`, `chords-v2-min-idle 25`) from the source `default.nix`.

> Naming note: the source dir is `input/kanata`; the PLAN names the module `input-kanata`. Use the flat
> `modules/input-kanata.nix` entry + a `modules/input-kanata/` subdir for fragments, OR keep `modules/input/kanata/`
> and register it as `input-kanata` in the flake. Pick one and be consistent; don't fork the `.kbd` content.

### 2d. Username parameterization  *(Phase 1 — applies repo-wide)*

The downstream `nix-meta` profiles currently hardcode `nixos`; the real user is **`andrew`**. nixos-core must
not bake a username in. Expose a single source of truth and reference it everywhere a user is named:

- Add a `username` option (e.g. `nixos-core.username = mkOption { type = types.str; default = "andrew"; }`),
  most naturally in `modules/common.nix` so every other module can read `config.nixos-core.username`.
- Any module that names a user (`users.users.<name>`, service `user =`/`group =`, syncthing `user`/`dataDir`,
  the `desktop` module if it creates the login user) must reference `config.nixos-core.username` rather than a
  literal. Note: the user-account block in `~/.dotfiles/configuration.nix:173-181` is a candidate to model the
  `desktop`/account wiring on, but decide whether account creation belongs in nixos-core or in `nix-meta`
  machines — flag it if you push it up to the orchestrator.

### 2e. Export in `flake.nix`

Register each new module under `outputs.nixosModules`:
```nix
nixosModules = {
  wsl-upstream = nixos-wsl.nixosModules.default;
  common         = import ./modules/common.nix;
  wsl            = import ./modules/wsl.nix;
  desktop        = import ./modules/desktop.nix;
  nvidia-compute = import ./modules/nvidia-compute.nix;
  input-kanata   = import ./modules/input-kanata.nix;   # or ./modules/input-kanata
};
```
Update `description` (it currently says "WSL only"). Add any new flake `input` you actually need (see §4).

## 3. Source material to port FROM (READ-ONLY — do not modify ~/.dotfiles)

| Target module | Source path(s) |
|---|---|
| `nvidia-compute.nix` | **None to copy** — `~/.dotfiles/configuration.nix` is the Intel/framework laptop and has **no** NVIDIA config. Build this module from the decision log + PLAN §10 (this is the genuinely new module). |
| `desktop.nix` | `~/.dotfiles/modules/nixos/desktop/niri-session.nix`; `~/.dotfiles/modules/nixos/desktop/noctalia-support.nix`; `~/.dotfiles/configuration.nix` lines **85** (xserver), **95–97** (gdm/defaultSession/gnome), **100–104** (xkb), **107** (printing), **109–117** (pulseaudio off + rtkit + pipewire), **156** (console.useXkbConfig). |
| `input-kanata.nix` | `~/.dotfiles/modules/nixos/input/kanata/` — `default.nix`, `generated-config.nix`, `fragments/*.kbd` (all 8 fragments). |
| `username` | `~/.dotfiles/configuration.nix:173-181` (`users.users.andrew` block) + the syncthing `user`/`dataDir`/`configDir` (lines 124–127) as examples of where a literal username is used today. |

## 4. Dependencies / integration

- **Downstream consumers (`nix-meta` profiles):**
  - `profiles.developer` / `profiles.gui` import `nixosModules.{common, desktop, input-kanata}`.
  - `profiles.gpu-compute` (the tower) imports `nixosModules.nvidia-compute` and imports **nothing** from
    `desktop` (no display stack).
- **`desktop` ↔ `nix-desktop` (HM):** this system module is the counterpart to the `nix-desktop` Home-Manager
  modules (niri/noctalia/walker). It provides the *system* enablement (`programs.niri`, display manager, audio);
  the HM repo provides the user config. They must agree on the session name (`niri`).
- **`nirinit` flake input:** `desktop/niri-session.nix` uses `services.nirinit` from
  `inputs.nirinit.nixosModules.nirinit` (see `~/.dotfiles/configuration.nix:14`). If you port the `nirinit`
  block, add `nirinit` as a flake input here (and the consumer must pass it through), OR leave `nirinit` wiring
  to the consuming profile and document that `desktop.nix` only sets `programs.niri.enable`. Prefer the latter
  to keep nixos-core input-light; note the decision.
- **`nvidia-compute` → vLLM:** the container toolkit here is what lets the tower run vLLM in Docker with
  `--gpus` (PLAN §8 Phase 4, §6 CI flow). nixos-core only provides the GPU/toolkit substrate; vLLM service
  definition lives downstream.

## 5. Acceptance criteria

- **`nvidia-compute`:** `nix-meta`'s `tower` config imports `nixosModules.nvidia-compute`, enables it, and
  **builds a headless, CUDA-capable system with no display stack** — `nvidia-smi` present, container toolkit
  available, **no `services.xserver` / `services.displayManager` pulled in**, CUDA cap 8.6, `open = true`,
  production driver. The power-limit oneshot service evaluates (and is a no-op when `powerLimitWatts = null`).
- **`desktop`:** `nix-meta`'s `framework` config imports `nixosModules.desktop`, enables it, and reaches niri +
  PipeWire + display-manager parity with the current `~/.dotfiles` laptop (niri session selectable, audio works).
- **`input-kanata`:** importing + enabling produces a `services.kanata` config byte-identical in behaviour to
  the current `~/.dotfiles` kanata (same fragments, same `extraDefCfg`).
- **`username`:** no module hardcodes `nixos` or `andrew`; everything routes through `config.nixos-core.username`
  (default `andrew`), and a consumer can override it in one place.
- **flake:** `nix flake check` / `nix flake show` succeeds and lists all six `nixosModules`. Importing any new
  module without enabling it is **inert** (no config side effects) — same gating discipline as `common`/`wsl`.

## 6. Repo-relevant open items (PLAN §10 — resolve while implementing `nvidia-compute`)

- [ ] **Headless NVIDIA minimal module set:** confirm the smallest set that gives kernel module + CUDA + KMS
      WITHOUT `services.xserver.videoDrivers`. Validate that nothing transitively pulls an X/Wayland stack.
- [ ] **Minimize fbcon VRAM:** find the cleanest declarative knob (kernel cmdline / fbcon disable) to keep
      framebuffer VRAM use near zero on the headless box. Acceptable to land as a documented option + TODO.
- [ ] **Declarative power-limiting:** oneshot systemd `nvidia-smi -pm 1 -pl <watts>` (~70%), exposed as a
      tunable option, **memory clock left high**. Confirm it survives reboot (RemainAfterExit + proper ordering).

## 7. Guardrails

- **This session implements nixos-core ONLY.** Do not touch `~/.dotfiles`, `nix-meta`, `nix-desktop`, or any
  other repo. Read sources read-only.
- Match the existing module style (`nixos-core.<name>` options, `mkEnableOption`/`mkIf` gating). Keep modules
  inert-until-enabled so the WSL consumers are unaffected.
- Do **not** add `services.xserver.videoDrivers` (or any compositor) to `nvidia-compute`. Headless means headless.
- Bring kanata `.kbd` fragments verbatim; don't rewrite keymaps.
- Do not commit/push or add remotes unless asked. No AI-authorship trailers in commits/docs/comments.
- On genuine ambiguity (e.g. whether the login-user account lives here vs in `nix-meta`, or whether `nirinit`
  becomes a flake input) — note it, pick the lower-coupling option, and continue.

## 8. Suggested order

1. Read the current `flake.nix` + both existing modules to internalize the option/gating style.
2. Add `username` to `common.nix` (smallest, unblocks the others).
3. `input-kanata` (mechanical port, lowest risk) → register + `nix flake show`.
4. `desktop` (port from the two desktop modules + configuration.nix sections) → register.
5. `nvidia-compute` (the new, research-bearing module; §6 open items) → register.
6. `nix flake check`; hand off to `nix-meta` for the Phase 4 tower build.
