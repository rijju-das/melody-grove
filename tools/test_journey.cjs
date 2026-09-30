const {chromium}=require('/Users/rijju/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const fs=require('node:fs');
(async()=>{
 const browser=await chromium.launch({channel:'chrome',headless:true});
 const context=await browser.newContext({viewport:{width:390,height:844},hasTouch:true});
 const page=await context.newPage(), errors=[];
 page.on('pageerror',e=>{errors.push(e.message);console.log(e.message);});
 page.on('console',m=>{if(m.type()==='error'){errors.push(m.text());console.log(m.text());}});
 const snap=async(name)=>page.screenshot({path:`/Users/rijju/Documents/Blender_2026/godot-diagnostics/${name}.png`,fullPage:true});
 const state=()=>page.evaluate(()=>window.testState);
 const wait=async(fn,arg)=>page.waitForFunction(fn,arg,{timeout:15000});
 const wrap=()=>page.evaluate(()=>{const report=window.groveState;window.groveState=s=>{window.testState=s;report(s);};});
 const move=async(target)=>{
   let s=await state();
   while(s.step!==target){
     const next=s.step+(target>s.step?1:-1);
     await page.locator(`[data-command="${target>s.step?'next':'back'}"]`).tap();
     await wait(n=>window.testState?.step===n&&!window.testState.hopping,next);
     s=await state();
   }
 };
 const listen=async()=>{await page.locator('#listen').tap();await wait(()=>window.testState?.lesson.phase==='answer');};
 const answer=async(notes)=>{
   for(const note of notes){await move(note+1);const before=(await state()).lesson;await page.locator('#note-action').tap();await wait(old=>{const l=window.testState.lesson;return l.answer!==old.answer||l.round!==old.round||l.phase!==old.phase||l.mistakes!==old.mistakes;},before);}
 };
 try {
   await page.goto('http://127.0.0.1:4321/');
   await page.evaluate(()=>{
     const connect=AudioNode.prototype.connect;
     AudioNode.prototype.connect=function(...args){
       const result=connect.apply(this,args);
       if(args[0] instanceof AudioDestinationNode){const meter=this.context.createAnalyser();meter.fftSize=2048;connect.call(this,meter);(window.successMeters ||= []).push(meter);}
       return result;
     };
   });
   await page.getByText('Ready offline ✓',{exact:true}).first().waitFor({timeout:60000});
   if(!await page.locator('[data-stage="2"]').isDisabled())throw Error('Stage 2 not locked');
   await snap('journey-menu-phone');
   await wrap();await page.locator('[data-stage="1"]').tap();
   await wait(()=>window.testState?.lesson.stage===1&&typeof window.groveCommand==='function');
   await page.locator('#loading').waitFor({state:'hidden'});
   await move(1);await move(0);await move(1);
   if((await state()).lesson.score!==10)throw Error('Duplicate points');
   await snap('journey-stage1-phone');
   for(let i=2;i<=8;i++)await move(i);
   await page.locator('#complete-dialog').waitFor({state:'visible'});
   if((await state()).lesson.score!==80)throw Error('Stage1 score');
   const signal=await page.evaluate(async()=>{
     let peak=0;const samples=new Float32Array(2048);
     for(let i=0;i<24;i++){for(const meter of window.successMeters||[]){meter.getFloatTimeDomainData(samples);peak=Math.max(peak,Math.sqrt(samples.reduce((sum,x)=>sum+x*x,0)/samples.length));}await new Promise(r=>setTimeout(r,20));}
     return peak;
   });
   if(signal<0.001){console.log('Audio graph',await page.evaluate(()=>({meters:window.successMeters?.length,contexts:audioContexts.map(c=>c.state)})));throw Error('Victory audio is silent: '+signal);}
   if(await page.locator('#complete-message').textContent()!=='Well done! You crossed stage one.')throw Error('Success message missing');
   if(await page.locator('#continue-stage').textContent()!=='Next stage 2 →')throw Error('Next-stage button missing');
   console.log('PASS: victory jingle produces audio, success message and next-stage button');
   await snap('journey-stage1-complete');console.log('PASS: stage 1 collection, unique points and unlock');
   await page.setViewportSize({width:844,height:390});await snap('success-landscape');
   const visible=await page.locator('#continue-stage').evaluate(el=>{const r=el.getBoundingClientRect();return r.top>=0&&r.bottom<=innerHeight;});
   if(!visible)throw Error('Next-stage button off screen');
   await page.setViewportSize({width:390,height:844});
   await page.locator('#continue-stage').tap();await wait(()=>window.testState.transitioning);
   await page.waitForTimeout(900);await page.locator('#pause').tap();await wait(()=>window.testState.paused);
   await snap('success-opening-trees');await page.locator('#pause').tap();
   await wait(()=>window.testState.lesson.stage===2&&!window.testState.transitioning);
   await snap('success-new-forest');
   if(process.argv.includes('--passage-only')) {console.log('PASS: victory card, audio, responsive next-stage button and tree passage');return;}
   await listen();await move(2);await page.locator('#note-action').tap();await wait(()=>window.testState.lesson.mistakes===1);
   await answer([0,2,4]);await listen();await answer([4,2,0]);await listen();await answer([0,1,2]);
   await page.locator('#complete-dialog').waitFor({state:'visible'});
   const second=(await state()).lesson;
   if(second.score!==115||second.stars!==2||second.unlocked!==3)throw Error('Stage2 scoring');
   console.log('PASS: stage 2 melodies, wrong answer recovery, stars and unlock');
   await page.locator('#continue-stage').tap();await wait(()=>window.testState.lesson.stage===3);
   await page.setViewportSize({width:844,height:390});
   await page.locator('#listen').tap();await wait(()=>window.testState.lesson.phase==='listening');
   await page.locator('#pause').tap();await wait(()=>window.testState.paused);
   await page.waitForTimeout(1200);
   if((await state()).lesson.phase!=='listening')throw Error('Demo advanced while paused');
   await page.locator('#pause').tap();await wait(()=>window.testState.lesson.phase==='answer');
   await snap('journey-stage3-landscape');
   await answer([0,2,4,2]);await listen();await answer([2,3,4,7]);await listen();await answer([7,4,2,0]);
   await page.locator('#complete-dialog').waitFor({state:'visible'});
   if((await state()).lesson.total!==345)throw Error('Total score');
   await snap('journey-finished');console.log('PASS: stage 3, paused demo and full journey');
   await context.setOffline(true);await page.reload();await wrap();
   await page.getByText('345 points saved',{exact:true}).waitFor();
   if(await page.locator('[data-stage="3"]').isDisabled())throw Error('Unlock not persisted');
   await page.locator('[data-stage="2"]').tap();await wait(()=>window.testState?.lesson.stage===2);
   await page.locator('#loading').waitFor({state:'hidden'});
   await listen();await move(1);await page.locator('#note-action').tap();await wait(()=>window.testState.lesson.answer===1);
   if((await state()).lesson.total!==345)throw Error('Replay erased best scores');
   console.log('PASS: offline restart, persisted scores, selected stage and sound');
   if(errors.length)throw Error(JSON.stringify(errors));
   fs.writeFileSync('/Users/rijju/Documents/Blender_2026/godot-diagnostics/journey-tests.json',JSON.stringify({result:'PASS',stages:3,total:345,offline:true,victoryAudioRms:signal,treePassages:2,errors},null,2));
 } catch(error){await snap('journey-error');console.log('STATE',JSON.stringify(await state()));throw error;}
 finally {await browser.close();}
})().catch(error=>{console.error(error);process.exit(1);});
