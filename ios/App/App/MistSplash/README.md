# Mist glass opening screen

This is the approved `alcove-living-water` artwork running locally in WKWebView,
not a SwiftUI redraw. `SplashView.swift` owns the view and accepts only a main-frame
`alcoveSplash` message containing `enter` (or `failed` for the manual fallback).
There is no automatic dismissal or external navigation. All assets are bundled.

- `quotes.js`: the seven supplied passages, including original punctuation and line breaks.
- `splash.js`: the same wipe mask, regrowing mist, height-field hand wake and at most
  two ambient ripple sources. Full-screen aspect correction keeps the ripples round.
  The hand impulse radius is 3.2 cells, down slightly from the approved 3.4;
  rain strength and wipe width are unchanged.
- `splash.css`: both the upper-left English and Enter are 10px. Enter retains the
  Pinyon script face and a 62 × 48px touch target above the bottom safe area.
- `mist.webp`: the approved photographic texture. `MistLaunch.imageset` uses the
  same source for the iOS launch screen and the brief period before WebKit loads.
- `serif.ttf`: Noto Serif SC Light, downloaded as a public full font and subset
  **locally** with fontTools to cover every supplied character. The subset is named
  Alcove Mist Serif Light. Do not send quote text to remote font-subsetting APIs.
- `script.ttf`: Pinyon Script subset for Alcove / Enter. Both font licenses are included.

When quotes change, regenerate the serif subset locally and check its cmap for every
non-whitespace character. This screen does not use or change the app's default fonts.

The native wrapper forwards window safe-area insets and scene activity. Rendering pauses
when inactive and stops when dismissed. Rotation reloads the artwork at the new aspect
ratio without ever automatically entering chat. Compact layouts use two text columns.

The SwiftUI root and its existing chat features remain mounted behind the opening screen.
The build workflow packages the MistSplash folder as a resource in the unsigned IPA.
