// Shared, dependency-free weather calculations. CommonJS export enables offline checks.
const WeatherCore = {
  grid(lat, lon) {
    // 15 km cells. Clamp polar latitude; wrap longitude across the date line.
    lat = Math.max(-84, Math.min(84, lat));
    const dy = 15 / 111.32, dx = dy / Math.cos(lat * Math.PI / 180);
    return Array.from({length:49}, (_,i) => {
      const y = lat + (Math.floor(i/7)-3)*dy;
      const x = lon + (i%7-3)*dx;
      return {lat:y,lon:((x+180)%360+360)%360-180,west:x-dx/2,east:x+dx/2,south:y-dy/2,north:y+dy/2};
    });
  },
  futureIndices(times, now=Date.now()/1000) {
    const first = times.findIndex(t=>t>=now);
    if(first<0 || times.length-first<7) throw new Error('Forecast does not cover the next six hours. Please refresh.');
    return Array.from({length:7},(_,i)=>first+i);
  },
  value(v, digits=0) { return Number.isFinite(v) ? v.toFixed(digits) : '—'; },
  color(v, mode) {
    if(!Number.isFinite(v)) return '#89969d';
    if(mode==='temperature') return `hsl(${Math.max(0,Math.min(260,240-(v+10)*5))},75%,51%)`;
    return v<.1 ? '#d3e9e1' : v<.5 ? '#8fd5bb' : v<2 ? '#2ea78a' : v<5 ? '#2e83c4' : v<10 ? '#705bc4' : '#c84f93';
  }
};
if(typeof module!=='undefined') module.exports=WeatherCore;
