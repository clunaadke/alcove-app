# Private Alcove room

User approved layout: bed 2m horizontal / 1.5m vertical, head left; desk attached
above with two-pane window behind; wardrobe lower left; glass cabinet upper
right; open iron shelf right; guitar on stand between cabinet and shelf; door
lower right. layout.mjs stores metres (x left→right, z sketch top→bottom, y up).
Only bed dimensions and relative layout are confirmed. Room/furniture sizes
remain estimated. Wardrobe raised to 2.52m near ceiling, glass cabinet 1.675m
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
  Approximate sunlight intensity responds to opening. No cloth simulation.

Details are currently procedural Three.js geometry; BLENDER HAS NOT BEEN USED.
This is a usable detail pass, not a photorealistic reference-image match.
No AI, chat, server state, personal photo textures or external asset requests.
Do not publish the user's photos/sketch/layout to communities.

www/room3d stores bundled HTML, JS, and Three.js MIT license. Existing authorized
Capacitor sync copies those to the iOS resource folder. Restore dependencies:
npm ci --ignore-scripts
Rebuild only local web assets:
./node_modules/.bin/esbuild room.mjs --bundle --format=iife --minify --target=safari16 --outfile=../../www/room3d/room.js
Tests: node --test test.mjs curtain.test.mjs

Offline preview: node preview.mjs && python3 raster-preview.py
This executes the actual scene construction with a non-WebGL adapter, exports
triangles and actual canvas textures, and rasterizes with a CPU depth buffer.
Lighting is simplified; no shadow maps, no PBR or real WKWebView rendering.
Output /tmp/alcove-room-{perspective,top}-final.png; top hides walls/curtains.
Preview meshes come from the same source; do not present these as App screenshots.

Passed: six layout/camera/asset/curtain-state tests; scene construction and CPU
preview; eight Live2D regression/gesture tests in the sibling directory.
Pending: explicit authorization to commit/push/build; Xcode compile; iPhone
WebGL/file access, textures, transparency, touch conflict, gestures, lifecycle,
performance and user visual acceptance. No commit, push or backend changes.
Live2D model is a separate page. Neither chat mini-window nor cross-app PiP exists.
