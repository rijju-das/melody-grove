const {chromium}=require('/Users/rijju/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const assert=require('node:assert/strict');
(async()=>{
 const browser=await chromium.launch({channel:'chrome',headless:true});
 const context=await browser.newContext({viewport:{width:390,height:844},hasTouch:true});
 const page=await context.newPage(),errors=[];
 page.on('pageerror',e=>errors.push(e.message));
 page.on('console',m=>{if(m.type()==='error')errors.push(m.text());});
 const wait=(fn,arg)=>page.waitForFunction(fn,arg,{timeout:30000});
 const state=()=>page.evaluate(()=>window.testState);
 const shot=name=>page.screenshot({path:`/Users/rijju/Documents/Blender_2026/godot-diagnostics/singing-${name}.png`,fullPage:true});
 try{
  await page.goto('http://127.0.0.1:4321/');
  await page.evaluate(()=>localStorage.setItem('melody-grove-progress-v1',JSON.stringify({version:1,records:[80,120,150].map(score=>({complete:true,score,stars:3}))})));
  await page.reload();await page.getByText('Ready offline ✓',{exact:true}).first().waitFor({timeout:60000});
  assert(await page.locator('[data-stage="4"]').isEnabled());
  await page.evaluate(()=>{
   const report=window.groveState;window.groveState=s=>{window.testState=s;report(s);};
   window.testMicrophones=[];window.denyMic=true;
   navigator.mediaDevices.getUserMedia=async()=>{
    if(window.denyMic)throw new DOMException('Denied','NotAllowedError');
    // A deterministic synthetic voice passes through the actual Web Audio analyser.
    const ctx=new AudioContext(),osc=ctx.createOscillator(),gain=ctx.createGain(),output=ctx.createMediaStreamDestination();
    gain.gain.value=0;osc.connect(gain).connect(output);osc.start();await ctx.resume();
    const mic={ctx,osc,gain,stream:output.stream};window.testMicrophones.push(mic);window.testMic=mic;
    return output.stream;
   };
  });
  await page.locator('[data-stage="4"]').tap();await page.locator('#loading').waitFor({state:'hidden',timeout:60000});
  await wait(()=>window.testState?.lesson.stage===4);await page.waitForTimeout(900);
  assert(await page.locator('#voice-guide').isVisible());assert(await page.locator('#memory-targets').isHidden());
  assert((await page.locator('.controls').boundingBox()).height<185);
  const coach=await page.locator('#voice-guide').boundingBox();
  assert(coach.x>195 && coach.x+coach.width<=390,'Singing coach stays on right side');
  assert.match(await page.locator('#voice-target').textContent(),/Do · C4/);
  assert(await page.locator('.controls #voice-enable').isVisible());
  assert.equal(await page.locator('#voice-guide progress').count(),2);
  assert.equal(await page.locator('#voice-guide button').count(),0);
  assert.equal(await page.locator('.pitch-centre,.pitch-zone').count(),0);
  const pitchRect=await page.locator('#voice-level').boundingBox(),holdRect=await page.locator('#voice-hold').boundingBox();
  assert(pitchRect.height<holdRect.height && Math.abs(pitchRect.y+pitchRect.height-holdRect.y-holdRect.height)<1 && pitchRect.x<holdRect.x);
  await shot('ready-phone');
  await page.locator('#voice-enable').tap();await page.getByText(/Microphone access was not allowed/).waitFor();
  assert.equal((await state()).lesson.score,0);
  await page.evaluate(()=>window.denyMic=false);
  await page.locator('#voice-enable').tap();await wait(()=>window.testState.voice.enabled);
  await page.locator('#voice-listen').tap();await wait(()=>window.testState.voice.pitch_meter.reference);
   assert(await page.locator('#voice-level').evaluate(el=>el.value>0));
   assert.equal((await state()).voice.hold,0);
   await wait(()=>window.testState.lesson.phase==='answer');
  await page.evaluate(()=>{testMic.osc.frequency.value=350;testMic.gain.gain.value=.2;});
  await wait(()=>window.testState.voice.has_pitch);await page.waitForTimeout(800);
  assert.equal((await state()).lesson.score,0);assert.match((await state()).voice.feedback,/lower/);
  assert((await state()).voice.pitch_meter.value>0.5);
  assert.equal(await page.locator('#voice-level').getAttribute('aria-valuetext'),'Pitch too high');
  await shot('pitch-guidance');
  // Pausing closes every microphone track. Resuming needs an explicit tap.
  await page.locator('#pause').tap();await wait(()=>window.testState.paused);
  assert(await page.evaluate(()=>testMicrophones.every(m=>m.stream.getTracks().every(t=>t.readyState==='ended'))));
  await page.locator('#pause').tap();await wait(()=>!window.testState.paused);
  await page.locator('#voice-enable').tap();await wait(()=>window.testState.voice.enabled);
  const referenceHeights=[],physicalHeights=[];
  for(let step=0;step<5;step++){
   if(step>0||((await state()).lesson.phase!=='answer')){
    await page.locator('#voice-listen').tap();await wait(()=>window.testState.voice.pitch_meter.reference);
   assert(await page.locator('#voice-level').evaluate(el=>el.value>0));
   assert.equal((await state()).voice.hold,0);
   referenceHeights.push((await state()).voice.pitch_meter.value);
   await page.waitForTimeout(120);
   const micBox=await page.locator('#voice-level').boundingBox(),jumpBox=await page.locator('#voice-hold').boundingBox();
   physicalHeights.push(micBox.height);
   assert(Math.abs(micBox.y+micBox.height-jumpBox.y-jumpBox.height)<1);
   assert.equal(jumpBox.height,120);
   assert.equal(await page.locator('#voice-level').evaluate(el=>el.value),1,'Active microphone bar is solid, with no empty track');
   if(step===2)await shot('reference-mi');
   await wait(()=>window.testState.lesson.phase==='answer');
   }
   assert.equal(await page.locator('#voice-level').evaluate(el=>el.value),0,'New reference clears the previous pitch');
   assert.match(await page.locator('#voice-target').textContent(),new RegExp(['Do · C4','Re · D4','Mi · E4','Re · D4','Do · C4'][step]));
   const hz=(await state()).voice.target*(step===0?.5:1);
   await page.evaluate(hz=>{testMic.osc.frequency.value=hz;testMic.gain.gain.value=.2;},hz);
   await wait(()=>window.testState.hopping);
   assert.match((await state()).voice.feedback,/Good!/);
   await wait(step=>window.testState.lesson.score===(step+1)*20,step);
   await page.evaluate(()=>testMic.gain.gain.value=0);
   if(step===1){await shot('climb-phone');await page.setViewportSize({width:844,height:390});await page.waitForTimeout(500);await shot('landscape');assert((await page.locator('.controls').boundingBox()).height<135);}
  }
  assert(referenceHeights[0]<referenceHeights[1] && referenceHeights[1]>referenceHeights[2] && referenceHeights[2]>referenceHeights[3],'Re, Mi, Re, Do have distinct reference heights');
  assert(physicalHeights[0]<physicalHeights[1] && physicalHeights[1]>physicalHeights[2] && physicalHeights[2]>physicalHeights[3],'Whole bar gets taller/shorter with Re, Mi, Re, Do');
  await page.locator('#complete-dialog').waitFor({state:'visible'});
  assert.equal((await state()).lesson.total,450);assert.equal((await state()).lesson.stars,3);
  assert(await page.evaluate(()=>testMicrophones.every(m=>m.stream.getTracks().every(t=>t.readyState==='ended'))));
  await shot('complete');
  await page.locator('#replay-stage').tap();await wait(()=>window.testState.lesson.phase==='ready');
  await page.locator('#voice-options').tap();await page.locator('#voice-practice').tap();await wait(()=>window.testState.voice.practice);
  for(let i=0;i<5;i++){
   await page.locator('#voice-listen').tap();await wait(()=>window.testState.lesson.phase==='answer');
   await page.locator('#voice-next').tap();await wait(i=>window.testState.step===i+1&&!window.testState.hopping,i);
  }
  assert.equal((await state()).lesson.phase,'practice_complete');assert.equal((await state()).lesson.score,0);
  assert(await page.locator('#complete-dialog').isHidden());
  await page.locator('#home').tap();await page.getByText('450 points saved',{exact:true}).waitFor();
  await context.setOffline(true);await page.reload();await page.getByText('450 points saved',{exact:true}).waitFor();
  assert.match(await page.locator('[data-stage="4"] .stage-result').textContent(),/100 points/);
  assert.deepEqual(errors,[]);
  console.log('SINGING WEB PASS: legacy unlock, permission denial/retry, real analyser synthetic voice, pitch guidance, five climbs, 100 points, mic cleanup, practice isolation, phone/landscape and offline save');
 }catch(e){await shot('error');console.log(await state());throw e;}finally{await browser.close();}
})().catch(e=>{console.error(e);process.exit(1);});
