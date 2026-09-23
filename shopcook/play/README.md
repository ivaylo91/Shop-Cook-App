# Play Store assets

Built by `store_art.py` from the app's own brand files
(`assets/brand/icon.png`, `assets/brand/icon_foreground.png`) and its own
font (Figtree), so the listing matches the app.

| File | Where it goes | Play's requirement |
|---|---|---|
| `icon-512.png` | Store listing -> App icon | 512x512, PNG, opaque, max 1 MB |
| `feature-1024.png` | Store listing -> Feature graphic | 1024x500, PNG or JPEG, no transparency |

The icon is the launcher artwork flattened onto the brand green: Play
applies its own rounding and shadow, so the file must be a full square
with no transparency.

`screenshots/` holds six phone screenshots (1080x1920, 9:16), built by
`screenshots.py` from emulator captures of a demo account: a caption on the
brand ground above each capture. Play wants at least 2 and takes up to 8.

`screenshots-tablet/` holds four at 1440x2560 (9:16), which satisfies both
Play's 7-inch slot (320-3840 px a side) and its 10-inch one (1080-7680),
captured with the emulator's display set to 1600x2560.

Both sets were taken on a throwaway account with demo data ("Weekly shop",
"Chicken curry", BBC Good Food's easy chicken curry), which was deleted
afterwards, so no real person's data is in them.
