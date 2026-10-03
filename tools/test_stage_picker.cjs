const {chromium}=require('/Users/rijju/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const assert=require('node:assert/strict');
(async()=>{
 const browser=await chromium.launch({channel:'chrome',headless:true});
 const page=await browser.newPage({viewport:{width:390,height:844},hasTouch:true});
 const errors=[];page.on('pageerror',e=>errors.push(e.message));
 const wait=fn=>page.waitForFunction(fn,null,{timeout:30000});
 const pick=n=>page.locator(`[data-jump-stage="${n}"]`);
 try{
  await page.goto('http://127.0.0.1:4321/');
  await page.evaluate(()=>localStorage.setItem('melody-grove-ground-progress-v1',JSON.stringify({version:1,records:[80,120].map(score=>({complete:true,score,stars:3})).concat([{complete:false,score:0,stars:0},{complete:false,score:0,stars:0}])})));
  await page.reload();
  await page.evaluate(()=>{const report=window.groveState;window.groveState=s=>{window.testState=s;report(s);};});
  await page.locator('[data-stage="3"]').tap();
  await page.locator('#loading').waitFor({state:'hidden',timeout:60000});
  await wait(()=>window.testState?.lesson.stage===3);
  await page.locator('#open-stages').tap();await wait(()=>window.testState.paused);
  assert(await pick(1).isEnabled());assert(await pick(2).isEnabled());
  assert(await pick(3).isDisabled());assert.equal(await pick(3).getAttribute('aria-current'),'step');
  assert(await pick(4).isDisabled());assert.match(await pick(4).textContent(),/Finish stage 3/);
  await page.screenshot({path:'/Users/rijju/Documents/Blender_2026/godot-diagnostics/stages-phone.png'});
  await pick(1).tap();await wait(()=>window.testState.lesson.stage===1&&!window.testState.paused);
  assert(await page.locator('#welcome').isHidden());
  await page.evaluate(()=>window.groveCommand('next'));
  await wait(()=>window.testState.lesson.score===10&&!window.testState.hopping);
  await page.locator('#open-stages').tap();await wait(()=>window.testState.paused);
  await page.locator('#return-stage').tap();await wait(()=>!window.testState.paused);
  assert.equal(await page.evaluate(()=>window.testState.lesson.score),10);
  await page.locator('#pause').tap();await wait(()=>window.testState.paused);
  await page.locator('#open-stages').tap();await page.keyboard.press('Escape');
  await page.locator('#stage-picker').waitFor({state:'hidden'});
  assert(await page.evaluate(()=>window.testState.paused),'An already paused game stays paused');
  await page.setViewportSize({width:844,height:390});
  await page.locator('#open-stages').tap();
  for(let n=1;n<=4;n++){
   const rect=await pick(n).boundingBox();assert(rect.y>=0&&rect.y+rect.height<=390);
  }
  await page.screenshot({path:'/Users/rijju/Documents/Blender_2026/godot-diagnostics/stages-landscape.png'});
  await pick(3).tap();await wait(()=>window.testState.lesson.stage===3&&!window.testState.paused);
  assert.equal(await page.evaluate(()=>window.testState.lesson.total),200);
  await page.locator('#open-stages').tap();await pick(1).tap();
  await wait(()=>window.testState.lesson.stage===1&&!window.testState.paused);
  assert.equal(await page.evaluate(()=>window.testState.lesson.score),0);
  assert.equal(await page.evaluate(()=>window.testState.lesson.records[0].score),80);
  assert.equal(await page.evaluate(()=>JSON.parse(localStorage.getItem('melody-grove-ground-progress-v1')).records[1].score),120);
  await page.evaluate(()=>localStorage.setItem('melody-grove-ground-progress-v1',JSON.stringify({version:1,records:[80,120,150].map(score=>({complete:true,score,stars:3}))})));
  await page.reload();
  await page.evaluate(()=>{const report=window.groveState;window.groveState=s=>{window.testState=s;report(s);};});
  await page.locator('[data-stage="4"]').tap();await page.locator('#loading').waitFor({state:'hidden',timeout:60000});
  await wait(()=>window.testState?.lesson.stage===4);
  for(const viewport of [{width:390,height:844},{width:844,height:390}]){
   await page.setViewportSize(viewport);
   for(const id of ['open-stages','voice-enable','voice-listen']){
    const rect=await page.locator('#'+id).boundingBox();assert(rect.x>=0&&rect.x+rect.width<=viewport.width&&rect.y+rect.height<=viewport.height);
   }
   assert((await page.locator('.controls').boundingBox()).height<(viewport.width===390?185:135));
  }
  await page.locator('#open-stages').tap();assert(await pick(3).isEnabled());assert(await pick(4).isDisabled());
  assert.deepEqual(errors,[]);
  console.log('STAGE PICKER PASS: unlocked replay, locked/current states, pause/resume/Escape, fresh attempts, saved best scores, phone and landscape');
 }finally{await browser.close();}
})().catch(e=>{console.error(e);process.exit(1);});
