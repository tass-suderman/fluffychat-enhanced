# Builds for your devices

The **Build Linux and Android** GitHub Actions workflow runs on every branch
push and can also be started from the Actions tab with **Run workflow**. It uses
the Flutter version in `.tool_versions.yaml`. The two jobs produce:

- `fluffychat-linux-x64`: an optimized Linux application bundle in a tar archive.
- `fluffychat-android-debug`: a universal debug APK for ARM, ARM64 and x64.

Artifacts are retained for 30 days. On GitHub, open **Actions → Build Linux and
Android → a completed run → Artifacts**. Sign in to download them. GitHub wraps
each download in a ZIP; extract that ZIP first. Linux builds target Ubuntu 24.04
and newer compatible distributions, including current Arch Linux. Required
runtime libraries still need to be installed (your existing FluffyChat AUR
installation supplies the usual dependencies).

Linux emoji rendering uses installed **Noto Color Emoji** (`noto-fonts-emoji`
on Arch); explicit VS15 text presentation uses **DejaVu Sans**. These fonts
resolve through Flutter's Linux engine without changing system fontconfig or
bundling another font. Other platforms retain their existing font behavior.

The upstream web/Play Store deployment jobs are restricted to the upstream
repository, so your fork does not need their deployment secrets.

## One-time Android signing setup

Android requires an update to use the same signing key as the installed app.
For your locally built debug APK, reuse the key Flutter generated in
`~/.android/debug.keystore`. Keep a backup of that file. Do not commit it.

If that file does not exist, generate a new reusable debug signing key:

```sh
mkdir -p "$HOME/.android"
umask 077
keytool -genkeypair -keystore "$HOME/.android/debug.keystore" \
  -storetype JKS -alias androiddebugkey -keyalg RSA -keysize 2048 \
  -validity 10000 -storepass android -keypass android \
  -dname 'CN=Android Debug,O=Android,C=US'
```

An APK signed with this new key cannot update an installation signed with a
previous key. Export your encryption keys before uninstalling the old app. Once
installed with the new key, future local and CI builds using it can update normally.

Install the GitHub CLI (`sudo pacman -S github-cli` on Arch), authenticate with
`gh auth login`, then run this from your checkout:

```sh
base64 -w 0 "$HOME/.android/debug.keystore" | gh secret set ANDROID_DEBUG_KEYSTORE_BASE64 --repo tass-suderman/fluffychat-enhanced
```

Alternatively, put the base64-encoded file in a repository Actions secret named
`ANDROID_DEBUG_KEYSTORE_BASE64` under **Settings → Secrets and variables → Actions**.
This workflow uses the standard Android debug alias and passwords. If you used
a different key for your local APK, these instructions need adapting.

Without this secret, CI still builds an APK, but each fresh runner generates a
different signing key. Set the secret before installing CI builds you intend to
update. This is a personal debug build, with debugging enabled; it is not a
Play Store release. It keeps the existing FluffyChat application ID, so an
official app signed with another key cannot be updated by this APK.

## Download from the terminal

From your checkout, list successful builds and select a run ID for the branch
and commit you want:

```sh
gh run list --workflow build-devices.yaml --branch main --status success
gh run download RUN_ID --name fluffychat-linux-x64 --dir /tmp/fluffychat-linux-download
gh run download RUN_ID --name fluffychat-android-debug --dir /tmp/fluffychat-android-download
```

Replace `RUN_ID` with the selected ID. Use fresh download directories for each
update. The CLI extracts the artifact ZIP automatically.

## Install or update Linux

Close FluffyChat first. Install the entire bundle, including `lib` and `data`:

```sh
mkdir -p "$HOME/.local/opt/fluffychat-enhanced"
tar -xzf /tmp/fluffychat-linux-download/fluffychat-linux-x64.tar.gz -C "$HOME/.local/opt/fluffychat-enhanced"
mkdir -p "$HOME/.local/share/applications"
cat > "$HOME/.local/share/applications/fluffychat.desktop" <<EOF
[Desktop Entry]
Name=FluffyChat
Exec="$HOME/.local/opt/fluffychat-enhanced/fluffychat"
Icon=fluffychat
Terminal=false
Type=Application
Categories=Network;Chat;InstantMessaging;
EOF
```

This user launcher overrides the AUR launcher. Repeat the extraction for updates;
your account data is stored separately. Keep the AUR package installed for its
runtime dependencies, or install those dependencies independently.

## Install or update Android

On your phone, download the Android artifact from GitHub, extract its ZIP, and
open `app-debug.apk`. Allow installation from your browser/file manager when
Android asks. With the signing secret configured to your existing local key,
it installs as an update and preserves app data.

Or enable USB debugging, connect your phone and install from your computer:

```sh
adb install -r /tmp/fluffychat-android-download/app-debug.apk
```

If Android reports incompatible signatures, check that CI uses the key from
your installed build. Uninstalling the app deletes local app data; export your
encryption keys before considering that route.
