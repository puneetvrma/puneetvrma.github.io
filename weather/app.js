'use strict';
const $=id=>document.getElementById(id);
let mode='rain', points=[], forecasts=[], indices=[], radar=null, frame=0, timer=null, sequence=0, selected={lat:-31.95,lon:115.86,name:'Perth, Australia'}, fetchedAt;
const map=L.map('map',{worldCopyJump:true}).setView([selected.lat,selected.lon],9);
L.tileLayer('https://tile.openstreetmap.org/{z}/{x}/{y}.png',{maxZoom:18,attribution:'© <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>'}).addTo(map);
const cells=L.layerGroup().addTo(map);
const marker=L.circleMarker([selected.lat,selected.lon],{radius:5,color:'#142c39',weight:2,fillColor:'#fff',fillOpacity:1}).addTo(map);
let radarLayer;
function status(msg,error=false){$('status').textContent=msg;$('status').className=error?'error':'';}
async function json(url){const response=await fetch(url,{signal:AbortSignal.timeout(25000)});if(!response.ok)throw Error(`Weather service returned ${response.status}. Try again later.`);return response.json();}
function format(t){return new Date(t*1000).toLocaleTimeString([],{hour:'2-digit',minute:'2-digit'});}
function value(v,d=0){return WeatherCore.value(v,d);}
function stop(){clearInterval(timer);timer=null;$('play').textContent='▶';}
async function load(location){
  stop();const request=++sequence;selected=location;$('place').textContent=location.name;
  marker.setLatLng([location.lat,location.lon]);map.setView([location.lat,location.lon],9);
  forecasts=[];indices=[];cells.clearLayers();$('temperature').textContent='—';$('rain').textContent='—';$('wind').textContent='—';$('summary').textContent='Loading forecast…';$('hours').replaceChildren();status('Loading 49 forecast samples…');
  try{
    const grid=WeatherCore.grid(location.lat,location.lon);
    const params=new URLSearchParams({latitude:grid.map(p=>p.lat.toFixed(4)).join(','),longitude:grid.map(p=>p.lon.toFixed(4)).join(','),hourly:'temperature_2m,precipitation,wind_speed_10m',forecast_hours:'10',timeformat:'unixtime',cell_selection:'nearest'});
    const key=`atlas:${location.lat.toFixed(3)},${location.lon.toFixed(3)}`;let saved;try{saved=JSON.parse(sessionStorage.getItem(key));}catch{}
    let data,stamp;
    if(saved&&Date.now()-saved.stamp<600000){data=saved.data;stamp=saved.stamp;}else{data=await json('https://api.open-meteo.com/v1/forecast?'+params);stamp=Date.now();try{sessionStorage.setItem(key,JSON.stringify({data,stamp}));}catch{}}
    if(request!==sequence)return;
    if(!Array.isArray(data)||data.length!==49||data.some(d=>!d.hourly?.time))throw Error('Incomplete forecast response. Please retry.');
    points=grid;forecasts=data;indices=WeatherCore.futureIndices(data[24].hourly.time);fetchedAt=stamp;
    const center=data[24].hourly;const first=indices[0];$('temperature').innerHTML=value(center.temperature_2m[first])+'<span>°C</span>';
    const rain=indices.slice(1).map(i=>center.precipitation[i]);$('rain').textContent=rain.every(Number.isFinite)?value(rain.reduce((a,b)=>a+b,0),1)+' mm':'Unavailable';
    $('wind').textContent=value(center.wind_speed_10m[first])+' km/h';$('summary').textContent='Next hourly forecast · '+format(center.time[first]);
    $('hours').replaceChildren(...indices.map((i,j)=>{const div=document.createElement('div');div.className='hour';div.innerHTML=`${j===0?'Next hour':format(center.time[i])}<strong>${value(center.temperature_2m[i])}°</strong><span>${value(center.precipitation[i],1)} mm</span>`;return div;}));
    frame=0;configureTimeline();draw();
  }catch(e){if(request===sequence){status(e.message,true);$('summary').textContent='Forecast unavailable. Search another city or refresh.';}}
}
function configureTimeline(){stop();const observed=mode==='radar';$('time').max=observed?Math.max(0,(radar?.radar.past.length||1)-1):6;frame=Math.min(frame,Number($('time').max));$('time').value=frame;$('start').textContent=observed?'Earlier observations':'Next hourly step';$('end').textContent=observed?'Latest observation':'+6 hours';$('timekind').textContent=observed?'Observed · past 2 hours':'Model forecast · next 6 hours';}
function draw(){
  cells.clearLayers();if(radarLayer){map.removeLayer(radarLayer);radarLayer=null;}
  $('badge').textContent=mode==='radar'?'OBSERVED RADAR · NOT A FORECAST':'MODEL FORECAST · 15 KM SAMPLES';
  $('layerTitle').textContent=mode==='radar'?'Observed radar':mode==='temperature'?'Temperature forecast':'Rain forecast';
  if(mode==='radar'){
    const f=radar?.radar.past[frame];$('legend').innerHTML='Observed precipitation<br><div class="scale" style="background:linear-gradient(90deg,#b9f4ff,#3880bd,#242974)"></div>Light → heavy · source zoom ≤ 7';
    if(!f){$('validTime').textContent='Radar unavailable';status('No observed radar frames are available. Forecast layers remain available.',true);return;}
    const age=(Date.now()/1000-f.time)/60;
    radarLayer=L.tileLayer(`${radar.host}${f.path}/256/{z}/{x}/{y}/2/1_1.png`,{opacity:.65,maxNativeZoom:7,maxZoom:18,attribution:'<a href="https://www.rainviewer.com/">RainViewer</a>'}).addTo(map);
    radarLayer.on('tileerror',()=>status('Some radar tiles failed to load. Blank areas may indicate missing coverage.',true));
    $('validTime').textContent=format(f.time)+' · observed';status(`${age>30?'Older radar frame. ':''}Frame age: ${Math.round(age)} min. Blank areas can mean no rain or no coverage.`,age>150);return;
  }
  if(!forecasts.length){$('validTime').textContent='Forecast unavailable';return;}
  const i=indices[frame];const field=mode==='temperature'?'temperature_2m':'precipitation';
  points.forEach((p,j)=>{const v=forecasts[j].hourly[field][i];const fill=WeatherCore.color(v,mode);L.rectangle([[p.south,p.west],[p.north,p.east]],{stroke:false,fillColor:fill,fillOpacity:mode==='rain'&&v<.1?.12:.53}).bindTooltip(`${value(v,mode==='rain'?1:0)} ${mode==='rain'?'mm in preceding hour':'°C'} · model sample`).addTo(cells);});
  marker.bringToFront();$('validTime').textContent=format(forecasts[24].hourly.time[i])+' · forecast';
  $('legend').innerHTML=mode==='temperature'?'Air temperature · °C<div class="scale" style="background:linear-gradient(90deg,#3333dd,#33dddd,#77dd33,#dddd33,#dd3333)"></div>−10　　　　15　　　　40':'Hourly precipitation · mm<div class="scale" style="background:linear-gradient(90deg,#d3e9e1,#8fd5bb,#2ea78a,#2e83c4,#705bc4,#c84f93)"></div>0　　　0.5　　　2　　　10+';
  status(`Forecast retrieved ${new Date(fetchedAt).toLocaleTimeString()}. 49 samples; ~15 km spacing. Rain totals cover the hour ending at the displayed time.`);
}
document.querySelectorAll('[data-mode]').forEach(button=>button.onclick=()=>{mode=button.dataset.mode;frame=mode==='radar'?Math.max(0,(radar?.radar.past.length||1)-1):0;document.querySelectorAll('[data-mode]').forEach(b=>b.classList.toggle('active',b===button));configureTimeline();draw();});
$('time').oninput=e=>{stop();frame=Number(e.target.value);draw();};$('play').onclick=()=>{if(timer){stop();return;}$('play').textContent='Ⅱ';timer=setInterval(()=>{frame=(frame+1)%(Number($('time').max)+1);$('time').value=frame;draw();},1500);};
let searchSequence=0;$('search').onsubmit=async e=>{e.preventDefault();const n=++searchSequence;try{const data=await json('https://geocoding-api.open-meteo.com/v1/search?'+new URLSearchParams({name:$('query').value.trim(),count:6,language:'en',format:'json'}));if(n!==searchSequence)return;$('results').replaceChildren(...(data.results||[]).map(p=>{const button=document.createElement('button');button.type='button';button.textContent=[p.name,p.admin1,p.country].filter(Boolean).join(', ');button.onclick=()=>{$('results').replaceChildren();load({lat:p.latitude,lon:p.longitude,name:button.textContent});};return button;}));if(!data.results?.length)$('results').textContent='No cities found. Try a nearby city.';}catch(e){status(e.message,true);}};
$('locate').onclick=()=>{if(!navigator.geolocation){status('Location is unavailable. Search for a city.',true);return;}navigator.geolocation.getCurrentPosition(p=>load({lat:p.coords.latitude,lon:p.coords.longitude,name:'My location'}),()=>status('Location access unavailable. Search for a city instead.',true),{timeout:15000,maximumAge:300000});};
map.on('click',e=>load({lat:e.latlng.lat,lon:((e.latlng.lng+180)%360+360)%360-180,name:`${e.latlng.lat.toFixed(3)}°, ${e.latlng.lng.toFixed(3)}°`}));
async function loadRadar(){try{const data=await json('https://api.rainviewer.com/public/weather-maps.json');if(!data.radar?.past?.length)throw Error('Radar currently unavailable.');radar=data;if(mode==='radar'){frame=data.radar.past.length-1;configureTimeline();draw();}}catch(e){if(mode==='radar')status(e.message,true);}}
$('refresh').onclick=()=>{load(selected);loadRadar();};
const script=document.createElement('script');script.src='core.js';script.onload=()=>{load(selected);loadRadar();};script.onerror=()=>status('Application files failed to load. Reload the page.',true);document.head.append(script);
