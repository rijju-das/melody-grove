const $ = (id) => document.getElementById(id);
let gameStarted = false, starting = false, paused = false, installPrompt = null;
const audioContexts = [];
try { if (navigator.audioSession) navigator.audioSession.type = 'playback'; } catch {}
if (window.AudioContext) {
  window.AudioContext = new Proxy(window.AudioContext, {construct(Target, args) {
    const context = new Target(...args); audioContexts.push(context); return context;
  }});
}
const unlockAudio = () => audioContexts.forEach(context => {
  if (context.state !== 'running' && context.state !== 'closed') context.resume().catch(() => {});
});
window.addEventListener('pointerdown', unlockAudio, {passive:true});
window.addEventListener('keydown', unlockAudio);
let soundCheckContext;
$('sound-check').onclick = async () => {
  try {
    soundCheckContext ||= new AudioContext();
    await soundCheckContext.resume();
    const note=soundCheckContext.createOscillator(), gain=soundCheckContext.createGain();
    note.frequency.value=261.63;gain.gain.setValueAtTime(0.08,soundCheckContext.currentTime);
    gain.gain.exponentialRampToValueAtTime(0.001,soundCheckContext.currentTime+0.6);
    note.connect(gain).connect(soundCheckContext.destination);note.start();note.stop(soundCheckContext.currentTime+0.6);
    $('sound-hint').textContent='Playing Do · check your phone volume';
  } catch {$('sound-hint').textContent='Turn Silent Mode off and tap again.';}
};
const PROGRESS_KEY='melody-grove-progress-v1';
let completedShown=false, activeLesson=null, pendingStage=1;
let memoryProgress=null;
function readProgress() {
  if(memoryProgress) return memoryProgress;
  try {const value=JSON.parse(localStorage.getItem(PROGRESS_KEY));return value?.version===1&&Array.isArray(value.records)&&value.records.length===3 ? value : null;} catch {return null;}
}
window.groveLoadProgress=()=>JSON.stringify(readProgress());
window.groveSaveProgress=text=>{
  try {memoryProgress=JSON.parse(text);localStorage.setItem(PROGRESS_KEY,text);updateStageMenu();return true;} catch {updateStageMenu();return false;}
};
function updateStageMenu() {
  const records=readProgress()?.records||[];
  let unlocked=1,total=0;
  for(let i=0;i<3;i++) {
    const record=records[i];
    if(record?.complete&&i<unlocked){total+=Math.max(0,Number(record.score)||0);unlocked=Math.min(3,i+2);}
    const button=document.querySelector(`[data-stage="${i+1}"]`);
    button.disabled=i+1>unlocked;
    button.querySelector('.stage-result').textContent=record?.complete ? `${'★'.repeat(Math.min(3,Math.max(1,Number(record.stars)||1)))} · Best: ${Number(record.score)||0} points` : (i+1<=unlocked?'Play stage →':`Finish stage ${i} to unlock`);
  }
  $('best-total').textContent=`${total} points saved`;
  pendingStage=unlocked;
  $('play').firstChild.textContent=unlocked>1?'Continue your journey ':'Start your journey ';
}
document.querySelectorAll('[data-stage]').forEach(button=>button.onclick=()=>play(Number(button.dataset.stage)));
updateStageMenu();
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
  if (!state.lesson) return;
  const lesson=state.lesson;activeLesson=lesson;
  $('lesson-title').textContent=`0${lesson.stage} · ${lesson.title}`;
  $('stage-score').textContent=`${lesson.score} pts`;
  $('lesson-goal').textContent=lesson.stage===1 ? `${lesson.collected} / 8 golden notes collected · 80 points to unlock stage 2` : `Melody ${lesson.round} / 3 · ${lesson.answer} / ${lesson.length||4} notes chosen · ${lesson.mistakes} mistakes`;
  $('lesson-progress').max=lesson.stage===1?8:3;
  $('lesson-progress').value=lesson.stage===1?lesson.collected:(lesson.phase==='complete'?3:lesson.round-1);
  $('note-action').dataset.command=lesson.stage===1?'repeat':'choose';
  $('note-action').textContent=lesson.stage===1?'♪ Play note':'✓ Choose note';
  $('listen').hidden=lesson.stage===1;
  $('listen').textContent=lesson.phase==='listening'?'Listening…':(lesson.phase==='answer'?'♪ Hear melody again':'♪ Listen to melody');
  const locked=state.paused||lesson.phase==='listening'||lesson.phase==='complete';
  ['back','next'].forEach(name=>document.querySelector(`[data-command="${name}"]`).disabled=locked);
  $('note-action').disabled=locked||state.hopping||state.step===0||(lesson.stage>1&&lesson.phase!=='answer');
  $('listen').disabled=locked||state.hopping;
  $('pause').disabled=lesson.phase==='complete';
  if(lesson.phase==='complete'&&!completedShown) {
    completedShown=true;
    $('complete-eyebrow').textContent=lesson.stage===3?'JOURNEY COMPLETE':'STAGE COMPLETE';
    $('earned-stars').textContent='★ '.repeat(lesson.stars)+'☆ '.repeat(3-lesson.stars);
    $('earned-stars').setAttribute('aria-label',`${lesson.stars} of 3 stars`);
    $('complete-title').textContent=['You found your first octave!','Your musical memory is growing!','The canopy is yours!'][lesson.stage-1];
    $('complete-summary').textContent=`${lesson.score} points · ${lesson.stage===1?'8 notes collected':lesson.mistakes+' mistakes'}. ${lesson.stage<3?'Your next stage is unlocked.':'Replay any stage to improve your stars.'}`;
    $('save-result').textContent=state.saved?'Best score and stage unlock saved on this device.':'Your browser could not save progress. Keep this tab open to continue.';
    $('continue-stage').textContent=lesson.stage<3?'Next stage →':'Back to your journey';
    $('complete-dialog').showModal();
  } else if(lesson.phase!=='complete') {completedShown=false;if($('complete-dialog').open)$('complete-dialog').close();}
};
function command(name,value) {if (typeof window.groveCommand==='function') window.groveCommand(name,value);}
document.querySelectorAll('[data-command]').forEach(button=>button.onclick=()=>command(button.dataset.command));
$('volume').oninput=event=>command('volume',Number(event.target.value));
function home() {if(gameStarted&&!paused)command('pause');$('complete-dialog').close();$('game-screen').hidden=true;$('welcome').hidden=false;updateStageMenu();window.scrollTo(0,0);}
$('home').onclick=home;
$('journey-home').onclick=home;
$('complete-dialog').addEventListener('cancel',event=>event.preventDefault());
$('continue-stage').onclick=()=>{if(activeLesson.stage<3){$('complete-dialog').close();command('stage',activeLesson.stage+1);}else home();};
$('replay-stage').onclick=()=>{$('complete-dialog').close();command('stage',activeLesson.stage);};
$('fullscreen').onclick=async()=>{
  try {if (document.fullscreenElement) await document.exitFullscreen();else if ($('game-screen').requestFullscreen) await $('game-screen').requestFullscreen();else {$('fullscreen').textContent='Turn phone sideways';}}
  catch {$('fullscreen').textContent='Turn phone sideways';}
};

async function play(stageNumber=pendingStage) {
  pendingStage=stageNumber;
  $('welcome').hidden=true;$('game-screen').hidden=false;window.scrollTo(0,0);
  if (gameStarted) {command('stage',stageNumber);return;}
  if (starting) return;
  starting=true;$('loading').hidden=false;$('retry').hidden=true;
  try {
    if (!window.Engine) await new Promise((resolve,reject)=>{const script=document.createElement('script');script.src='game.js';script.onload=resolve;script.onerror=()=>reject(new Error('Could not load the game. Check your connection and try again.'));document.head.append(script);});
    const missing=Engine.getMissingFeatures({threads:false});
    if(missing.length) throw new Error('This browser cannot run the 3D game. Try an updated Safari or Chrome.');
    resizeCanvas();
    const engine=new Engine({...GROVE_CONFIG,canvas:$('canvas'),canvasResizePolicy:0,focusCanvas:false});
    await engine.startGame({onProgress:(current,total)=>{if(total>0){$('load-progress').value=current/total*100;$('load-message').textContent=`Opening the grove… ${Math.round(current/total*100)}%`;}}});
    await new Promise((resolve,reject)=>{let attempts=0;const check=()=>{if(typeof window.groveCommand==='function')resolve();else if(attempts++>250)reject(new Error('The game did not finish starting. Please reload.'));else setTimeout(check,20);};check();});
    gameStarted=true;$('loading').hidden=true;document.querySelectorAll('[data-command]').forEach(button=>button.disabled=false);
    command('stage',pendingStage);
    $('canvas').focus();saveOffline();
  } catch(error) {$('load-message').textContent=error.message;$('retry').hidden=false;$('load-progress').hidden=true;}
  finally {starting=false;}
}
$('play').onclick=()=>play(pendingStage);$('retry').onclick=()=>{location.reload();};
document.addEventListener('visibilitychange',()=>{if(document.hidden&&gameStarted&&!paused) command('pause');});
saveOffline();
