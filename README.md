# Garmin Komoot Sync

A Connect IQ app for the Garmin Edge 830 that keeps your latest Komoot cycling routes on the device.

Start it on the Edge and it:

- installs your latest X planned Komoot **cycling** tours as courses (X is a setting, default 5, maximum 20),
- skips tours that are already on the Edge from any source (Garmin Connect sync, Komoot's own Connect IQ app, or this app),
- downloads a tour again when you edited it in Komoot,
- removes the courses it installed itself once you delete their tour in Komoot.

It never touches courses it did not install.

> **Warning.** Komoot has no public API for individuals. This app signs in with your Komoot email and password through the same unofficial API that community tools use. That is against Komoot's terms and can stop working at any time. Your password is stored in plain text in the app settings on your phone and on the Edge. Use it at your own risk.

## Before you start

1. **Turn off Komoot's Garmin courses sync**, or it keeps adding copies this app cannot remove: komoot.com → Profile → Settings → Connected accounts → Garmin → switch off course sync.
2. **Delete old duplicate courses on the Edge** by hand once (Courses → course → Delete).
3. Keep your phone near the Edge with the Garmin Connect app running when you sync, or set up WiFi on the Edge. The Edge reaches Komoot through the phone or WiFi.

## Install as a private beta

A beta app is only visible to you and is not reviewed by Garmin. Unlike an app copied over USB, it gets its settings from the Garmin Connect app, so you can enter your Komoot login there.

These steps come from Garmin's docs and the Connect IQ developer forum; Garmin changes its dashboard now and then, so the screens may look slightly different.

### 1. Developer setup (once)

1. Install Java, the [Connect IQ SDK Manager](https://developer.garmin.com/connect-iq/sdk/) (download the latest SDK and the **Edge 830** device) and the **Monkey C** extension in VS Code.
2. In VS Code, run **Monkey C: Generate a Developer Key** and point the extension at it. Keep the key safe and outside git: you need the same key for every future upload of this app.
3. Sign in at [apps.garmin.com/developer](https://apps.garmin.com/developer) with your Garmin account and accept the developer agreement.

### 2. Build the package

In VS Code, open this folder and run **Monkey C: Export Project**, then click **Finish**. Or from a terminal:

```powershell
java -jar "$env:APPDATA\Garmin\ConnectIQ\Sdks\<sdk folder>\bin\monkeybrains.jar" -e -f monkey.jungle -o bin\komoot-edge-sync.iq -y <path to developer_key> -r
```

This creates `bin\komoot-edge-sync.iq`. Never upload a build made with `spike/build-with-login.ps1`; that one contains your password.

### 3. Upload it as a beta

1. Go to [apps.garmin.com/developer/upload](https://apps.garmin.com/developer/upload).
2. Choose `bin\komoot-edge-sync.iq` and tick **Beta app**.
3. Fill in a title and a short description (only you will see them) and submit.

### 4. Install it on the Edge

1. If you copied the app to the Edge over USB before, delete `Garmin\Apps\KOMOOT-EDGE-SYNC.PRG` first; the beta has the same app id.
2. On your phone, open the developer dashboard at [apps.garmin.com/developer/dashboard](https://apps.garmin.com/developer/dashboard) and tap the app. The link opens its store page in the Connect IQ app; tap **Install**.
3. Sync the Edge with the Garmin Connect app. The app appears in the Edge's Connect IQ menu.

### 5. Enter your Komoot login

In the Garmin Connect app (or the Connect IQ app): your Edge → Connect IQ apps → **Komoot Sync** → Settings. Fill in your Komoot email, password and the number of latest tours, then save and sync the Edge.

### Updating the beta

Build a new `.iq` with the same developer key, open the app in the developer dashboard, choose **Upload new version**, and keep it marked as beta. The Edge picks up the new version on its next sync.

## Use

Open **Komoot Sync** from the Connect IQ menu on the Edge. It syncs right away and shows a log, ending with a summary:

```
Added 1, updated 0, removed 1, already on device 4, failed 0
```

Tap the screen to sync again. Swipe up and down to scroll the log.

## How it decides

- **Which tours:** planned tours (not recorded rides) in any Komoot cycling sport, newest first.
- **Already on the device:** a course whose name ends with the tour id (Komoot names its courses `<tour name> <tour id>`), or whose name equals the tour name (Garmin Connect copies).
- **Updated:** the app remembers each tour's Komoot `changed_at` when it installs it; if Komoot reports a newer one, it downloads the tour again and only then deletes the old course.
- **Removed:** only courses this app installed, and only when Komoot answers "not found" for their tour. Tours that are still planned but no longer among the latest X stay on the Edge.

[PLAN.md](PLAN.md) holds the design decisions and the test findings from a real Edge 830.

## Development

Build for the Edge 830:

```powershell
java -jar "<sdk>\bin\monkeybrains.jar" -f monkey.jungle -d edge830 -o bin\komoot-edge-sync.prg -y <developer_key>
```

Run the unit tests (simulator must be running):

```powershell
java -jar "<sdk>\bin\monkeybrains.jar" -f monkey.jungle -d edge830 -o bin\test.prg -y <developer_key> -t
& "<sdk>\bin\monkeydo.bat" bin\test.prg edge830 /t
```

In VS Code, press **F5** to run the app in the simulator; set the login under File → Edit Application.Properties.

**Sideloading for quick tests.** Apps copied over USB get no settings from Garmin Connect. `spike/build-with-login.ps1` asks for your login and builds `Desktop\edge-sync\KOMOOT-EDGE-SYNC.PRG` with it built in; copy that to `Garmin\Apps` on the Edge. The login only ends up in that file, so delete it when you are done.

`spike/komoot-fit-check.ps1` checks the Komoot login and FIT download from a PC.

## Limitations

- Edge 830 only for now (other devices need their product id in `manifest.xml` and support for `PersistedContent.getCourses()`).
- Courses keep the Komoot tour id at the end of their name.
- No background sync: Komoot sends about 7 KB of data per tour, more than a background task may use.
