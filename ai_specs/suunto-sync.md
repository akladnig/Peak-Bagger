# Prompt
How do I develop an app to upload gpx files from macOS to a Suunto Vertical 2? Either as a direct upload to the watch or the Suunto App on an iPhone. Would a custom app need to be developed for direct upload to the watch or app?

# Short Answer
Short answer: you usually do not build a custom watch app. For a Suunto Vertical 2, the normal path is:
1. GPX on Mac
2. Import into Suunto App on iPhone
3. Sync Suunto App to the watch
Suunto’s iPhone app supports GPX import from Files/iCloud/Drive, and Suunto’s docs say routes saved in the app can be synced to the watch.
If you want automation from macOS, then yes, you’d likely need a custom app/integration. But it would not upload “directly to the watch” in the usual consumer sense. It would use Suunto’s Cloud/API/partner program to create or import a route into the user’s Suunto account, then the watch gets it via normal sync.
So:
- Direct-to-watch upload: not a normal public workflow
- Via Suunto App on iPhone: yes, supported manually
- Fully automated Mac app: possible only if you get Suunto partner API access
If you want, I can outline the exact build options:
- simplest manual workflow
- a Mac app that prepares GPX for iPhone import
- a partner/API-based fully automated solution

# Build Options
Proceeding with the practical breakdown:
Best route
- No custom watch app needed for normal use.
- Export GPX on macOS.
- Import it into Suunto App on iPhone.
- Sync the watch.
If you want automation
- Build a Mac helper app/service that:
  - reads GPX files,
  - optionally cleans/converts them,
  - then either:
    - hands them off to the iPhone for import, or
    - uploads them into the user’s Suunto Cloud account via the Suunto Route API.
Direct upload to the watch
- There is no normal public direct-to-watch upload API.
- The supported path is: Suunto Cloud route -> Suunto App sync -> watch.
- So a “direct upload” product would still usually go through Suunto’s cloud and watch sync.
What a custom app would need
- For manual use: nothing special, just a GPX importer/exporter on Mac.
- For automatic upload into Suunto: yes, you’d need a custom app and likely Suunto partner API access.
- For watch-side app: not for GPX upload; SuuntoPlus is for sports-app features during activities, not route ingestion.
Recommended implementation
1. Mac app imports GPX.
2. App authenticates with Suunto.
3. App creates/updates a route in Suunto Cloud.
4. Suunto App syncs it to the Vertical 2.
If you want, I can next sketch:
1. a no-code/manual workflow,
2. a Mac app architecture, or
3. the Suunto API integration flow.

# Sketches
1. No-Code / Manual Workflow
- Export GPX from macOS.
- AirDrop, iCloud Drive, or save to Files on iPhone.
- Open Suunto App on iPhone.
- Import route .gpx in Map view.
- Save route in library.
- Sync Suunto App to the Vertical 2.
- Result: route appears on the watch for navigation.
2. Mac App Architecture
- macOS app watches a folder for new GPX files.
- App validates/parses GPX and optionally normalizes track/route data.
- App either:
- Exports a clean .gpx for iPhone import.
- Or uploads the route into Suunto Cloud via API.
- App stores auth state, route IDs, and sync status.
- Optional companion iPhone app or share extension for handoff.
- Result: mostly automated workflow, but still routed through Suunto App/sync.
3. Suunto API Integration Flow
- User signs into Suunto account and grants access.
- Your app gets OAuth tokens.
- App calls Suunto Route API to create/import a route from GPX.
- Suunto stores the route in the user’s cloud account.
- Suunto App on iPhone syncs the route.
- The Vertical 2 receives it from the synced Suunto App.
- Result: best true automation path, but it needs Suunto partner/developer access.
Bottom line
- For normal use: no custom app needed.
- For automated upload from macOS: yes, you’d need a custom app.
- For direct-to-watch upload: not really public; the supported path is cloud -> Suunto App -> watch.
