export function curtainWidth(openness, fullWidth) {return fullWidth*(1-.76*Math.max(0,Math.min(1,openness)));}
export function dragOpenness(start, dx, side, pixels=180) {return Math.max(0,Math.min(1,start+(side==='left'?-dx:dx)/Math.max(1,pixels)));}
