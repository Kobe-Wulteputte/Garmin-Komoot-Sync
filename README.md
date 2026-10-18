# Garmin Komoot Sync

A Connect IQ app for Garmin Edge bike computers and fēnix watches that keeps your latest Komoot routes on the device.

**Devices:** Edge 540, 550, 830, 840, 850, 1040, 1050; fēnix 7, 7S, 7X (also Pro and Pro Solar), fēnix 8 (43/47/51 mm, Pro, Solar) and fēnix E. Variants that share a fēnix build (quatix, tactix, Enduro 2) get the app too.

Start it on the Edge and it:

- installs your latest X planned Komoot tours of the sports you choose as courses (X is a setting, default 5, no upper limit; all cycling sports are on by default),
- skips tours that are already on the Edge from any source (Garmin Connect sync, Komoot's own Connect IQ app, or this app),
- downloads a tour again when you edited it in Komoot,
- removes the courses it installed itself once you delete their tour in Komoot, or, with **Remove routes outside the latest tours** switched on, as soon as they drop out of your latest X.

It never touches courses it did not install.

## Why not Komoot's own options?

Komoot gets routes onto a Garmin in two ways: its own Connect IQ app, and the course sync through Garmin Connect. Both leave gaps that this app fills.

| | Komoot Connect IQ app | Komoot → Garmin Connect sync | This app |
|---|---|---|---|
| Several routes at once | No, one route at a time | Yes, in the background | Yes: one tap syncs the latest X |
| Removes routes you deleted in Komoot | No | No, the device keeps filling up | Yes, its own courses |
| Knows what is already on the device | No | No | Yes, from any source |
| Duplicates when you use both | Yes | Yes | No new ones |
| Picks up edits to a route | Download it again by hand | Unclear | Yes |
| Only the sports you want on the device | Pick by hand | No, every planned tour | Yes, a switch per sport |
| You control how many routes | By hand | No | Yes, any number of latest |

**Much faster for several routes.** With the Komoot Connect IQ app you open, download and wait for each route separately. This app fetches all missing routes in one run: start it, and the latest X are on the device a moment later.

**A clean device.** The Garmin Connect sync only ever adds courses, so the course list grows until the device is full and you clean it up by hand. This app removes the courses it installed as soon as you delete their tour in Komoot.

**No duplicates.** Neither Komoot option knows what the other already put on the device, so the same route ends up there twice. This app checks every course on the device first, whatever installed it.

**Edits arrive.** Change a route in Komoot and the next sync replaces the course with the new version.

**Only what you ride.** Planned a hike or a run? With the sport switches, those stay off your bike computer.

> **Warning.** Komoot has no public API for individuals. This app signs in with your Komoot email and password through the same unofficial API that community tools use. That is against Komoot's terms and can stop working at any time. Your password is stored in plain text in the app settings on your phone and on the Edge. Use it at your own risk.

## Before you start

1. **Turn off Komoot's Garmin courses sync**, or it keeps adding copies this app cannot remove: komoot.com → Profile → Settings → Connected accounts → Garmin → switch off course sync.
2. **Delete old duplicate courses on the Edge** by hand once (Courses → course → Delete).
3. Keep your phone near the Edge with the Garmin Connect app running when you sync, or set up WiFi on the Edge. The Edge reaches Komoot through the phone or WiFi.

## Install as a private beta

A beta app is only visible to you and is not reviewed by Garmin. Unlike an app copied over USB, it gets its settings from the Garmin Connect app, so you can enter your Komoot login there.

These steps come from Garmin's docs and the Connect IQ developer forum; Garmin changes its dashboard now and then, so the screens may look slightly different.

### 1. Developer account (once)

Sign in at [apps.garmin.com/developer](https://apps.garmin.com/developer) with your Garmin account and accept the developer agreement.

### 2. Get the package

**Option A: download the release.** Download the `.iq` file from the [latest release](https://github.com/Kobe-Wulteputte/Garmin-Komoot-Sync/releases/latest). It covers every supported Edge and contains no login. No SDK or build tools needed.

The release is signed with the author's developer key and carries the author's app id. If the upload in step 3 is refused because the app already exists, use option B.

**Option B: build it yourself.**

1. Install Java, the [Connect IQ SDK Manager](https://developer.garmin.com/connect-iq/sdk/) (download the latest SDK and the devices you want to build for, for example **Edge 840**) and the **Monkey C** extension in VS Code.
2. In VS Code, run **Monkey C: Generate a Developer Key** and point the extension at it. Keep the key safe and outside git: you need the same key for every future upload of this app.
3. To publish under your own account, give the app its own id: replace the `id` in `manifest.xml` with a new 32-character hex value (for example from `[guid]::NewGuid().ToString("N")` in PowerShell).
4. In VS Code, open this folder and run **Monkey C: Export Project**, then click **Finish**. Or from a terminal:

```powershell
java -jar "$env:APPDATA\Garmin\ConnectIQ\Sdks\<sdk folder>\bin\monkeybrains.jar" -e -f monkey.jungle -o bin\komoot-edge-sync.iq -y <path to developer_key> -r
```

This creates `bin\komoot-edge-sync.iq`. Never upload a build made with `spike/build-with-login.ps1`; that one contains your password.

### 3. Upload it as a beta

1. Go to [apps.garmin.com/developer/upload](https://apps.garmin.com/developer/upload).
2. Choose the `.iq` file from step 2 and tick **Beta app**.
3. Fill in a title and a short description (only you will see them) and submit.

### 4. Install it on the Edge

1. If you copied the app to the Edge over USB before, delete `Garmin\Apps\KOMOOT-EDGE-SYNC.PRG` first; the beta has the same app id.
2. On your phone, open the developer dashboard at [apps.garmin.com/developer/dashboard](https://apps.garmin.com/developer/dashboard) and tap the app. The link opens its store page in the Connect IQ app; tap **Install**.
3. Sync the Edge with the Garmin Connect app. The app appears in the Edge's Connect IQ menu.

### 5. Enter your Komoot login

In the Garmin Connect app (or the Connect IQ app): your Edge → Connect IQ apps → **Komoot Sync** → Settings. Fill in your Komoot email, password and the number of latest tours, switch on the sports you want synced, choose whether to remove routes outside the latest tours, then save and sync the Edge.

### Updating the beta

Download the `.iq` from a newer release (option A) or build a new one with the same developer key (option B), open the app in the developer dashboard, choose **Upload new version**, and keep it marked as beta. The Edge picks up the new version on its next sync.

## Use

Open **Komoot Sync** from the Connect IQ menu. It starts with a menu:

- **Sync now** runs the full sync. The screen shows a status line ("Loading route 3 of 5", "Downloading 1 of 2", then "Up to date") and a card per route with its name, length, sport, planned date and a coloured status: Added, Updated, On device, Removed or Failed. A summary line follows at the end, for example `1 added · 0 updated · 1 removed · 4 kept`.
- **Refresh a route** lists all your planned routes of every sport, newest first, with length, sport and date, ten at a time with **Load more** at the bottom. Pick one and the app downloads it again. If this app installed the old copy, it removes it once the new one is in; a copy from Garmin Connect or the Komoot app cannot be removed and the screen tells you to delete it by hand.

Swipe up and down (or use the up and down buttons) to scroll through the cards. Back returns to the menu.

## How it decides

- **Which tours:** planned tours (not recorded rides) of the sports switched on in the settings, newest first. There is a switch for every sport Komoot can plan: road, gravel, bike touring, mountain biking and enduro (each also as e-bike), hiking, mountaineering and running. The cycling sports are on by default.
- **Already on the device:** a course whose name ends with the tour id (Komoot names its courses `<tour name> <tour id>`), or whose name equals the tour name (Garmin Connect copies).
- **Updated:** the app remembers each tour's Komoot `changed_at` when it installs it; if Komoot reports a newer one, it downloads the tour again and only then deletes the old course.
- **Removed:** only courses this app installed. By default only when Komoot answers "not found" for their tour, so tours that are still planned but no longer among the latest X stay on the Edge. Switch on **Remove routes outside the latest tours** to keep exactly your latest X (of the chosen sports) instead; that also removes this app's routes of sports you switched off. If a tour in the latest X could not be loaded, the sync skips this cleanup to be safe.

[PLAN.md](PLAN.md) holds the design decisions and the test findings from a real Edge 840.

## Development

Build for one device (here the Edge 840):

```powershell
java -jar "<sdk>\bin\monkeybrains.jar" -f monkey.jungle -d edge840 -o bin\komoot-edge-sync.prg -y <developer_key>
```

Run the unit tests (simulator must be running):

```powershell
java -jar "<sdk>\bin\monkeybrains.jar" -f monkey.jungle -d edge840 -o bin\test.prg -y <developer_key> -t
& "<sdk>\bin\monkeydo.bat" bin\test.prg edge840 /t
```

In VS Code, press **F5** to run the app in the simulator; set the login under File → Edit Application.Properties.

**Sideloading for quick tests.** Apps copied over USB get no settings from Garmin Connect. `spike/build-with-login.ps1` asks for your login and builds (for the Edge 840; pass `-Device edge1040` and so on for another model) `Desktop\edge-sync\KOMOOT-EDGE-SYNC.PRG` with it built in; copy that to `Garmin\Apps` on the Edge. The login only ends up in that file, so delete it when you are done.

`spike/komoot-fit-check.ps1` checks the Komoot login and FIT download from a PC.

## Limitations

- Tested on a real Edge 840 only. The other Edge models and the fēnix watches build, start in the simulator and use the same APIs, but have not been tried on a device. On round fēnix screens the log is centred in the middle band and wrapped to fit. Adding another device needs its product id in `manifest.xml` and support for `PersistedContent.getCourses()`.
- Courses keep the Komoot tour id at the end of their name.
- No background sync: Komoot sends about 7 KB of data per tour, more than a background task may use.
