# SnapSort

iOS app that automatically organizes your screenshots by the app they were taken in, using Mistral AI's Pixtral vision model.

## Features

- **Automatic grouping** — every screenshot lands in a folder for the app it was taken from
- **Knows your apps** — show it your Settings → Apps once and it learns which apps you actually have, so classification stays accurate
- **Per-app galleries** — tap a card to see every screenshot from that app
- **Multi-select delete** — sweep through and trash whole groups or individual shots, Photos-app style
- **Light & dark mode** — adapts to your iOS theme
- **Local-only** — your API key and classification cache stay on the device

## Requirements

- iPhone running iOS 17 or later
- Xcode 15+ to build & install
- A Mistral AI API key (free tier works) from [console.mistral.ai](https://console.mistral.ai)

## Install

```bash
git clone https://github.com/<your-username>/SnapSort.git
cd SnapSort
open SnapSort.xcodeproj
```

In Xcode:
1. Select the **SnapSort** target → **Signing & Capabilities** → set your Apple Developer Team.
2. Plug in your iPhone, pick it as the run destination, hit ⌘R.

> The Simulator works for browsing the UI but won't have screenshots in its Photos library — there's nothing to sort there. Run on a real device.

## First launch

1. **Add your API key.** Sign up at [console.mistral.ai](https://console.mistral.ai), create a key, paste it on the welcome screen.
2. **Teach it your apps.** On your iPhone open **Settings → Apps**, screenshot every page, then pick those screenshots in SnapSort's onboarding screen. SnapSort uses them to build a list of apps you actually have installed.
3. **Sort.** Hit the big **Sort** button. SnapSort classifies every screenshot in your library and groups them by app. Results are cached, so re-opening the app is instant.

## Picking a model

Settings → **Vision Model** lets you choose between:

| Model | Notes |
| --- | --- |
| **Pixtral 12B** *(default)* | Fast, free-tier friendly |
| **Pixtral Large** | Most accurate, higher cost per request |
| **Mistral Medium 3** | Balanced quality and speed |
| **Mistral Small 3** | Cheapest paid option |

## How it works

iOS doesn't tag screenshots with the source app, so SnapSort sends each screenshot to Pixtral and asks "which of these installed apps is this from?" — constrained to the list of apps you taught it during setup. Up to 5 requests run in parallel via `TaskGroup`. Classifications are cached locally and indexed by the photo's `PHAsset.localIdentifier`, so each screenshot is only sent to the API once.

When you add or remove an app from the **Apps** menu, SnapSort automatically wipes the cache and re-sorts everything in the background.

## Privacy

- Your API key is stored in `UserDefaults` on the device.
- Screenshots are sent only to Mistral's API for classification, and only when you press Sort or open the app.
- There is no SnapSort backend. Nothing is uploaded anywhere else.

## License

[Add a license here — MIT, Apache-2.0, etc.]
