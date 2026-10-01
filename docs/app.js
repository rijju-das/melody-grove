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
let completionTimer, rewardFrame, rewardAttempt=null, lastReward=0, displayedPoints=0;
const rewardAnimations=new Set();
const reducedMotion=window.matchMedia('(prefers-reduced-motion: reduce)');
function clearRewards() {
  cancelAnimationFrame(rewardFrame);
  clearTimeout(completionTimer);
  rewardAnimations.forEach(animation=>animation.cancel());rewardAnimations.clear();
  $('reward-effects').replaceChildren();$('reward-plus').textContent='';
}
function animateReward(reward, score) {
  const reduced=reducedMotion.matches;
  const wallet=$('points-wallet'), bounds=$('canvas').getBoundingClientRect(), target=wallet.getBoundingClientRect();
  $('reward-plus').textContent=`+${reward.amount}`;
  $('reward-announcement').textContent=`Plus ${reward.amount} points. ${score} points this stage.`;
  const run=(element,frames,options,cleanup=()=>{})=>{
    const animation=element.animate(frames,options);rewardAnimations.add(animation);
    animation.finished.then(cleanup).catch(()=>{}).finally(()=>rewardAnimations.delete(animation));
  };
  if(!reduced) {
    const spark=document.createElement('span');spark.className='flying-gem';
    const gem=document.createElement('span');gem.className='gem-icon';
    const label=document.createElement('b');label.textContent=`+${reward.amount}`;
    spark.append(gem,label);$('reward-effects').append(spark);
    const x=bounds.left+bounds.width*reward.from[0], y=bounds.top+bounds.height*reward.from[1];
    const endX=target.left+target.width/2, endY=target.top+target.height/2;
    spark.style.left=`${x}px`;spark.style.top=`${y}px`;
    run(spark,[{transform:'translate(-50%,-50%) scale(.7)',opacity:0},{transform:'translate(-50%,calc(-50% - 24px)) scale(1.15)',opacity:1,offset:.24},{transform:`translate(calc(-50% + ${endX-x}px),calc(-50% + ${endY-y}px)) scale(.5)`,opacity:1,offset:.86},{transform:`translate(calc(-50% + ${endX-x}px),calc(-50% + ${endY-y}px)) scale(.2)`,opacity:0}],{duration:760,easing:'cubic-bezier(.3,.1,.6,1)'},()=>spark.remove());
  }
  run(wallet,reduced?[{opacity:.7},{opacity:1}]:[{transform:'scale(1)'},{transform:'scale(1.10)'},{transform:'scale(1)'}],{duration:320,delay:reduced?0:560});
  run($('reward-plus'),[{opacity:1},{opacity:1,offset:.7},{opacity:0}],{duration:1100});
  cancelAnimationFrame(rewardFrame);
  const start=displayedPoints, started=performance.now(), delay=reduced?0:500;
  const count=now=>{
    const t=reduced?1:Math.max(0,Math.min(1,(now-started-delay)/260));
    displayedPoints=Math.round(start+(score-start)*t);$('points-count').textContent=displayedPoints;
    if(t<1)rewardFrame=requestAnimationFrame(count);
  };
  rewardFrame=requestAnimationFrame(count);
}
function updateRewards(state) {
  const lesson=state.lesson;
  if(rewardAttempt!==state.attempt) {
    $('game-screen').classList.remove('memory-settings-open');
    $('memory-settings').setAttribute('aria-expanded','false');
    clearRewards();rewardAttempt=state.attempt;lastReward=state.reward?.id||0;
    displayedPoints=lesson.score;$('points-count').textContent=lesson.score;
    completedShown=false;
  }
  $('gem-count').textContent=lesson.stage===4?`${lesson.round-1+(lesson.phase==='complete'||lesson.phase==='practice_complete'?1:0)} / 5`:lesson.stage===1?`${lesson.collected} / 8`:`${lesson.phase==='complete'?3:lesson.round-1} / 3`;
  $('gem-label').textContent=lesson.stage===4?'STEPS':lesson.stage===1?'GEMS':'MELODIES';
  if(state.reward?.id>lastReward) {lastReward=state.reward.id;animateReward(state.reward,lesson.score);}
  $('camera-mode').textContent=state.overview?'Follow view':'Wide view';
  $('camera-mode').setAttribute('aria-pressed',String(!!state.overview));
  $('view-label').textContent=state.camera_wide?(lesson.phase==='listening'?'LISTEN & WATCH':'FOREST VIEW'):'FOLLOWING YOU';
}
let memoryProgress=null;
function readProgress() {
  if(memoryProgress) return memoryProgress;
  try {const value=JSON.parse(localStorage.getItem(PROGRESS_KEY));return value?.version===1&&Array.isArray(value.records)&&[3,4].includes(value.records.length) ? value : null;} catch {return null;}
}
window.groveLoadProgress=()=>JSON.stringify(readProgress());
window.groveSaveProgress=text=>{
  try {memoryProgress=JSON.parse(text);localStorage.setItem(PROGRESS_KEY,text);updateStageMenu();return true;} catch {updateStageMenu();return false;}
};
function updateStageMenu() {
  const records=readProgress()?.records||[];
  let unlocked=1,total=0;
  for(let i=0;i<4;i++) {
    const record=records[i];
    if(record?.complete&&i<unlocked){total+=Math.max(0,Number(record.score)||0);unlocked=Math.min(4,i+2);}
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

const memoryLabels=['Low Do · C4','Re · D4','Mi · E4','Fa · F4','Sol · G4','La · A4','Ti · B4','High Do · C5'];
const memoryButtons=memoryLabels.map((label,index)=>{
  const button=document.createElement('button');button.dataset.note=index;
  button.setAttribute('aria-label',`Jump to ${label} (key ${index+1})`);
  button.onclick=()=>command('note',index);
  $('memory-targets').append(button);return button;
});
$('glade-listen').onclick=()=>command('listen');
$('concert-hint').onclick=()=>command('hint');
$('memory-settings').onclick=()=>{
  const expanded=$('memory-settings').getAttribute('aria-expanded')!=='true';
  $('memory-settings').setAttribute('aria-expanded',String(expanded));
  $('game-screen').classList.toggle('memory-settings-open',expanded);
};
let memoryInputBlocked=true;
window.addEventListener('keydown',event=>{
  if($('game-screen').hidden||(activeLesson?.stage||0)<2||!/^Digit[1-8]$/.test(event.code)||/INPUT|TEXTAREA|SELECT/.test(event.target.tagName))return;
  event.preventDefault();
  if(!event.repeat&&!memoryInputBlocked)command('note',Number(event.code.slice(-1))-1);
});
function updateMemory(state) {
  const singing=state.lesson.stage===4;
  const memory=state.lesson.stage===2||state.lesson.stage===3;
  $('game-screen').classList.toggle('memory-game',memory);
  $('game-screen').classList.add('compact-game');
  document.querySelector('.step-buttons').hidden=memory||singing;
  $('memory-markers').hidden=!memory||singing;
  $('camera-mode').hidden=memory||singing;
  const tappable=state.lesson.stage===1||memory;
  $('memory-targets').hidden=!tappable||state.transitioning;
  memoryInputBlocked=!memory||state.paused||state.hopping||state.recovering||state.transitioning||state.lesson.phase!=='answer';
  const glade=$('glade-listen');
  glade.hidden=!memory||state.transitioning||state.lesson.phase==='complete';
  glade.disabled=state.paused||state.hopping||state.recovering||state.transitioning||state.lesson.phase==='listening'||state.lesson.phase==='complete';
  $('glade-prompt').textContent=state.lesson.phase==='listening'?'♪ Listening…':(state.lesson.phase==='answer'?'Listen again':'Tap to listen');
  const landmark=state.lesson.stage===3?'musical lantern':'Listening Glade';
  glade.setAttribute('aria-label',`${state.lesson.phase==='answer'?'Hear the melody again':'Listen to the melody'} at the ${landmark}`);
  $('concert-hint').hidden=state.lesson.stage!==3;
  $('concert-hint').disabled=glade.disabled;
  $('concert-hint').textContent=state.guided&&state.lesson.phase==='listening'?'Showing hint…':'Show hint';
  const centre=state.glade_target;
  if(centre?.length){glade.style.left=`${centre[0]*100}%`;glade.style.top=`${centre[1]*100}%`;glade.style.width=`${centre[2]*100}%`;}
  $('memory-settings').hidden=false;
  memoryButtons.forEach((button,i)=>{
    button.disabled=!tappable||state.paused||state.hopping||state.recovering||state.transitioning||state.lesson.phase==='complete'||(memory&&state.lesson.phase!=='answer');
    button.setAttribute('aria-label',memory?`Jump to ${memoryLabels[i]} (key ${i+1})`:`Jump to ${memoryLabels[i]} and hear its note`);
    const point=state.targets?.[i];
    button.hidden=!point||point[0]<0||point[0]>1||point[1]<0||point[1]>1;
    if(point){button.style.left=`${point[0]*100}%`;button.style.top=`${point[1]*100}%`;button.style.width=`${point[2]*100}%`;}
  });
  const count=state.lesson.stage===3?4:3;
  if($('memory-markers').children.length!==count){
    $('memory-markers').replaceChildren(...Array.from({length:count},()=>document.createElement('span')));
  }
  $('memory-markers').setAttribute('aria-label',`${state.memory_marks||0} of ${count} notes correct`);
  [...$('memory-markers').children].forEach((marker,i)=>{marker.classList.toggle('filled',i<(state.memory_marks||0));marker.textContent=i<(state.memory_marks||0)?'✓':i+1;});
  document.querySelector('.keyboard').textContent=memory?'Click a platform or press 1–8 to jump · L: listen again':'Tap platforms or use arrows / WASD to hop · Space: hear note · C: camera';
  if(memory)$('view-label').textContent=state.lesson.phase==='listening'?'WATCH THE GLOW':'MUSICAL MEMORY';
  if(state.lesson.stage===3)$('view-label').textContent=state.guided&&state.lesson.phase==='listening'?'GUIDED REPLAY':['WATCH & REPEAT','FIRST NOTE GLOWS','LISTEN BY EAR'][Math.min((state.clearing||1)-1,2)];
}

let latestVoiceState=null, voiceMessage='', voiceAttempt=null;
const voiceInput=new GroveVoice.VoiceInput({
  send:(name,value)=>command(name,value),
  report:text=>{voiceMessage=text;$('voice-feedback').textContent=text;$('voice-enable').disabled=voiceInput.pending||voiceInput.mode==='calibrating';$('voice-enable').textContent=voiceInput.pending?'Waiting for permission…':voiceInput.mode==='calibrating'?'Checking microphone…':voiceInput.stream?'Turn mic off':'Enable microphone';},
  allowed:()=>activeLesson?.stage===4&&!paused&&!$('game-screen').hidden&&!document.hidden&&activeLesson.phase!=='complete'&&!latestVoiceState?.voice?.practice
});
function updateVoice(state){
  latestVoiceState=state;
  const active=state.lesson.stage===4;
  $('game-screen').classList.toggle('singing-game',active);
  $('voice-guide').hidden=!active||state.transitioning;
  $('voice-controls').hidden=!active||state.transitioning;
  $('voice-feedback').hidden=!active;
  $('sound-check').disabled=active;
  if(!active||state.paused||state.transitioning||state.lesson.phase==='complete'||state.voice.practice||$('game-screen').hidden){voiceInput.stop();}
  if(!active)return;
  if(voiceAttempt!==state.attempt){voiceInput.stop();voiceAttempt=state.attempt;voiceMessage='';$('voice-options-panel').hidden=true;$('voice-options').setAttribute('aria-expanded','false');}
  const v=state.voice,phase=state.lesson.phase;
  if(v.enabled||v.practice)voiceMessage='';
  voiceInput.setListening(v.enabled&&!state.paused&&!state.hopping&&phase==='answer');
  $('voice-enable').disabled=state.paused||state.hopping||phase==='complete'||v.practice||voiceInput.pending||voiceInput.mode==='calibrating';
  $('voice-enable').textContent=voiceInput.pending?'Waiting for permission…':voiceInput.mode==='calibrating'?'Checking microphone…':voiceInput.stream?'Turn mic off':'Enable microphone';
  $('voice-listen').disabled=state.paused||state.hopping||!['ready','answer'].includes(phase)||(!v.enabled&&!v.practice);
  $('voice-next').hidden=!v.practice;
  $('voice-next').disabled=state.paused||state.hopping||phase!=='answer';
  $('voice-range').disabled=state.hopping||phase==='complete';
  $('voice-range').value=String(v.octave);
  $('voice-target').textContent=`${v.target_name || 'Do · C4'}`;
  $('voice-feedback').textContent=state.paused?'Paused · microphone off':voiceInput.mode==='calibrating'||voiceInput.pending||(!v.enabled&&!v.practice&&voiceMessage)?voiceMessage:v.feedback;
  $('voice-hold').value=state.hopping?1:v.hold;
  const pitch=v.pitch_meter||{};
  $('voice-level').value=pitch.active?1:0;
  $('voice-level').style.width=`${Math.max(8,120*(pitch.active?pitch.value:(pitch.target_height||0.5)))}px`;
  $('voice-level').classList.toggle('matched',!!pitch.matched);
  $('voice-level').classList.toggle('reference',!!pitch.reference);
  $('voice-level').setAttribute('aria-valuetext',!pitch.active?'Waiting for your note':pitch.reference?`Reference ${v.target_name}, ${Math.round(pitch.hz)} Hz`:pitch.matched?'Matching the target note':pitch.error<0?'Pitch too low':'Pitch too high');
  $('view-label').textContent=v.practice?'LISTENING PRACTICE':'SING YOUR WAY UP';
}
$('voice-enable').onclick=()=>{voiceMessage='';if(voiceInput.stream)voiceInput.stop();else voiceInput.start();};
$('voice-listen').onclick=()=>{voiceMessage='';voiceInput.setListening(false);command('listen');};
$('voice-next').onclick=()=>command('practice_next');
$('voice-range').onchange=e=>{voiceMessage='';voiceInput.setListening(false);command('voice_range',Number(e.target.value));};
$('voice-practice').onclick=()=>{voiceInput.stop();command('practice');};
$('voice-options').onclick=()=>{const panel=$('voice-options-panel');panel.hidden=!panel.hidden;$('voice-options').setAttribute('aria-expanded',String(!panel.hidden));};
window.addEventListener('pagehide',()=>voiceInput.stop());
document.addEventListener('visibilitychange',()=>{if(document.hidden)voiceInput.stop();});

window.groveState = state => {
  paused=state.paused;
  $('note-status').textContent=state.text.replace(' · Space to repeat','').replace('Paused · press P or click Resume','Paused · tap Resume to continue').replace('Free play · use the arrow keys to continue','Hop onto a step, listen, then sing along').replace('At the start · press Up, Right, W or D','At the start · tap Next to hear Do');
  $('pause').textContent=paused?'Resume':'Pause';
  $('step-count').textContent=state.step?`NOTE ${state.step} / 8`:(state.lesson?.stage===2?'CENTRE':'START');
  if (!state.lesson) return;
  const lesson=state.lesson;activeLesson=lesson;
  updateRewards(state);
  updateMemory(state);
  updateVoice(state);
  $('path-transition').hidden=!state.transitioning;
  $('path-destination').textContent=state.concert_moving?`Growing the bridge to clearing ${state.clearing+1}…`:(state.transitioning?`Entering ${['','Echo meadow','Canopy concert','Singing stairway'][lesson.stage]}…`:'');
  $('lesson-title').textContent=lesson.stage===3?`Canopy concert · Clearing ${state.clearing}/3`:(lesson.stage===2?`Echo meadow · Melody ${Math.min(lesson.round,3)}/3`:`0${lesson.stage} · ${lesson.title}`);
  $('stage-score').textContent=`${lesson.score} pts`;
  $('lesson-goal').textContent=lesson.stage===1 ? `${lesson.collected} / 8 gems collected · 80 points to unlock stage 2` : `Melody ${lesson.round} / 3 · ${lesson.answer} / ${lesson.length||4} notes chosen · ${lesson.mistakes} mistakes`;
  $('lesson-progress').max=lesson.stage===1?8:3;
  $('lesson-progress').value=lesson.stage===1?lesson.collected:(lesson.phase==='complete'?3:lesson.round-1);
  $('note-action').dataset.command=lesson.stage===1?'repeat':'choose';
  $('note-action').textContent=lesson.stage===1?'♪ Play note':'✓ Choose note';
  $('listen').hidden=true;
  $('listen').textContent=lesson.phase==='listening'?'Listening…':(lesson.phase==='answer'?'♪ Hear melody again':'♪ Listen to melody');
  const locked=state.paused||state.transitioning||lesson.phase==='listening'||lesson.phase==='complete';
  ['back','next'].forEach(name=>document.querySelector(`[data-command="${name}"]`).disabled=locked);
  $('note-action').disabled=locked||state.hopping||state.step===0||(lesson.stage>1&&lesson.phase!=='answer');
  $('listen').disabled=locked||state.hopping||state.recovering;
  $('pause').disabled=lesson.phase==='complete'&&!state.transitioning;
  $('open-stages').disabled=!gameStarted||!!state.transitioning||lesson.phase==='complete';
  $('camera-mode').disabled=!!state.transitioning;
  document.querySelector('[data-command="restart"]').disabled=!!state.transitioning;
  if(lesson.phase==='complete'&&!completedShown&&!state.transitioning) {
    completedShown=true;
    $('complete-eyebrow').textContent=lesson.stage===4?'JOURNEY COMPLETE':'STAGE COMPLETE';
    $('earned-stars').textContent='★ '.repeat(lesson.stars)+'☆ '.repeat(3-lesson.stars);
    $('earned-stars').setAttribute('aria-label',`${lesson.stars} of 3 stars`);
    $('complete-title').textContent=lesson.stage===4?'You did it!':'Hurray!';
    $('complete-message').textContent=lesson.stage===4?'You sang your way to the treetop!':lesson.stage===3?'Your music brought the canopy to life!':`Well done! You crossed stage ${['one','two','three'][lesson.stage-1]}.`;
    $('complete-summary').textContent=`${lesson.score} points earned · ${lesson.stage===1?'8 gems collected':lesson.stars+' stars earned'}`;
    $('next-stage-hint').textContent=lesson.stage<4?`Stage ${lesson.stage+1} unlocked · ${['','Echo meadow','Canopy concert','Singing stairway'][lesson.stage]}`:'The whole grove is yours. Keep singing!';
    $('save-result').textContent=state.saved?'Best score and stage unlock saved on this device.':'Your browser could not save progress. Keep this tab open to continue.';
    $('continue-stage').textContent=lesson.stage<4?`Next stage ${lesson.stage+1} →`:'Back to your journey →';
    // Let the last gem reach the wallet before opening the stage result.
    completionTimer=setTimeout(()=>{
      if(activeLesson.phase!=='complete'||$('game-screen').hidden)return;
      const confetti=$('complete-dialog').querySelector('.success-confetti');
      confetti.replaceChildren();
      if(!reducedMotion.matches) for(let i=0;i<22;i++) {
        const piece=document.createElement('i');
        piece.style.cssText=`--x:${(i*37)%100}%;--delay:${(i%6)*.07}s;--turn:${i*53}deg;--colour:${['#ffda72','#90cc78','#f2a084','#fff6bc'][i%4]}`;
        confetti.append(piece);
      }
      $('complete-dialog').showModal();
      $('continue-stage').focus({preventScroll:true});
      command('celebrate');
    },reducedMotion.matches?0:950);
  } else if(lesson.phase!=='complete') {completedShown=false;clearTimeout(completionTimer);if($('complete-dialog').open)$('complete-dialog').close();}
};
function command(name,value) {if(['stage','restart','advance','pause'].includes(name))voiceInput.stop();if (typeof window.groveCommand==='function') window.groveCommand(name,value);}
document.querySelectorAll('[data-command]').forEach(button=>button.onclick=()=>command(button.dataset.command));
$('volume').oninput=event=>command('volume',Number(event.target.value));
function home() {voiceInput.stop();if(gameStarted&&!paused)command('pause');command('stop_celebration');clearRewards();$('complete-dialog').close();$('game-screen').hidden=true;$('welcome').hidden=false;updateStageMenu();window.scrollTo(0,0);}
let resumeAfterStageMenu=false;
const stageTitles=['Find the notes','Echo meadow','Canopy concert','Singing stairway'];
function openStagePicker(){
  if(!gameStarted||!activeLesson||$('open-stages').disabled||$('stage-picker').open)return;
  resumeAfterStageMenu=!paused;
  voiceInput.stop();
  if(resumeAfterStageMenu)command('pause');
  const choices=stageTitles.map((title,index)=>{
    const number=index+1,record=activeLesson.records?.[index];
    const locked=number>activeLesson.unlocked,current=number===activeLesson.stage;
    const button=document.createElement('button');
    button.type='button';button.dataset.jumpStage=number;button.disabled=locked||current;
    if(current)button.setAttribute('aria-current','step');
    const heading=document.createElement('strong');heading.textContent=`${number} · ${title}`;
    const detail=document.createElement('span');detail.textContent=current?'You are here':locked?`Finish stage ${number-1} to unlock`:record?.complete?`Replay · Best ${record.score} points`:'Play stage';
    button.append(heading,detail);
    button.onclick=()=>{
      if(number>activeLesson.unlocked)return;
      resumeAfterStageMenu=false;
      $('stage-picker').close();
      clearRewards();
      command('stage',number);
      $('canvas').focus({preventScroll:true});
    };
    return button;
  });
  $('stage-picker-list').replaceChildren(...choices);
  $('stage-picker').showModal();
  $('return-stage').focus({preventScroll:true});
}
$('open-stages').onclick=openStagePicker;
$('close-stages').onclick=()=> $('stage-picker').close();
$('return-stage').onclick=()=> $('stage-picker').close();
$('stage-picker').addEventListener('close',()=>{
  if(resumeAfterStageMenu&&!$('game-screen').hidden)command('pause');
  resumeAfterStageMenu=false;
  $('open-stages').focus({preventScroll:true});
});
$('home').onclick=home;
$('journey-home').onclick=home;
$('complete-dialog').addEventListener('cancel',event=>event.preventDefault());
$('continue-stage').onclick=()=>{if(activeLesson.stage<4){$('complete-dialog').close();command('advance');}else home();};
$('replay-stage').onclick=()=>{$('complete-dialog').close();command('stage',activeLesson.stage);};
$('fullscreen').onclick=async()=>{
  try {if (document.fullscreenElement) await document.exitFullscreen();else if ($('game-screen').requestFullscreen) await $('game-screen').requestFullscreen();else {$('fullscreen').textContent='Turn phone sideways';}}
  catch {$('fullscreen').textContent='Turn phone sideways';}
};

async function play(stageNumber=pendingStage) {
  voiceInput.stop();pendingStage=stageNumber;
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
document.addEventListener('visibilitychange',()=>{if(document.hidden&&gameStarted){command('stop_celebration');if(!paused)command('pause');}});
saveOffline();
