const {chromium}=require('/Users/rijju/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const assert=require('node:assert/strict');
const output='/Users/rijju/Documents/Blender_2026/godot-diagnostics';
(async()=>{
  const browser=await chromium.launch({channel:'chrome',headless:true});
  const context=await browser.newContext({viewport:{width:390,height:844},hasTouch:true});
  const page=await context.newPage(), errors=[];
  page.on('pageerror',e=>errors.push(e.message));
  page.on('console',m=>{if(m.type()==='error')errors.push(m.text());});
  const wait=fn=>page.waitForFunction(fn,null,{timeout:20000});
  const snap=name=>page.screenshot({path:`${output}/${name}.png`,fullPage:true});
  const move=async(direction,step)=>{
    await page.locator(`[data-command="${direction}"]`).tap();
    await page.waitForFunction(n=>window.testState.step===n&&!window.testState.hopping,step);
  };
  try {
    await page.goto('http://127.0.0.1:4321/');
    await page.evaluate(()=>{const report=window.groveState;window.testRewards=[];window.groveState=s=>{if(s.reward?.id&&s.reward.id!==window.testState?.reward?.id)window.testRewards.push(s.reward);window.testState=s;report(s);};});
    await page.locator('[data-stage="1"]').tap();
    await page.locator('#loading').waitFor({state:'hidden',timeout:60000});
    await wait(()=>window.testState?.attempt>0);
    await snap('follow-start-phone');
    await move('next',1);
    await page.waitForTimeout(150);
    assert.equal(await page.locator('.flying-gem').count(),1);
    assert.equal(await page.locator('#reward-plus').textContent(),'+10');
    await snap('follow-gem-pickup');
    await wait(()=>document.getElementById('points-count').textContent==='10');
    assert.equal(await page.locator('#gem-count').textContent(),'1 / 8');
    await move('back',0);await move('next',1);
    assert.equal(await page.evaluate(()=>window.testRewards.length),1);
    assert.equal(await page.locator('#points-count').textContent(),'10');
    await page.locator('#camera-mode').tap();
    await wait(()=>window.testState.overview);
    assert.equal(await page.locator('#camera-mode').getAttribute('aria-pressed'),'true');
    await page.waitForTimeout(1000);await snap('follow-wide-phone');
    await page.locator('#camera-mode').tap();await wait(()=>!window.testState.overview);
    await move('next',2);await move('next',3);
    await page.waitForTimeout(1000);await snap('follow-step3-phone');
    // Reset while a pickup is in flight: old animation must not change the new counter.
    await move('next',4);await page.locator('[data-command="restart"]').tap();
    await wait(()=>window.testState.step===0&&window.testState.lesson.score===0);
    await page.waitForTimeout(1200);
    assert.equal(await page.locator('#points-count').textContent(),'0');
    assert.equal(await page.locator('#gem-count').textContent(),'0 / 8');
    assert.equal(await page.locator('.flying-gem').count(),0);
    await page.emulateMedia({reducedMotion:'reduce'});
    await move('next',1);
    await wait(()=>document.getElementById('points-count').textContent==='10');
    assert.equal(await page.locator('.flying-gem').count(),0);
    await page.emulateMedia({reducedMotion:'no-preference'});
    await page.setViewportSize({width:844,height:390});await page.waitForTimeout(1000);
    await snap('follow-landscape');
    assert(await page.evaluate(()=>document.documentElement.scrollHeight<=innerHeight+1),'Landscape overflows');
    assert(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth),'Horizontal overflow');
    await page.setViewportSize({width:1440,height:1000});await page.waitForTimeout(1000);await snap('follow-desktop');
    assert.deepEqual(errors,[]);
    console.log('PASS: gem flight, +10, wallet count, duplicate prevention, camera toggle, retry during flight, reduced motion and responsive layouts');
  } catch(error){await snap('follow-error');throw error;}
  finally{await browser.close();}
})().catch(error=>{console.error(error);process.exit(1);});
