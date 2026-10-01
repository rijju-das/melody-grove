const {chromium}=require('/Users/rijju/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const assert=require('node:assert/strict');
(async()=>{
 const browser=await chromium.launch({channel:'chrome',headless:true});
 try{
  for(const [kind,userAgent] of [['iphone','Mozilla/5.0 (iPhone; CPU iPhone OS 26_3 like Mac OS X) AppleWebKit/605.1.15 Version/26.3 Mobile/15E148 Safari/604.1'],['android','Mozilla/5.0 (Linux; Android 15) AppleWebKit/537.36 Chrome/140.0 Mobile Safari/537.36']]){
   const context=await browser.newContext({viewport:{width:390,height:844},userAgent,hasTouch:true});
   const page=await context.newPage();const errors=[];page.on('pageerror',e=>errors.push(e.message));
   await page.goto('http://127.0.0.1:4321/');
   await page.evaluate(()=>{activeLesson={stage:4};document.getElementById('game-screen').hidden=false;showMicrophoneHelp('NotAllowedError');});
   assert.equal(await page.locator('#mic-help-device').inputValue(),kind);
   assert.match(await page.locator('#mic-help-steps').textContent(),kind==='iphone'?/Website Settings/:/Site settings/);
   assert.match(await page.locator('#mic-help-source').getAttribute('href'),kind==='iphone'?/support.apple.com/:/support.google.com/);
   await page.screenshot({path:`/Users/rijju/Documents/Blender_2026/godot-diagnostics/microphone-help-${kind}.png`});
   await page.locator('#mic-help-device').selectOption('other');assert.match(await page.locator('#mic-help-steps').textContent(),/another app/);
   await page.locator('#mic-help-close').click();assert(await page.locator('#mic-help-dialog').isHidden());
   assert.deepEqual(errors,[]);await context.close();
  }
  console.log('MICROPHONE HELP PASS: iPhone/Android instructions, manual browser choice, official guides, closable phone dialog');
 }finally{await browser.close();}
})().catch(e=>{console.error(e);process.exit(1);});
