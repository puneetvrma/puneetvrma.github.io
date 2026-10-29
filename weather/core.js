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
  futureIndices(times, now=Date.now()/1000, hours=6) {
    if(![1,3,6,12,24,72,168].includes(hours)) throw new Error("Unsupported forecast range.");
    const first = times.findIndex(t=>t>=now);
    if(first<0 || times.length-first<hours+1) throw new Error(`Forecast does not cover the selected ${hours}-hour range. Please refresh.`);
    return Array.from({length:hours+1},(_,i)=>first+i);
  },
  periods(times, hourly, indices, hours) {
    const first=indices[0];
    if(hours<=24) return indices.map((i,j)=>({time:times[i],temperature:hourly.temperature_2m[i],rain:hourly.precipitation[i],label:j===0?'Next hour':null,span:1}));
    return Array.from({length:hours/24},(_,day)=>{
      const start=first+day*24+1, end=start+24;
      const temps=hourly.temperature_2m.slice(start,end), rain=hourly.precipitation.slice(start,end);
      return {time:times[start-1],end:times[end-1],min:temps.every(Number.isFinite)?Math.min(...temps):null,max:temps.every(Number.isFinite)?Math.max(...temps):null,rain:rain.every(Number.isFinite)?rain.reduce((a,b)=>a+b,0):null,label:`Day ${day+1}`,span:24};
    });
  },
  value(v, digits=0) { return Number.isFinite(v) ? v.toFixed(digits) : '—'; },
  color(v, mode) {
    if(!Number.isFinite(v)) return '#89969d';
    if(mode==='temperature') return `hsl(${Math.max(0,Math.min(260,240-(v+10)*5))},75%,51%)`;
    return v<.1 ? '#d3e9e1' : v<.5 ? '#8fd5bb' : v<2 ? '#2ea78a' : v<5 ? '#2e83c4' : v<10 ? '#705bc4' : '#c84f93';
  }
};
if(typeof module!=='undefined') module.exports=WeatherCore;
