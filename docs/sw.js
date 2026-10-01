const CACHE='melody-grove-25a5556849a7';
const FILES=["./app.js", "./forest.png", "./game-config.js", "./game.apple-touch-icon.png", "./game.audio.position.worklet.js", "./game.audio.worklet.js", "./game.icon.png", "./game.js", "./game.pck", "./game.png", "./game.wasm.gz", "./icon-180.png", "./icon-192.png", "./icon-512.png", "./icon.svg", "./index.html", "./manifest.webmanifest", "./style.css", "./voice-input.js"];
self.addEventListener('install',event=>event.waitUntil((async()=>{
  const cache=await caches.open(CACHE);
  let done=0;
  for (const file of FILES) {
    const requestPath=file==='./index.html'?'./':file;
    const response=await fetch(new Request(requestPath,{cache:'reload'}));
    if(!response.ok || response.redirected) throw new Error('Unable to save '+file);
    await cache.put(file,response);
    done++;
    const clients=await self.clients.matchAll({includeUncontrolled:true});
    clients.forEach(client=>client.postMessage({type:'CACHE_PROGRESS',done,total:FILES.length}));
  }
  await self.skipWaiting();
})()));
self.addEventListener('activate',event=>event.waitUntil((async()=>{
  for (const key of await caches.keys()) if(key.startsWith('melody-grove-')&&key!==CACHE) await caches.delete(key);
  await self.clients.claim();
})()));
self.addEventListener('fetch',event=>{
  const url=new URL(event.request.url);
  if(event.request.method!=='GET'||url.origin!==self.location.origin) return;
  event.respondWith((async()=>{
    const cache=await caches.open(CACHE);
    const key=event.request.mode==='navigate'?'./index.html':event.request;
    return (await cache.match(key)) || fetch(event.request);
  })());
});
self.addEventListener('message',event=>{
  if(event.data?.type==='CHECK_OFFLINE') event.waitUntil((async()=>{
    const cache=await caches.open(CACHE);
    const found=await Promise.all(FILES.map(file=>cache.match(file)));
    event.ports[0]?.postMessage({ready:found.every(Boolean)});
  })());
});
