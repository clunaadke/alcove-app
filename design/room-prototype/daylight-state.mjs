// Art-directed solar arc through the window, NOT astronomical location/time data.
export function daylightAt(hour, openness=1){
 const t=Math.max(8,Math.min(19,Number.isFinite(hour)?hour:14));
 const phase=(t-8)/11,altitude=Math.sin(phase*Math.PI);
 const warm=Math.pow(Math.abs(phase-.5)*2,1.7);
 return {hour:t,position:[-5+10*phase,1.3+5.5*altitude,-5.5],
  intensity:(1.2+2.0*altitude)*(.30+.70*Math.max(0,Math.min(1,openness))),
  color:[1,1-.28*warm,1-.48*warm],ambient:.65+.55*altitude,
  label:`${String(Math.floor(t)).padStart(2,'0')}:${String(Math.round((t%1)*60)).padStart(2,'0')}`};
}
