Prompt for an AI coding agent (or a checklist for a human) to build and run ArmorPaint on Linux x64. Verified on Ubuntu 24.04 with clang 18, in a headless container with no GPU.

The same steps are automated by `build_linux.sh` in the repository root (`./build_linux.sh --deps --test`), which also packages `dist/ArmorPaint-linux-x64-<version>.tar.gz`. The `Linux Build` workflow runs it on every push and uploads that tarball as a downloadable artifact.

---

**Task: Build ArmorPaint from this repository for Linux x64 and prove the binary runs.**

Work from the repository root (the directory containing `base/` and `paint/`). Do not edit tracked source files. The build output goes to `paint/build/`, which is gitignored.

1. **Install build dependencies** (Debian/Ubuntu; prefix with `sudo` if not root):
   ```bash
   apt-get update
   DEBIAN_FRONTEND=noninteractive apt-get install -y make clang libvulkan-dev libgtk-3-dev libssl-dev libxi-dev libxrandr-dev libxcursor-dev libasound2-dev
   ```
   For Arch: `pacman -S make clang vulkan-devel gtk3 openssl libxi libxrandr libxcursor alsa-lib`.
   Warnings from unrelated PPAs during `apt-get update` are harmless if the install succeeds.

2. **Compile:**
   ```bash
   cd paint
   ../base/make --compile
   ```
   `base/make` runs the prebuilt `base/tools/bin/linux_x64/amake` (`linux_arm64` on aarch64). Running it without flags only generates `paint/build/Release/makefile`, shaders and assets. `--compile` also runs `make -j<cores>` with clang (`-O2`, Vulkan backend) and takes about 20 seconds on 4 cores. Use `--debug` for a debug build, or `--run` to compile and launch in one step on a desktop.
   Expected result: `paint/build/out/ArmorPaint` (about 3 MB) next to `paint/build/out/data/`. Run `ldd paint/build/out/ArmorPaint | grep "not found"` and confirm it prints nothing.

3. **Run.** The binary must be started from `paint/build/out/` so it can find `data/`.
   - **On a desktop with a Vulkan-capable GPU driver:**
     ```bash
     cd paint/build/out && ./ArmorPaint
     ```
   - **Headless (CI, containers, SSH, no GPU):** install a virtual X server and Mesa's software Vulkan driver (lavapipe):
     ```bash
     DEBIAN_FRONTEND=noninteractive apt-get install -y xvfb mesa-vulkan-drivers
     cd paint/build/out
     timeout 30 xvfb-run -a -s "-screen 0 1920x1080x24" ./ArmorPaint; echo "exit=$?"
     ```
     No environment variables are needed, because the Vulkan loader finds lavapipe automatically. To force it anyway, set `VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.json`.

4. **Verify it runs:**
   - **Exit code:** exit code `124` means the app stayed alive until `timeout` killed it, which is a pass. Any other code means it crashed or exited early, and that is a failure. The app normally prints nothing to stdout or stderr.
   - **Optional visual check:** install `imagemagick`, then run:
     ```bash
     Xvfb :99 -screen 0 1920x1080x24 & XVFB=$!
     (cd paint/build/out && DISPLAY=:99 ./ArmorPaint) & APP=$!
     sleep 20
     DISPLAY=:99 import -window root armorpaint.png
     kill $APP $XVFB
     ```
     The screenshot should show the ArmorPaint UI: a menu bar (File, Edit, Viewport, ...), a grey cube in the 3D view, and the Layers and Materials panels.

5. **Report:** the commands you ran, any errors and how you fixed them, the binary path, the exit code from step 4, and whether the screenshot shows the UI.
