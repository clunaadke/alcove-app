// Metres. x: sketch left→right; z: sketch top→bottom; y: height.
// Only the bed dimensions/orientation and relative furniture positions are confirmed.
export const layout = {
  room: { width: 3.96, depth: 4.02, height: 2.6, estimated: true },
  bed: { x: 0, z: .55, width: 2, depth: 1.5, head: 'left', estimated: false },
  desk: { x: 0, z: 0, width: 2, depth: .55, height: .76, estimated: true },
  wardrobe: { x: 0, z: 3.47, width: 2.05, depth: .55, height: 2.52, estimated: true },
  cabinet: { x: 3.11, z: .05, width: .75, depth: .55, height: 1.675, estimated: true },
  shelf: { x: 3.60, z: 1.15, width: .36, depth: .85, height: 1.65, estimated: true },
  window: { x: .1, width: 1.8, sill: 1, height: 1.35, estimated: true },
  guitar: { x: 3.57, z: .86, estimated: true },
  door: { x: 3.06, width: .8, estimated: true }
};
