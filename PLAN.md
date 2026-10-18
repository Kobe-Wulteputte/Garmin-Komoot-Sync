# Komoot Edge Sync

A Connect IQ device app for Garmin Edge bike computers (Edge 540, 550, 830, 840, 850, 1040, 1050) and fēnix watches (fēnix 7, 8 and E families). You start it by hand. It makes the
device hold your latest X Komoot planned tours as courses, and removes the courses it
installed itself once their tour is gone from Komoot.

## Why

Komoot's Garmin Connect courses sync only pushes new tours. It never removes old
ones, so the Edge fills up. It also does not know about courses installed by
Komoot's own Connect IQ app, so tours end up on the device twice.

## Decisions

| Topic | Decision |
|---|---|
| Komoot access | Unofficial API (no partner contract). All calls run on the Edge through the phone or WiFi. No backend. |
| Credentials | Komoot email and password in the app settings (Garmin Connect Mobile). Stored in plain text on phone and device. |
| Login | Every sync: `GET https://api.komoot.de/v006/account/email/{email}/` with Basic `email:password`. The response holds `username` and `password` (a token). Later calls use Basic `username:token`. No token caching. |
| Which tours | Planned tours of the sports switched on in the settings (`type=tour_planned`, `sport_types=` comma-separated), newest first. One boolean setting `sport_<id>` per sport Komoot can plan (13); the 10 cycling ones default on, hike/mountaineering/jogging off. Tracking-only sports (downhillbike, citybike) are left out since they cannot be planned. If none is on, the sync stops. Before 2026-10-18 the list was fixed to cycling. Cycling sports: racebike, e_racebike, touringbicycle, e_touringbicycle, mtb, e_mtb, mtb_easy, e_mtb_easy, mtb_advanced, e_mtb_advanced, downhillbike, citybike. |
| X | App setting, default 30 (was 5 until 2026-10-18), no upper limit (was 20, then 50; limit dropped 2026-10-18). Loading stops early when Komoot has no more tours. Each tour costs one list request through the phone, so large values make syncs slow, and the device course storage can fill up (downloads then fail and are reported as failed). |
| Install | A tour in the latest X is installed unless the app already owns a course for it, or a course on the device matches: its name ends with `" " + tourId` (Komoot app and Komoot FIT downloads), equals the tour name ignoring case (Garmin Connect sync), or is a shortened Komoot name: `<start of the name>... <end of the id>` (at least 3 name characters and 3 digits, and exactly one latest tour matching). |
| Remove | Only courses this app installed. Default: only when Komoot answers `404` for their tour (`GET /v007/tours/{id}`); tours still planned but outside the latest X stay. Setting `keepOnlyLatest` ("Remove routes outside the latest tours", default off, added 2026-10-18): own courses outside the latest X are removed without asking Komoot, unless a latest tour was skipped as too large in this run (then the list is incomplete and the cleanup falls back to the 404 check). Own courses whose tour is among the latest X are never removed. |
| Updates | An own course whose tour is among the latest X is re-downloaded when the tour's `changed_at` differs from the value stored at install (no stored value counts as changed, so courses from before this feature refresh once). Garmin Connect and Komoot-app copies cannot be updated. |
| Ownership tracking | `getAppCourses()` lists the courses this app installed. At install the app stores course id => [tour id, course name] (`ownedCourses`), using the course the FIT callback's iterator returns. A record counts only while the course name still matches (the device reuses course ids); without a record the tour id is read from the end of the name and must have 9+ digits. An own course whose tour is among the latest X always counts as on the device. Download one tour at a time. |
| Failures | A single download fails: skip it, report it. A latest tour too large to load (`-402`/`-403`): skip it, report it. Login fails, or loading the latest tours fails otherwise: stop and change nothing. Any answer other than `404` on a check keeps the course. |
| App type | Device app (`watch-app`). Opens on a menu: **Sync now** (the full sync) and **Refresh a route**. Both show a status line and one card per route (name, length, sport, planned date, coloured state). No background sync in v1. |
| Refresh a route | Lists every planned tour of every sport, newest first, 10 per page with "Load more" (one request per tour, see the -402 finding). Picking one downloads its FIT again; the old course is removed afterwards only if this app owns it. A Garmin Connect or Komoot-app copy cannot be removed, so the app downloads anyway and tells the user to delete the old copy by hand. |
| Tests | The add/remove decision is one pure function with `(:test)` cases. Network and install are checked by hand on the device. |
| One-time manual steps | Turn off the Komoot to Garmin Connect courses sync. Delete existing duplicate courses on the Edge by hand. |

## Sync flow

1. Log in.
2. Load the latest X planned tours with `TourLoader`: pages of 5 (`limit=5&page=p`); a page that is too large (`-402`/`-403`) is loaded one tour per request (`limit=1&page=i`), and a single tour that is still too large is skipped.
3. Read `getCourses()` names, and `getAppCourses()` with the tour id at the end of each name.
4. Decide `toAdd`, `toUpdate` and `toCheck` (pure function `SyncPlan.plan`).
5. For each course in `toCheck`: `GET /v007/tours/{id}`; on `404`, `course.remove()` (before installs, to free space).
6. For each tour in `toUpdate` and `toAdd`: download `/v007/tours/{id}.fit` with `HTTP_RESPONSE_CONTENT_TYPE_FIT`, store the tour's `changed_at` under its id in `Application.Storage` (`installedChanges`). For an update, remove the old course only after the new download succeeded.
7. Show the summary: added, removed, already on device, failed.

## Out of scope for v1

- Background sync.
- Token caching.
- Removing courses that this app did not install.

## Milestones

### Step 1: prove the risky parts

Nothing below is confirmed for the Edge 830 with the unofficial login yet.

- **1a, from the PC:** `spike/komoot-fit-check.ps1`. Does `/v007/tours/{id}.fit` download with the unofficial Basic `username:token` login, and is the result a real FIT file? How big is the tour list JSON?
- **1b, on the real Edge 840 (edge830 build):** the app in this folder, in its spike form. Does `makeWebRequest` with the FIT response type install a course on the Edge 830? What does the callback's `data` hold? Does the `getAppCourses()` diff find the new course? What do existing course names look like? Does the tour list JSON fit in memory?

Fallbacks if FIT fails: GPX through `makeWebRequest` on the device, then a small proxy that converts GPX to FIT.

### Step 2: the full app

Turn the spike into the flow above: pagination, the pure decision function with tests, the ownership map, removal, and the summary screen.

## Findings

- 2026-10-18: The unofficial login works (`/v006/account/email/{email}/` returns `username` and token).
- 2026-10-18: The tour list works with `type=tour_planned&sort_field=date&sort_direction=desc&limit&page`. The response is `_embedded.tours[]` plus `page.{size,totalElements,totalPages,number}`. Tour `id` is a string.
- 2026-10-18: The list is heavy: about 6.8 KB of JSON per tour (map image URLs, `_links`, `summary`, `path`, `segments`). The account has 69 planned tours, so the full list is about 470 KB. The removal check (all planned ids) must page through small pages and keep only the ids.

- 2026-10-18: **FIT download works with the unofficial login.** `/v007/tours/{id}.fit` returned a 12.8 KB FIT course file (file type 6, 596 records); the GPX of the same tour is 81 KB. The FIT course name is `<tour name> <tour id>` (`Tot Bosbeke 3100000001`): the "number at the end" seen on Komoot app courses is the tour id.
- 2026-10-18: Edge 830 (`compiler.json`, SDK 9.2.0): API 3.3, 246x322 screen. Memory: watchApp 1 MB, widget 1 MB, datafield 128 KB, background 32 KB. 32 KB rules out parsing the tour list in a background service, so background sync is not an option without a slimmer source.
- 2026-10-18: The spike app builds for `edge830` (`BUILD SUCCESSFUL`).
- 2026-10-18, simulator (edge830): login, the 5-tour list (free memory still ~946 KB after parsing) and the FIT install all work. The callback's `data` iterator returns the new course, and `getAppCourses()` shows it. Course names are cut to 16 characters (`Tot Bosbeke 3352`, `Sporen in Lokere`), so the tour id suffix is not usable for matching. Course ids are small numbers (0, 1, 2). A second run marked both installed tours as "on device".

- 2026-10-18, real Edge 840 (edge830 build): `getCourses()` lists all 26 courses with full names. **Names are not cut to 16 characters on the device**; that was a simulator artifact. Komoot app courses are `<tour name> <tour id>`, and long names are shortened to `<start of name> ... <tour id>` (`To Vierzele Village ... 3100000002`). Garmin Connect courses carry the bare tour name (`To Vierzele Village Climb`). Duplicates are visible (`Sporen in Lokeren` twice, `To Vierzele Village ... 3100000002` twice). Course ids are up to 239.
- 2026-10-18, real Edge 840 (edge830 build) (login built in via `spike/build-with-login.ps1`): login and the 5-tour list work through the phone; free memory ~945 KB after parsing. With the id-suffix-or-exact-name rule all 5 latest tours were correctly found on the device ("Nothing to install").
- 2026-10-18, real Edge 840 (edge830 build): **FIT install works.** After deleting Thx Ignaas on the device, the app saw it missing, downloaded the FIT (`200`), and the callback iterator plus `getAppCourses()` both returned `Thx Ignaas 3100000003 #162`. Course id 162 had belonged to a different (deleted) course earlier, so **course ids are reused**. Since every app-installed course name ends with its Komoot tour id, the app reads ownership from `getAppCourses()` names and needs no stored map.
- 2026-10-18, simulator: loading all planned tours does not fit. `limit=10` failed with `-403` (out of memory); `limit=5` failed on page 5 with `-402` (response too large). Older tours carry much more route data. Hence one tour per request and a per-course existence check instead of the full list.
- 2026-10-18, simulator: the full app (`Sync.mc`) logs in, loads the latest 5 one by one and installs them; 3 `SyncPlan` unit tests pass. Because the simulator cuts names to 16 characters, the simulator re-installs every run and cannot test removal; use the real device.
- 2026-10-18, simulator: Komoot honours a comma-separated `sport_types` filter (a probe with `hike,jogging` returned only hike tours; the cycling list returns only racebike for this account).
- 2026-10-18, simulator: `GET /v007/tours/{id}` for a non-existent id answers `404`, so the removal path works. Course ids parsed from names now need 6+ digits, after a simulator-cut name (`Gourmand Route 2`) parsed as tour id 2.
- 2026-10-18, real Edge 840 (edge830 build), full app: run 1 loaded the latest 5 cycling tours (incl. a new "To delete route"), added all 5 (none were on the device at that point), `Added 5, removed 0, already on device 0, failed 0`. After deleting "To delete route" in Komoot, run 2: `Checking 1 older own courses`, `Removed To delete route 3100000004` (Komoot answered 404 for the deleted tour), re-added Thx Ignaas which moved back into the latest 5: `Added 1, removed 1, already on device 4, failed 0`. **Install, skip, check and remove all work on the device.**
- 2026-10-18, real Edge 840 (edge830 build): the `.SET` file copied from the simulator to `Garmin\Apps\Settings` was not picked up; the app saw empty settings.

- 2026-10-18: **All "real Edge" tests above actually ran on an Edge 840** (the owner has an 840; the edge830 build ran on it unchanged). Support widened to Edge 540, 550, 830, 840, 850, 1040, 1050. From the SDK device files: 540/840 are 246x322, 1040 is 282x470, 550/850 are 420x600, 1050 is 480x800; all give a device app 1 MB and run Connect IQ 6.0. The 540 and 550 have no touchscreen, so the app tells them to press enter instead of tap.
- 2026-10-18: fēnix 7 and up added (fenix7, 7pro, 7pronowifi, 7s, 7spro, 7x, 7xpro, 7xpronowifi, 843mm, 847mm, 8pro47mm, 8solar47mm, 8solar51mm, fenixe). Their SDK device files have `getAppCourses` and `HTTP_RESPONSE_CONTENT_TYPE_FIT`, 768 KB for a device app, round 240–454 px screens, all touch. All 21 products build; fenix7 and fenix847mm start in the simulator. Round screens draw the log centred with a sixth of the height as top and bottom margin.
- 2026-10-18, simulator (fenix847mm): long log lines were cut at the round edges. The view now wraps every line with `Graphics.fitTextToArea` to 70% of the width on round screens (the circle is ~74% wide at the band edges) and to the full width on Edges; confirmed visually by the owner in the simulator.
- 2026-10-18: Glance added (`KomootGlanceView`, `(:glance)`; 64 KB on every supported device except the Edge 830, which has no glances). It shows the name and the last sync (`lastSync` in Storage: time and number of latest routes on the device). The device draws the launcher icon beside the glance itself, so the glance draws text only. The app class is loaded in glance mode too, so it creates the Komoot client in `getInitialView`, not as a field. Launcher icon redrawn as a green disc with a white route (68x68, scaled down per device).
- 2026-10-18, owner report on the Edge 840: routes with long names were removed and downloaded again on every sync. Likely cause: the device stores a shorter course name than Komoot's `<name> <tour id>`, cutting the id, so the app neither matched its own course (re-download) nor read the right id (a cut-off number answered 404, so the course was removed). Fixed with the `ownedCourses` record and the 9-digit minimum. Courses installed before the fix have no record; a cut one may be downloaded one last time, after which it is recorded. Not yet confirmed on the device.
- 2026-10-18, real Edge 840: the glance title was invisible (white on the Edge's light glance background) and the Edge, unlike fenix and the simulator, draws no launcher icon beside a glance. On non-round devices the glance now draws the route icon itself and uses black text unless `isNightModeEnabled`; confirmed by the owner on the Edge 840. The sync there showed `18 OCT 12:30 · 56 routes`, and a course with a 9-digit tour id matches the 9-digit minimum.
- 2026-10-18, real Edge 840: the menu (system Menu2) follows the Edge's light theme, but the route screens were always dark. `Theme.isLight()` (non-round device with night mode off) now drives the route screens and the glance: white background, light grey cards, dark text and darker status colours; fenix stays dark. Confirmed by the owner on the Edge 840.
- 2026-10-18: loading switched from one tour per request to pages of 5 with a one-by-one fallback, to cut round trips about five-fold (the JSON per tour stays ~7 KB, so the gain depends on whether the phone link is limited by round trips or by bytes). The sync status shows the total time (`Up to date in 14 s`) to compare. Not yet measured on the device.
- 2026-10-18, owner report on a fenix: the same long-named route was saved again on every sync, piling up copies. The fenix shows Komoot's course name cut in the middle, id included (`<start>... <last 7 digits of the id>`), so neither the full-id suffix nor the 9-digit name parse matched, and the install record was evidently not written (the FIT callback's iterator likely returns no course there). Fixes: shortened names are matched against the latest tours (name start + id ending); the new course is found by comparing `getAppCourses()` before and after the download when the callback gives none; extra own courses for the same tour are removed as duplicates on every sync. Shortened names can only be matched to tours among the latest X, so duplicates of older or switched-off-sport tours stay until removed by hand. Confirmed by the owner on the fenix: duplicates removed, no new copies on the next sync.

## Open facts

- Whether Komoot bumps `changed_at` when a route is edited (the update feature depends on it; not yet tested on the device).

- Maximum number of courses on the Edge 840.
- The Edge 540, 550, 830, 850, 1040 and 1050 and all fēnix builds have not run on a real device.
- Whether Komoot's tour list can be trimmed to fewer fields, if it runs out of memory.
