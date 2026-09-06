# Alcove local Live2D

Sidebar: Live2D 房间. Official Hiyori Momose FREE is an integration placeholder,
not Chenjing/Hodu's character. Runs in an offline WKWebView; no Electron, TTS,
AI calls, credential access, chat/session injection or remote requests.

Implemented: model display, single owned 30fps ticker, manual/reduced-motion
pause, foreground lifecycle and disposal, visible loading/error/retry UI.
Local touch: tap invokes bundled Tap; long press/stroke invokes bundled Flick
plus a restrained container tilt; gaze follows pointer coordinates. Single
pointer only, cancellation/multi-touch suppression, 850ms reaction cooldown.
Explicit tap/stroke buttons use the same logic. No custom core-parameter writer
competes with the official motions. These are demo motions, not a claim that
this model has a particular smile/blush response.

Files: www/live2d/{index.html,room.js,touch.js,vendor,model,licenses}.
Existing Capacitor sync copies www to bundled public resources on authorized
App builds. Local dependencies here are pinned; restore with npm ci --ignore-scripts.
No app-root dependencies or backend services changed.

Same display-library family as https://github.com/zziying/ai-live2d-body-starter;
its Electron/preload/hooks/custom choreography were not installed/copied.
Official model: https://cubism.live2d.com/sample-data/bin/hiyori/hiyori_en.zip
Core: https://cubism.live2d.com/sdk-web/cubismcore/live2dcubismcore.min.js
Original model readme and third-party license references are in bundled licenses.
Model/Core remain subject to Live2D terms; review before public distribution.

Validation: node --test *.cjs (8 mock/resource/gesture tests), node --check on JS.
No Chromium, iPhone, simulator, Swift compile or physical gesture verification.
Pending authorized build and device checks: offline asset load, actual model
motion/gaze, multitouch/pause/background/reentry behavior, heat and frame pacing.
Chat mini-window, cross-app PiP and AI interaction are NOT implemented.
