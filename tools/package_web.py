"""Package a Godot Web export as a self-contained installable website."""
import gzip, hashlib, json, re
from pathlib import Path

root=Path(__file__).resolve().parent.parent
public=root/'docs'
html=(public/'game.html').read_text()
config=json.loads(re.search(r'const GODOT_CONFIG = (.*?);',html).group(1))
(public/'game-config.js').write_text('const GROVE_CONFIG = '+json.dumps(config)+';\n')
wasm=public/'game.wasm'
if wasm.exists():
    (public/'game.wasm.gz').write_bytes(gzip.compress(wasm.read_bytes(),compresslevel=9,mtime=0))
    wasm.unlink()
assets=sorted(p.name for p in public.iterdir() if p.is_file() and not p.name.startswith('.') and p.name not in ['sw.js','game.html'])
version=hashlib.sha256(Path(__file__).read_bytes()+b''.join((public/name).read_bytes() for name in assets)).hexdigest()[:12]
sw='''const CACHE='melody-grove-VERSION';
const FILES=ASSETS;
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
'''.replace('VERSION',version).replace('ASSETS',json.dumps(['./'+name for name in assets]))
(public/'sw.js').write_text(sw)
print(f'Website ready: {len(assets)} offline files, {sum((public/n).stat().st_size for n in assets)/1e6:.1f} MB; version {version}')
