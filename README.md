# SnapSort

iOS app that automatically organizes your screenshots by the app they were taken in. Pick your AI: **Mistral AI** (cloud) or your own **Ollama** server running locally (no API key, no cloud).

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
- One of:
  - A Mistral AI API key (free tier works) from [console.mistral.ai](https://console.mistral.ai), **or**
  - A computer on the same Wi-Fi running [Ollama](https://ollama.com) with a vision model (`llama3.2-vision`, `llava`, `moondream`, etc.)

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

1. **Pick a backend** on the welcome screen — Mistral AI or Ollama. See setup below.
2. **Teach it your apps.** On your iPhone open **Settings → Apps**, screenshot every page, then pick those screenshots in SnapSort's onboarding screen. SnapSort uses them to build a list of apps you actually have installed.
3. **Sort.** Hit the big **Sort** button. SnapSort classifies every screenshot in your library and groups them by app. Results are cached, so re-opening the app is instant.

## Backend setup

### Mistral AI (cloud)

Sign up at [console.mistral.ai](https://console.mistral.ai), create a key, paste it on the welcome screen. Pick a model:

| Model | Notes |
| --- | --- |
| **Pixtral 12B** *(default)* | Fast, free-tier friendly |
| **Pixtral Large** | Most accurate, higher cost per request |
| **Mistral Medium 3** | Balanced quality and speed |
| **Mistral Small 3** | Cheapest paid option |

### Ollama (local, no API key)

Run the model on your own computer; the iPhone calls it over Wi-Fi. Nothing leaves your network.

On your computer:

```bash
# 1. Install Ollama from https://ollama.com (or `brew install ollama`)
# 2. Pull a vision model:
ollama pull llama3.2-vision

# 3. Start Ollama bound to your LAN (so the iPhone can reach it):
OLLAMA_HOST=0.0.0.0 ollama serve

# 4. Find your computer's LAN IP:
ipconfig getifaddr en0       # macOS, Wi-Fi
```

In SnapSort settings:

- Pick the **Ollama** backend.
- Set the server URL to `http://<your-mac-ip>:11434` (e.g. `http://192.168.1.50:11434`).
- Pick a model from the dropdown (or type a custom tag like `llava:13b`).
- Hit **Test connection** — you should see the number of installed models.

The phone and computer must be on the same Wi-Fi. Inference is slower than the cloud (a few seconds per screenshot) but free and private.

## How it works

iOS doesn't tag screenshots with the source app, so SnapSort sends each screenshot to a vision model and asks "which of these installed apps is this from?" — constrained to the list of apps you taught it during setup. Up to 5 requests run in parallel via `TaskGroup`. Classifications are cached locally and indexed by the photo's `PHAsset.localIdentifier`, so each screenshot is only sent to the model once.

When you add or remove an app from the **Apps** menu, SnapSort automatically wipes the cache and re-sorts everything in the background.

## Privacy

- Your API key (Mistral) or server URL (Ollama) is stored in `UserDefaults` on the device.
- With **Mistral**, screenshots go only to Mistral's API for classification, only when you press Sort or open the app.
- With **Ollama**, screenshots go only to your own computer over your local Wi-Fi — they never leave your network.
- There is no SnapSort backend. Nothing is uploaded anywhere else.
