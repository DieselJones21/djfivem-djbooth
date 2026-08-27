# Lumina DJ Booth

A premium FiveM DJ booth resource with a bright tablet UI, YouTube playback through [xsound](https://github.com/Xogy/xsound), saved songs, playlists, and in-game placement.

## Features

- **YouTube + direct HTTPS audio** — paste `youtube.com`, `youtu.be`, Shorts, or a direct `.mp3` / stream URL
- **3D positional audio** via xsound, with optional extra speakers per booth
- **Full transport** — play, pause, resume, stop, skip, previous, seek, volume, hearing radius
- **Queue** — add, reorder, play now, clear, shuffle, loop track / loop queue
- **Save songs** to a personal library (persisted on the server)
- **Playlists** — create, add tracks, play the whole set, or dump it into the queue
- **Portable speakers** — handheld, big PA, and tripod as ox_inventory items; place them, change volume/range, make permanent, and group nearby speakers so they play in sync
- **Interact E prompts** using [darktrovx/interact](https://github.com/darktrovx/interact), with ox_target / qb-target / native 3D text fallbacks
- **`/djadmin`** — walk-up placement, job locks, teleport, edit, delete, add speakers
- **`/dj`** — open the nearest booth you can use
- **QBCore, Qbox, ESX, or standalone** — auto-detected
- **Bright tablet UI** — Lumina OS, built to look like a physical iPad-style deck

## Dependencies

| Resource | Required | Notes |
| --- | --- | --- |
| `xsound` | **Yes** | Start it before this resource |
| `interact` | Recommended | E-prompt interaction ([darktrovx/interact](https://github.com/darktrovx/interact)) |
| `ox_target` or `qb-target` | Optional | Used if `interact` is not running |
| `ox_lib` | Optional | Notifications only |
| `ox_inventory` | Recommended | Usable speaker items (`lumina_speaker_*`) |
| `qb-core` / `qbx_core` / `es_extended` | Optional | Job locks, admin groups, usable items |

## Install

1. Drop this folder into `resources` as `djbooth` (or keep the repo name and ensure it matches `server.cfg`).
2. Install and start [xsound](https://github.com/Xogy/xsound).
3. Install [interact](https://github.com/darktrovx/interact) if you want the E prompts.
4. Add to `server.cfg`:

```cfg
ensure xsound
ensure interact
ensure djbooth
```

5. Grant booth admin (for `/djadmin`):

```cfg
add_ace group.admin djbooth.admin allow
```

QBCore `god` / `admin` and ESX `admin` / `superadmin` are also accepted. You can add extra identifiers in `config.lua`.

## Commands

| Command | Who | What |
| --- | --- | --- |
| `/djadmin` | Admins | Opens the placement tablet |
| `/dj` | Anyone with booth access | Opens the nearest booth |
| `/givespeaker handheld\|big\|tripod [id]` | Admins | Gives a speaker item |
| `/placespeaker handheld\|big\|tripod` | Admins | Place a speaker without consuming an item |

Walk up to a placed booth and press **E** (interact prompt) to open the DJ tablet.

## Portable speakers

GTA already has the props. We map them like this:

| Item | Prop | Fallback | Default range |
| --- | --- | --- | --- |
| `lumina_speaker_handheld` | `prop_boombox_01` | `prop_portable_hifi_01` | 12m |
| `lumina_speaker_big` | `prop_speaker_07` | `prop_speaker_03` | 45m |
| `lumina_speaker_tripod` | `ba_prop_battle_club_speaker_small` (After Hours) | `prop_speaker_03` | 28m |

GTA does not have a true camera-tripod PA. The tripod item uses the After Hours club speaker if that DLC is loaded, otherwise the vanilla box speaker.

### ox_inventory setup

1. Copy the three item blocks from `install/ox_inventory/items.lua` into `ox_inventory/data/items.lua`.
2. Copy the PNGs from `install/ox_inventory/web/images/` into `ox_inventory/web/images/`.
3. Restart `ox_inventory` then `djbooth`.

QBCore / ESX usable items are registered automatically if those frameworks are running (you still need to add the items to your items list).

### Using a speaker

1. Use the item from inventory — placement is the same as booths (**E** confirm, **X** cancel, scroll rotate).
2. Walk up and press **E** for the speaker menu.
3. Paste a YouTube link, set volume and range.
4. **Permanent** keeps it through restarts and blocks pickup until you unlock it.
5. **Group** links nearby speakers so they share one track; each speaker still has its own volume and range.

Pickup returns the inventory item (only if it is not permanent).

## Placing a booth

1. Run `/djadmin`
2. Pick a prop model
3. Click **Place booth**
4. Aim at the ground — **scroll** rotates, **arrows** raise/lower, **E** confirms, **X** cancels
5. Name it, optionally lock it to jobs (`nightclub` or `nightclub:2`), set radius / volume
6. Optionally add **speakers** so the room fills from more than one point

Job field examples:

- blank → public booth
- `unemployed` → that job, any grade
- `nightclub:2, vanilla:0` → multiple jobs with minimum grades

## YouTube

xsound plays YouTube through the official iframe player. Some videos block embedding (age gate, copyright, embedding disabled) and will fail silently in xsound — try another link.

Titles are resolved with YouTube oEmbed. To expand full playlist URLs (`list=`), set `Config.YouTubeApiKey` to a [YouTube Data API v3](https://console.cloud.google.com/apis/credentials) key.

Use audio in line with YouTube's terms and your server's content rules.

## Config highlights

See `config.lua` for everything. The important ones:

- `Config.Framework` — `auto`, `qb`, `qbx`, `esx`, `standalone`
- `Config.AdminAce` — default `djbooth.admin`
- `Config.DefaultRadius` / `Config.MaxRadius`
- `Config.Models` — props offered in `/djadmin`
- `Config.Interact` — prompt label and distances
- `Config.MaxQueue`, `Config.MaxSavedSongs`, `Config.MaxPlaylists`

Booths are saved to `data/booths.json`. Personal libraries are saved to `data/library.json`.

## Exports

**Server**

```lua
exports.djbooth:GetBooths()
exports.djbooth:GetBoothState(boothId)
```

**Client**

```lua
exports.djbooth:OpenBooth(boothId)
exports.djbooth:GetBooths()
```

## Notes

- After Hours / Tuners DJ desk models need those DLC packs on the server and clients. `prop_speaker_07` and `prop_boombox_01` are safe vanilla fallbacks.
- Streamer mode in xsound mutes booth audio for that player.
- If interact is missing, the script automatically tries ox_target, then qb-target, then a native `[E] Open DJ Booth` 3D prompt.
