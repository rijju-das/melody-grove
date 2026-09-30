const $ = (id) => document.getElementById(id);
let gameStarted = false, starting = false, paused = false, installPrompt = null;
const audioContexts = [];
if (window.AudioContext) {
  window.AudioContext = new Proxy(window.AudioContext, {construct(Target, args) {
    const context = new Target(...args); audioContexts.push(context); return context;
  }});
}
window.addEventListener('pointerdown', () => audioContexts.forEach(context => {
  if (context.state === 'suspended') context.resume().catch(() => {});
}), {passive:true});
const resizeCanvas = () => {
  const bounds = $('stage').getBoundingClientRect();
  if (!bounds.width || !bounds.height) return;
  const scale = Math.min(window.devicePixelRatio || 1, 1.5);
  $('canvas').width = Math.round(bounds.width * scale);
  $('canvas').height = Math.round(bounds.height * scale);
};
new ResizeObserver(resizeCanvas).observe($('stage'));
const realFetch = window.fetch.bind(window);
// Keep the engine download small enough for mobile connections and static hosts.
window.fetch = async (input, options) => {
  const url = new URL(typeof input === 'string' || input instanceof URL ? input : input.url, location.href);
  if (url.origin === location.origin && url.pathname.endsWith('/game.wasm')) {
    if (!('DecompressionStream' in window)) throw new Error('Please update Safari or Chrome to play this game.');
    const response = await realFetch(new URL('game.wasm.gz', location.href), options);
    if (!response.ok) throw new Error('The game download failed. Reconnect and try again.');
    return new Response(response.body.pipeThrough(new DecompressionStream('gzip')), {headers:{'Content-Type':'application/wasm'}});
  }
  return realFetch(input, options);
};

function instructions(platform) {
  $('install-title').textContent = platform === 'iphone' ? 'Add to your iPhone' : 'Add to your Android';
  const steps = platform === 'iphone'
    ? ['Open this website in Safari.', 'Save the game below and wait for “Ready offline”.', 'Tap Share, then Add to Home Screen. If shown, enable Open as Web App, then tap Add.', 'Open Melody Grove from your Home Screen once while online. Check that it says “Ready offline”.']
    : ['Open this website in Chrome.', 'Save the game below and wait for “Ready offline”.', 'Tap Chrome’s ⋮ menu, then Install app or Add to Home screen.', 'Open Melody Grove from your Home Screen once while online. Check that it says “Ready offline”.'];
  $('install-steps').replaceChildren(...steps.map(text => {const li=document.createElement('li'); li.textContent=text; return li;}));
  $('install-dialog').showModal();
}
$('iphone').onclick = () => instructions('iphone');
$('android').onclick = async () => {
  if (installPrompt) {await installPrompt.prompt(); await installPrompt.userChoice; installPrompt=null;}
  else instructions('android');
};
$('close-dialog').onclick = () => $('install-dialog').close();
window.addEventListener('beforeinstallprompt', event => {event.preventDefault(); installPrompt=event;});
window.addEventListener('appinstalled', () => {installPrompt=null;});

let savePromise;
async function saveOffline() {
  if (savePromise) return savePromise;
  savePromise = (async () => {
    if (!('serviceWorker' in navigator) || !window.isSecureContext) throw new Error('Offline saving needs a secure HTTPS website.');
    $('download').disabled=true;
    $('offline-status').textContent='Saving your grove…';
    $('offline-detail').textContent='Keep this page open. Your game and sounds are being saved on this device.';
    const registration=await navigator.serviceWorker.register('./sw.js');
    if (!registration.active) await new Promise((resolve,reject) => {
      const worker=registration.installing || registration.waiting;
      if (!worker) {reject(new Error('Offline setup did not start. Please try again.'));return;}
      const check=() => {
        if (worker.state==='activated') resolve();
        if (worker.state==='redundant') reject(new Error('Could not save the game. Check your connection and available storage, then retry.'));
      };
      worker.addEventListener('statechange',check);check();
    });
    const ready=await navigator.serviceWorker.ready;
    const complete=await new Promise((resolve,reject) => {
      const channel=new MessageChannel();
      const timer=setTimeout(()=>reject(new Error('Offline check timed out. Please try again.')),15000);
      channel.port1.onmessage=event=>{clearTimeout(timer);resolve(event.data.ready);channel.port1.close();};
      ready.active.postMessage({type:'CHECK_OFFLINE'},[channel.port2]);
    });
    if (!complete) throw new Error('Some saved files are missing. Reconnect, reload this page and save again.');
    $('offline-status').textContent='Ready offline ✓';
    $('offline-detail').textContent='The full game is saved on this device. Add it to your Home Screen to keep it handy.';
    $('download').textContent='Saved on this device ✓';
    $('dialog-save').textContent='Ready offline ✓';
    if (navigator.storage?.persist) navigator.storage.persist().catch(()=>{});
  })().catch(error=>{
    $('offline-status').textContent='Offline copy not ready';
    $('offline-detail').textContent=error.message;
    $('download').textContent='Retry saving ↓';$('download').disabled=false;savePromise=null;
  });
  return savePromise;
}
$('download').onclick=saveOffline;
$('dialog-save').onclick=saveOffline;
if ('serviceWorker' in navigator) navigator.serviceWorker.addEventListener('message',event=>{
  if (event.data.type==='CACHE_PROGRESS') $('offline-detail').textContent=`Saving file ${event.data.done} of ${event.data.total}… Keep this page open.`;
});

window.groveState = state => {
  paused=state.paused;
  $('note-status').textContent=state.text.replace(' · Space to repeat','').replace('Paused · press P or click Resume','Paused · tap Resume to continue').replace('Free play · use the arrow keys to continue','Hop onto a step, listen, then sing along').replace('At the start · press Up, Right, W or D','At the start · tap Next to hear Do');
  $('pause').textContent=paused?'Resume':'Pause';
  $('step-count').textContent=state.step?`NOTE ${state.step} / 8`:'START';
};
function command(name,value) {if (typeof window.groveCommand==='function') window.groveCommand(name,value);}
document.querySelectorAll('[data-command]').forEach(button=>button.onclick=()=>command(button.dataset.command));
$('volume').oninput=event=>command('volume',Number(event.target.value));
$('home').onclick=()=>{if (gameStarted && !paused) command('pause');$('game-screen').hidden=true;$('welcome').hidden=false;};
$('fullscreen').onclick=async()=>{
  try {if (document.fullscreenElement) await document.exitFullscreen();else if ($('game-screen').requestFullscreen) await $('game-screen').requestFullscreen();else {$('fullscreen').textContent='Turn phone sideways';}}
  catch {$('fullscreen').textContent='Turn phone sideways';}
};

async function play() {
  $('welcome').hidden=true;$('game-screen').hidden=false;window.scrollTo(0,0);
  if (gameStarted) {if(paused) command('pause');return;}
  if (starting) return;
  starting=true;$('loading').hidden=false;$('retry').hidden=true;
  try {
    if (!window.Engine) await new Promise((resolve,reject)=>{const script=document.createElement('script');script.src='game.js';script.onload=resolve;script.onerror=()=>reject(new Error('Could not load the game. Check your connection and try again.'));document.head.append(script);});
    const missing=Engine.getMissingFeatures({threads:false});
    if(missing.length) throw new Error('This browser cannot run the 3D game. Try an updated Safari or Chrome.');
    resizeCanvas();
    const engine=new Engine({...GROVE_CONFIG,canvas:$('canvas'),canvasResizePolicy:0,focusCanvas:false});
    await engine.startGame({onProgress:(current,total)=>{if(total>0){$('load-progress').value=current/total*100;$('load-message').textContent=`Opening the grove… ${Math.round(current/total*100)}%`;}}});
    gameStarted=true;$('loading').hidden=true;document.querySelectorAll('[data-command]').forEach(button=>button.disabled=false);
    $('canvas').focus();saveOffline();
  } catch(error) {$('load-message').textContent=error.message;$('retry').hidden=false;$('load-progress').hidden=true;}
  finally {starting=false;}
}
$('play').onclick=play;$('retry').onclick=()=>{location.reload();};
document.addEventListener('visibilitychange',()=>{if(document.hidden&&gameStarted&&!paused) command('pause');});
saveOffline();
