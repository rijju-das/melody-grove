const {chromium}=require('/Users/rijju/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const assert=require('node:assert/strict');
(async()=>{
 const browser=await chromium.launch({channel:'chrome',headless:true});
 const page=await browser.newPage({viewport:{width:390,height:844},hasTouch:true});
 const errors=[];page.on('pageerror',e=>errors.push(e.message));
 const wait=(fn,arg)=>page.waitForFunction(fn,arg,{timeout:30000});
 const state=()=>page.evaluate(()=>window.testState);
 try{
  await page.goto('http://127.0.0.1:4321/');
  // A completed platform save must neither unlock nor be overwritten by the experiment.
  const old=JSON.stringify({version:1,records:[80,120,150,100].map(score=>({complete:true,score,stars:3}))});
  await page.evaluate(old=>localStorage.setItem('melody-grove-progress-v1',old),old);
  await page.reload();
  assert(await page.locator('[data-stage="2"]').isDisabled());
  await page.evaluate(()=>{const report=window.groveState;window.groveState=s=>{window.testState=s;report(s);};});
  await page.locator('#play').tap();await page.locator('#loading').waitFor({state:'hidden',timeout:60000});
  await wait(()=>window.testState?.lesson.stage===1);
  assert.equal((await state()).lesson.title,'Whispering Meadow');
  await page.locator('[data-note="0"]').tap();
  await wait(()=>window.testState.lesson.score===10&&!window.testState.hopping);
  await page.locator('[data-note="0"]').tap();
  await page.waitForTimeout(400);
  assert.equal((await state()).lesson.score,10);
  // Focus the canvas; held keys move the camera/targets continuously without a note command.
  await page.locator('#canvas').focus();
  const before=(await state()).targets[0];
  await page.keyboard.down('ArrowLeft');await page.waitForTimeout(500);await page.keyboard.up('ArrowLeft');
  await page.waitForTimeout(300);
  const after=(await state()).targets[0];
  assert(Math.hypot(after[0]-before[0],after[1]-before[1])>.015,'Keyboard movement follows the explorer');
  // Tap empty ground between the player and flower; the actual canvas listener starts a walk.
  const box=await page.locator('#canvas').boundingBox();
  await page.touchscreen.tap(box.x+box.width*.50,box.y+box.height*.62);
  await wait(()=>window.testState.hopping);
  await wait(()=>!window.testState.hopping);
  await page.screenshot({path:'/Users/rijju/Documents/Blender_2026/godot-diagnostics/ground-web-phone.png',fullPage:true});
  await page.setViewportSize({width:844,height:390});
  await page.locator('#camera-mode').tap();
  for(let i=1;i<8;i++){
   await page.locator(`[data-note="${i}"]`).tap();
   await wait(score=>window.testState.lesson.score>=score&&!window.testState.hopping,(i+1)*10);
  }
  await page.locator('#complete-dialog').waitFor({state:'visible'});
  assert.equal((await state()).lesson.score,80);
  assert.equal(await page.evaluate(()=>localStorage.getItem('melody-grove-progress-v1')),old);
  assert.equal(await page.evaluate(()=>JSON.parse(localStorage.getItem('melody-grove-ground-progress-v1')).records[0].score),80);
  await page.locator('#continue-stage').tap();
  await wait(()=>window.testState.lesson.stage===2&&!window.testState.transitioning);
  await page.locator('#glade-listen').tap();await wait(()=>window.testState.lesson.phase==='answer');
  for(const note of [0,2,4]){
   await page.locator(`[data-note="${note}"]`).tap();
   await wait(()=>!window.testState.hopping);
  }
  await wait(()=>window.testState.lesson.score===30);
  await page.screenshot({path:'/Users/rijju/Documents/Blender_2026/godot-diagnostics/ground-web-echo.png',fullPage:true});
  assert.deepEqual(errors,[]);
  console.log('GROUND WEB PASS: phone flower taps, free keyboard and ground movement, unique rewards, separate saves, celebration, connected passage and echo sequence');
 }finally{await browser.close();}
})().catch(e=>{console.error(e);process.exit(1)});
