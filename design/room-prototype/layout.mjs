// Metres. x: sketch left→right; z: sketch top→bottom; y: height.
// Only the bed dimensions/orientation and relative furniture positions are confirmed.
export const layout = {
  room: { width: 3.3, depth: 3.35, height: 2.6, estimated: true },
  bed: { x: 0, z: .55, width: 2, depth: 1.5, head: 'left', estimated: false },
  desk: { x: 0, z: 0, width: 2, depth: .55, height: .76, estimated: true },
  wardrobe: { x: 0, z: 2.8, width: 2.05, depth: .55, height: 2.52, estimated: true },
  cabinet: { x: 2.45, z: .05, width: .75, depth: .55, height: 1.675, estimated: true },
  shelf: { x: 2.94, z: 1.15, width: .36, depth: .85, height: 1.65, estimated: true },
  window: { x: .1, width: 1.8, sill: 1, height: 1.35, estimated: true },
  door: { x: 2.4, width: .8, estimated: true }
};
