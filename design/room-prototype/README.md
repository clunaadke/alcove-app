# Private Alcove room

User approved layout: bed 2m horizontal / 1.5m vertical, head left; desk attached
above with two-pane window behind; wardrobe lower left; glass cabinet upper
right; open iron shelf right; guitar on stand between cabinet and shelf; door
lower right. layout.mjs stores metres (x left→right, z sketch top→bottom, y up).
Only bed dimensions and relative layout are confirmed. The room is now 3.96 ×
4.02m, expanded 20% along each axis without scaling furniture. Dimensions remain
art-directed estimates. Wardrobe defaults hidden; iron shelf defaults visible,
with independent controls and hidden furniture excluded from picking. Wardrobe raised to 2.52m near ceiling, glass cabinet 1.675m
(window midpoint). Door opening direction remains unspecified.

Source:
- room.mjs: Three.js scene, on-demand rendering, orbit/zoom/top/labels/walls,
  local selection descriptions and foreground lifecycle.
- details.mjs: white metal glass cabinet and pegboard, thin open metal shelf,
  white matte wardrobe with upper/lower doors and curved pulls, acoustic guitar
  and stand, rounded pillows, low-poly draped dot quilt, small wing cushion,
  checker tablecloth, light neutral procedural woodgrain.
- curtains.mjs / curtain-state.mjs: cream pleated panels, procedural transparent
  lace hem, drag opening using projected world-axis direction, button and slider;
  camera interaction suspended during curtain drag and restored on cancellation.
  Approximate sunlight intensity responds to opening. Blender-authored pleated
  panel geometry replaces the basic plane after model load; lace remains locally
  generated alpha texture. No cloth simulation.

Blender 4.5.3 LTS now authors quilt thickness/drape, stuffed pillows/seams and
normalized curtain panels in blender/build_bedding.py. Folds are analytically
sculpted, not cloth-simulated. bedding.blend and bundled bedding.glb retain these
assets. GLTFLoader parses embedded base64 (bedding-data.mjs) to avoid WKWebView
file XHR; only local blob image fetch is permitted by CSP. Failure retains the
procedural bed and shows a nonfatal message. Disposal handles late loading.
Furniture remains procedural Three.js geometry. This is not yet a reference-image
photorealism match. daylight-state.mjs is an artistic 08:00–19:00 sun arc, changing
light direction, warmth/intensity and shadow maps, not city/date astronomy.
Window/cabinet glass does not cast opaque shadows. foliage.mjs adds three clusters (195 leaves and 18 branches) outside the window;
shadows use the existing moving directional light (no perpetual animation).
Tree meshes disable color/depth writes but retain shadow casting; Blender mirrors
this with ray visibility. The tree-shadow checkbox disables the whole foliage group.
Current palette: black surround, neutral walnut floor, white linen quilt and ONE
pillow, plain pleated linen curtains without lace; sunlight supplies the warmth.
No AI, chat, server state, personal photo textures or external asset requests.
Do not publish the user's photos/sketch/layout to communities.

www/room3d stores bundled HTML, JS, and Three.js MIT license. Existing authorized
Capacitor sync copies those to the iOS resource folder. Restore dependencies:
npm ci --ignore-scripts
Rebuild only local web assets:
./node_modules/.bin/esbuild room.mjs --bundle --format=iife --minify --target=safari16 --outfile=../../www/room3d/room.js
Tests: node --test test.mjs curtain.test.mjs daylight.test.mjs

Regenerate Blender assets (portable installation, no system service):
/root/.local/opt/blender-4.5.3-linux-x64/blender -b -t 2 --factory-startup --python blender/build_bedding.py
Then rebuild the local bundle as above. Official archive SHA256 verified:
975c58fcb244273838534bba771e64ad87739216b0f9b39a888531a49a72d845

Offline preview: node preview.mjs && python3 raster-preview.py
This executes the actual scene construction with a non-WebGL adapter, exports
triangles and actual canvas textures, and rasterizes with a CPU depth buffer.
Lighting is simplified; no shadow maps, no PBR or real WKWebView rendering.
Output /tmp/alcove-room-{perspective,top}-final.png; top hides walls/curtains.
Preview meshes come from the same source; do not present these as App screenshots.

Material/shadow preview: after node preview.mjs, run Blender with
blender/render_room.py. It imports the runtime world geometry/textures and renders
with CPU Cycles. These are Blender lighting results, NOT WebGL or App screenshots.
Output /tmp/room-french-preview.png. Phone performance remains unverified.

Validation: eight layout/camera/asset/curtain/daylight/GLB tests; actual Node GLB
parse and scene export, including furniture default/toggle and fallback checks.
Pending: explicit authorization to commit/push/build; Xcode compile; iPhone
WebGL/file access, textures, transparency, touch conflict, gestures, lifecycle,
performance and user visual acceptance. This enhancement pass is uncommitted and not pushed; no backend changes.
The earlier baseline 0fc9630 was pushed with authorization; Actions not polled.
Live2D was removed at the user’s request. The room retains its own web container.
Neither chat mini-window nor cross-app PiP exists.
