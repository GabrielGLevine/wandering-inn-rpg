// Exported Godot DOM input and actual AudioContext fault injection.
// Viewport changes and desktop tab visibility do not prove phone suspension.
import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {createServer} from 'node:http';
import {mkdir, readFile, writeFile} from 'node:fs/promises';
import {dirname, extname, join, resolve, sep} from 'node:path';
import {fileURLToPath} from 'node:url';
import {chromium} from 'playwright';
import {isKnownRendererDiagnostic} from './lifecycle_result.mjs';

const game = resolve(dirname(fileURLToPath(import.meta.url)), '../..');
const root = join(game, 'build/web');
const profile = process.argv[2] ?? 'iphone', hosting = process.argv[3] ?? 'direct';
const headed = !process.argv.includes('--headless');
const profiles = {iphone:{width:844,height:390}, android:{width:915,height:412}};
assert(profiles[profile], 'Expected iphone or android');
assert(['direct','iframe'].includes(hosting), 'Expected direct or iframe');
const output = join(game, 'qa_output', `lifecycle_input_audio_${profile}_${hosting}`);
await mkdir(output, {recursive:true});
const expected = JSON.parse(await readFile(join(game,'qa/scripts/lifecycle_input_audio.json'),'utf8')).steps.length;
const mime = {'.html':'text/html','.js':'text/javascript','.wasm':'application/wasm','.pck':'application/octet-stream','.png':'image/png'};
const consoleLog = [], diagnostics = [], requests = [], probes = [], touches = [];
const server = createServer(async (req,res) => {
 const name = decodeURIComponent(new URL(req.url,'http://localhost').pathname);
 if (name === '/iframe.html') {
  res.writeHead(200,{'Content-Type':'text/html'}).end(`<!doctype html><meta name='viewport' content='width=device-width, initial-scale=1'><title>Local iframe lifecycle probe</title><link rel='icon' href='data:,'><style>html,body{margin:0;width:100%;height:100%;overflow:hidden;background:black}iframe{border:0;width:100%;height:100%}</style><iframe src='http://localhost:${server.address().port}/index.html' sandbox='allow-scripts allow-same-origin allow-downloads allow-modals' allow='autoplay; fullscreen'></iframe>`);
  requests.push({name,status:200}); return;
 }
 const path = resolve(root,'.'+(name==='/'?'/index.html':name));
 if (!path.startsWith(root+sep)) {res.writeHead(403).end();return;}
 try {const bytes=await readFile(path);res.writeHead(200,{'Content-Type':mime[extname(path)]??'application/octet-stream'}).end(bytes);requests.push({name,status:200});}
 catch {res.writeHead(404).end();requests.push({name,status:404});}
});
await new Promise(done => server.listen(0,'127.0.0.1',done));
const origin=`http://127.0.0.1:${server.address().port}`;
let browser,page,frame,result,runtime,failure=null,baselineGeometry;

async function geometry() {
 return frame.evaluate(() => {
  const canvas=document.querySelector('canvas'),rect=canvas.getBoundingClientRect();
  return {boot:window.__WI_LIFECYCLE_BOOT__,sameCanvas:canvas===window.__WI_LIFECYCLE_CANVAS__,viewport:[innerWidth,innerHeight],devicePixelRatio,canvasBacking:[canvas.width,canvas.height],rect:[rect.x,rect.y,rect.width,rect.height],visibility:document.visibilityState,overlay:getComputedStyle(document.querySelector('#wi-rotate-overlay')).display};
 });
}

async function tapName() {
 const rect=await frame.locator('canvas').boundingBox();
 assert(rect,'Missing canvas bounds');
 await page.touchscreen.tap(rect.x+rect.width/2,rect.y+rect.height/2);
 await frame.locator('input[type="text"]:not([disabled])').waitFor({state:'visible',timeout:3000});
}

async function audioOutput(control=false) {
 return frame.evaluate(async makeControl => {
  const audio=window.__WI_LIFECYCLE_AUDIO__;
  const gameContexts=audio.contexts.filter(ctx=>!ctx.__wiControl);
  const gameTaps=audio.taps.filter(tap=>!tap.context.__wiControl);
  async function peak(taps) {
   let rms=0;
   const samples=new Float32Array(2048);
   for(let round=0;round<6;round++) {
    for(const tap of taps) {
     tap.analyser.getFloatTimeDomainData(samples);
     rms=Math.max(rms,Math.sqrt(samples.reduce((sum,value)=>sum+value*value,0)/samples.length));
    }
    await new Promise(done=>setTimeout(done,100));
   }
   return rms;
  }
  const peakRms=await peak(gameTaps);
  let controlRms=null;
  if(makeControl) {
   const ctx=new AudioContext();ctx.__wiControl=true;
   const oscillator=ctx.createOscillator();oscillator.connect(ctx.destination);oscillator.start();
   await Promise.race([ctx.resume(),new Promise((_,fail)=>setTimeout(()=>fail(new Error('Control audio resume timed out')),2000))]);
   controlRms=await peak(audio.taps.filter(tap=>tap.context===ctx));
   oscillator.stop();await ctx.close();
  }
  return {states:gameContexts.map(ctx=>ctx.state),contexts:gameContexts.length,taps:gameTaps.length,peakRms,controlRms};
 },control);
}

try {
 browser=await chromium.launch({headless:!headed,ignoreDefaultArgs:['--disable-backgrounding-occluded-windows','--disable-renderer-backgrounding','--disable-background-timer-throttling'],args:['--single-process','--autoplay-policy=document-user-activation-required']});
 const context=await browser.newContext({viewport:profiles[profile],hasTouch:true,isMobile:true,deviceScaleFactor:1});
 page=await context.newPage();
 page.on('console',message=>{
  const row={type:message.type(),text:message.text()};consoleLog.push(row);
  if(['error','warning'].includes(row.type)||/SCRIPT ERROR|Parse Error|ERROR:|WARNING/.test(row.text)) diagnostics.push(row);
 });
 page.on('pageerror',error=>diagnostics.push({type:'pageerror',text:String(error)}));
 await context.addInitScript(() => {
  window.__WI_QA__={script:'res://qa/scripts/lifecycle_input_audio.json',seed:'9'};
  window.__WI_LIFECYCLE_BOOT__=crypto.randomUUID();
  window.__WI_LIFECYCLE_EVENTS__=[];
  for(const type of ['touchstart','touchend','touchcancel','focus','blur','input','visibilitychange']) document.addEventListener(type,event=>{
   window.__WI_LIFECYCLE_EVENTS__.push({type,trusted:event.isTrusted,time:performance.now(),visibility:document.visibilityState,target:event.target.tagName??'document',value:event.target.value??null,points:event.changedTouches?Array.from(event.changedTouches,touch=>({x:touch.clientX,y:touch.clientY})):null});
  },{capture:true,passive:true});
  const audio=window.__WI_LIFECYCLE_AUDIO__={contexts:[],taps:[],states:[]};
  const NativeContext=window.AudioContext;
  window.AudioContext=class extends NativeContext {
   constructor(...args) {super(...args);audio.contexts.push(this);this.addEventListener('statechange',event=>audio.states.push({state:this.state,trusted:event.isTrusted,time:performance.now()}));}
  };
  const connect=AudioNode.prototype.connect;
  AudioNode.prototype.connect=function(...args) {
   if(args[0]===this.context.destination) {
    const analyser=this.context.createAnalyser();analyser.fftSize=2048;
    connect.call(this,analyser);connect.call(analyser,this.context.destination);
    audio.taps.push({context:this.context,analyser});return args[0];
   }
   return connect.apply(this,args);
  };
 });
 await page.goto(origin+(hosting==='iframe'?'/iframe.html':'/index.html'));
 frame=hosting==='iframe'?await page.locator('iframe').elementHandle().then(handle=>handle.contentFrame()):page;
 assert(frame,'Missing game frame');
 const deadline=Date.now()+120000;
 while(Date.now()<deadline) {
  const req=await frame.evaluate(()=>window.__WI_QA_TOUCH_REQ__??null);
  if(req) {
   await frame.evaluate(()=>{window.__WI_QA_TOUCH_REQ__=null;});
   const canvas=await frame.locator('canvas').boundingBox();
   const backing=await frame.evaluate(()=>{const canvas=document.querySelector('canvas');return [canvas.width,canvas.height];});
   assert(canvas&&backing.every(size=>size>0),'Missing canvas touch geometry');
   // Engine window coordinates use backing pixels; Playwright taps use CSS pixels.
   const css={x:canvas.x+req.x*canvas.width/backing[0],y:canvas.y+req.y*canvas.height/backing[1]};
   await page.touchscreen.tap(css.x,css.y);
   touches.push({...req,css,backing});
   await frame.evaluate(()=>{window.__WI_QA_TOUCH_DONE__=(window.__WI_QA_TOUCH_DONE__||0)+1;});
  }
  const shot=await frame.evaluate(()=>window.__WI_QA_SHOT__??null);
  if(shot) {
   let probe={name:shot};probes.push(probe);
   if(shot==='00_audio_locked') {
    await frame.evaluate(()=>{window.__WI_LIFECYCLE_CANVAS__=document.querySelector('canvas');});
    baselineGeometry=await geometry();
    probe.audio=await audioOutput();
    assert(probe.audio.contexts>0,'Missing actual game audio context');
    probe.browserPolicyUnlockProven=probe.audio.states.every(state=>state==='suspended');
    if(!probe.browserPolicyUnlockProven) {
     probe.injectedStates=await frame.evaluate(async()=>{const contexts=window.__WI_LIFECYCLE_AUDIO__.contexts.filter(ctx=>!ctx.__wiControl);await Promise.all(contexts.map(ctx=>ctx.suspend()));return contexts.map(ctx=>ctx.state);});
     assert(probe.injectedStates.every(state=>state==='suspended'),'First-gesture context fault injection did not suspend');
     probe.mechanism='Cold context already running in this browser; explicitly suspended before first trusted title tap. Browser-policy unlock remains unproven.';
    }
   }
   if(shot==='01_title_audio') {
    probe.audio=await audioOutput(true);
    assert(probe.audio.states.every(state=>state==='running')&&probe.audio.peakRms>0.0001&&probe.audio.controlRms>0.0001,'First trusted title tap did not unlock actual game audio output');
   }
   if(shot==='02_name_enter') {
    await tapName();
    const input=frame.locator('input[type="text"]:not([disabled])');
    await input.fill('Mira');
    probe.domValue=await input.inputValue();assert.equal(probe.domValue,'Mira');
    await page.screenshot({path:join(output,'02a_name_entered.png')});
    await input.evaluate(element=>element.blur());
    probe.mechanism='trusted canvas tap → exported Godot HTML input fill → actual element.blur(); no OS keyboard claim';
   }
   if(shot==='03_rotation') {
    await page.setViewportSize({width:profiles[profile].height,height:profiles[profile].width});
    await frame.waitForFunction(()=>getComputedStyle(document.querySelector('#wi-rotate-overlay')).display==='flex',null,{timeout:2000});
    probe.portrait=await geometry();
    await page.screenshot({path:join(output,'03a_portrait_overlay.png')});
    await page.setViewportSize(profiles[profile]);
    await frame.waitForFunction(()=>getComputedStyle(document.querySelector('#wi-rotate-overlay')).display==='none',null,{timeout:2000});
    await page.waitForTimeout(150);
    probe.restored=await geometry();
    assert.equal(probe.restored.boot,baselineGeometry.boot);assert(probe.restored.sameCanvas);
    assert.deepEqual(probe.restored.rect,baselineGeometry.rect);
   }
   if(shot==='04_visibility') {
    await page.bringToFront();
    const alternate=await context.newPage();await alternate.goto('about:blank');await alternate.bringToFront();
    await page.waitForTimeout(200);probe.background=await geometry();
    await page.bringToFront();await page.waitForTimeout(150);probe.foreground=await geometry();await alternate.close();
    let edges=await frame.evaluate(()=>window.__WI_LIFECYCLE_EVENTS__.filter(event=>event.type==='visibilitychange'));
    probe.verified=probe.background.visibility==='hidden'&&probe.foreground.visibility==='visible'&&edges.some(event=>event.visibility==='hidden'&&event.trusted)&&edges.some(event=>event.visibility==='visible'&&event.trusted);
    probe.events=edges;probe.mechanism=`${headed?'headed':'headless'} desktop Chromium alternate tab bringToFront; no synthetic visibility event`;
    probe.tabSwitchVerified=probe.verified;
    if(!probe.verified&&headed) {
     const session=await context.newCDPSession(page);
     const {windowId}=await session.send('Browser.getWindowForTarget');
     try {
      await session.send('Browser.setWindowBounds',{windowId,bounds:{windowState:'minimized'}});
      await page.waitForTimeout(400);
      probe.minimizedBounds=(await session.send('Browser.getWindowBounds',{windowId})).bounds;
      probe.background=await geometry();
     } finally {
      await session.send('Browser.setWindowBounds',{windowId,bounds:{windowState:'normal'}});
      await page.bringToFront();await page.waitForTimeout(200);
     }
     probe.foreground=await geometry();
     edges=await frame.evaluate(()=>window.__WI_LIFECYCLE_EVENTS__.filter(event=>event.type==='visibilitychange'));
     probe.verified=probe.minimizedBounds.windowState==='minimized'&&probe.background.visibility==='hidden'&&probe.foreground.visibility==='visible'&&edges.some(event=>event.visibility==='hidden'&&event.trusted)&&edges.some(event=>event.visibility==='visible'&&event.trusted);
     probe.events=edges;probe.mechanism='headed desktop Chromium native window minimize/restore through Browser.setWindowBounds; actual visibilityState and trusted edges measured; no synthetic visibility event';
     await session.detach();
    }
    assert.equal(probe.foreground.boot,baselineGeometry.boot);assert(probe.foreground.sameCanvas);
   }
   if(shot==='05_suspend') {
    probe.states=await frame.evaluate(async()=>{const contexts=window.__WI_LIFECYCLE_AUDIO__.contexts.filter(ctx=>!ctx.__wiControl);await Promise.all(contexts.map(ctx=>ctx.suspend()));return contexts.map(ctx=>ctx.state);});
    assert(probe.states.length>0&&probe.states.every(state=>state==='suspended'),'Actual game context did not suspend');
    probe.mechanism='explicit AudioContext.suspend fault injection; no OS audio interruption claim';
   }
   if(shot==='06_resume') {
    await tapName();
    probe.domValue=await frame.locator('input[type="text"]:not([disabled])').inputValue();assert.equal(probe.domValue,'Mira','Name lost after blur/rotation/visibility');
    probe.audio=await audioOutput(true);
    assert(probe.audio.states.every(state=>state==='running')&&probe.audio.peakRms>0.0001&&probe.audio.controlRms>0.0001,'Trusted tap did not restore actual game audio output after suspension');
    await frame.locator('input[type="text"]:not([disabled])').evaluate(element=>element.blur());
   }
   probe.geometry=await geometry();
   await page.screenshot({path:join(output,`${shot}.png`)});
   await frame.evaluate(()=>{window.__WI_QA_SHOT__=null;});
  }
  result=await frame.evaluate(()=>window.__WI_RESULT__??null);
  if(result) break;
  await page.waitForTimeout(40);
 }
 assert(result?.passed===true&&result.aborted===false&&result.failures.length===0,JSON.stringify(result));
 assert(result.script==='res://qa/scripts/lifecycle_input_audio.json'&&result.steps_total===expected&&result.steps_run===expected,'Incomplete or wrong game result');
 runtime=await frame.evaluate(()=>({boot:window.__WI_LIFECYCLE_BOOT__,events:window.__WI_LIFECYCLE_EVENTS__,audioStates:window.__WI_LIFECYCLE_AUDIO__.states,gameEvents:window.__WI_QA_EVENTS__}));
 assert(runtime.events.filter(event=>event.type==='touchstart').length>=6&&runtime.events.filter(event=>event.type.startsWith('touch')).every(event=>event.trusted),'Missing trusted browser touch');
 assert.equal(runtime.boot,baselineGeometry.boot);
 assert(diagnostics.filter(row=>!isKnownRendererDiagnostic(row)).length===0,`Unexpected diagnostics: ${JSON.stringify(diagnostics)}`);
 assert(requests.every(request=>request.status===200),'Failed export request');
 console.log(`LIFECYCLE_INPUT_AUDIO_RESULT: PASS (${profile}, ${hosting}; visibility ${probes.find(probe=>probe.name==='04_visibility').verified?'observed':'unproven'}; browser-policy unlock ${probes[0].browserPolicyUnlockProven?'observed':'unproven'})`);
} catch(error) {failure=String(error);console.error(failure);}
finally {
 if(frame&&!runtime) runtime=await frame.evaluate(()=>({boot:window.__WI_LIFECYCLE_BOOT__,events:window.__WI_LIFECYCLE_EVENTS__,audioStates:window.__WI_LIFECYCLE_AUDIO__?.states,gameEvents:window.__WI_QA_EVENTS__??[]})).catch(()=>null);
 const buildPckSha256=createHash('sha256').update(await readFile(join(root,'index.pck'))).digest('hex');
 await writeFile(join(output,'console.json'),JSON.stringify(consoleLog,null,2));
 await writeFile(join(output,'result.json'),JSON.stringify({passed:!failure,failure,profile,hosting,headed,browser:browser?.version(),host:origin,topUrl:page?.url(),gameUrl:frame?.url(),autoplayPolicy:'document-user-activation-required',visibilityVerified:probes.find(probe=>probe.name==='04_visibility')?.verified??false,browserPolicyUnlockVerified:probes[0]?.browserPolicyUnlockProven??false,buildPckSha256,emulated:true,scope:'Exported Godot DOM input/blur, viewport changes, measured desktop-tab visibility, actual game AudioContext suspend and trusted-tap output recovery. Physical keyboards/phones, OS suspension and actual itch remain unproven.',result,probes,runtime,touches,diagnostics,requests},null,2));
 await browser?.close();server.close();
}
if(failure) process.exitCode=1;
