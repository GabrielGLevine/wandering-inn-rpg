// Real same-origin page reload. Browser profiles emulate devices; no claim of
// physical backgrounding, process eviction, or interruption-caused corruption.
import { chromium } from 'playwright';
import { stageResultFailures } from './lifecycle_result.mjs';
import { createServer } from 'node:http';
import { readFile, mkdir, writeFile } from 'node:fs/promises';
import { dirname, resolve, extname, join, sep } from 'node:path';
import { fileURLToPath } from 'node:url';
const here = dirname(fileURLToPath(import.meta.url));
const game = resolve(here, '../..');
const root = join(game, 'build/web');
const profile = process.argv[2] ?? 'iphone';
const profiles = {
 iphone: {viewport: {width: 844, height: 390}, userAgent: 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X) AppleWebKit/605.1.15 Version/17.5 Mobile/15E148 Safari/604.1'},
 android: {viewport: {width: 915, height: 412}, userAgent: 'Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 Chrome/126.0.0.0 Mobile Safari/537.36'},
};
if (!profiles[profile]) throw new Error('Expected iphone or android');
const output = join(game, 'qa_output', `lifecycle_${profile}`);
await mkdir(output, {recursive: true});
const mime = {'.html':'text/html','.js':'text/javascript','.wasm':'application/wasm','.pck':'application/octet-stream','.png':'image/png'};
const requests = [], diagnostics = [], stages = [], consoleLog = [];
const server = createServer(async (req, res) => {
 const name = decodeURIComponent(new URL(req.url, 'http://localhost').pathname);
 const path = resolve(root, '.' + (name === '/' ? '/index.html' : name));
 if (!path.startsWith(root + sep)) {res.writeHead(403).end(); return;}
 try {const bytes = await readFile(path); res.writeHead(200, {'Content-Type':mime[extname(path)] ?? 'application/octet-stream'}).end(bytes); requests.push({name,status:200});}
 catch {res.writeHead(404).end(); requests.push({name,status:404});}
});
await new Promise((r) => server.listen(0,'127.0.0.1',r));
const origin = `http://127.0.0.1:${server.address().port}`;
let browser, failure = null;
try {
 browser = await chromium.launch({args:['--single-process']});
 const context = await browser.newContext({...profiles[profile], hasTouch:true, isMobile:true, deviceScaleFactor:1});
 const page = await context.newPage();
 page.on('console', msg => {
  consoleLog.push({type:msg.type(),text:msg.text()});
  if (['error','warning'].includes(msg.type()) || /SCRIPT ERROR|Parse Error|ERROR:|WARNING/.test(msg.text())) diagnostics.push({type:msg.type(),text:msg.text()});
 });
 page.on('pageerror', err => diagnostics.push({type:'pageerror',text:String(err)}));
 await page.addInitScript(() => {
  const stage = sessionStorage.getItem('wiLifecycleStage') ?? 'save';
  window.__WI_QA__ = {script:`res://qa/scripts/lifecycle_${stage}.json`,seed:'9'};
  window.__WI_LIFECYCLE_BOOT__ = crypto.randomUUID();
  window.__WI_LIFECYCLE_TOUCHES__ = [];
  for (const type of ['touchstart','touchend','touchcancel']) document.addEventListener(type, e => window.__WI_LIFECYCLE_TOUCHES__.push({type,trusted:e.isTrusted,time:performance.now()}), {capture:true,passive:true});
 });
 async function runStage(name) {
  const expected = JSON.parse(await readFile(join(game, `qa/scripts/lifecycle_${name}.json`), 'utf8')).steps.length;
  const until = Date.now()+120000;
  let result;
  while (Date.now()<until) {
   const req = await page.evaluate(() => window.__WI_QA_TOUCH_REQ__ ?? null);
   if(req) {
    await page.evaluate(() => {window.__WI_QA_TOUCH_REQ__=null;});
    await page.touchscreen.tap(req.x,req.y);
    await page.evaluate(() => {window.__WI_QA_TOUCH_DONE__=(window.__WI_QA_TOUCH_DONE__ || 0)+1;});
   }
   const shot = await page.evaluate(() => window.__WI_QA_SHOT__ ?? null);
   if(shot) {await page.screenshot({path:join(output,`${name}_${shot}.png`)}); await page.evaluate(() => {window.__WI_QA_SHOT__=null;});}
   result = await page.evaluate(() => window.__WI_RESULT__ ?? null);
   if(result) break;
   await page.waitForTimeout(40);
  }
  const runtime = await page.evaluate(() => ({boot:window.__WI_LIFECYCLE_BOOT__,origin:location.origin,touches:window.__WI_LIFECYCLE_TOUCHES__,events:window.__WI_QA_EVENTS__ ?? []}));
  stages.push({name,result,runtime});
  const resultFailures = stageResultFailures(result, name, expected);
  if(resultFailures.length) throw new Error(`${name}: ${resultFailures.join('; ')}: ${JSON.stringify(result)}`);
  if(runtime.touches.filter(e => e.type==='touchstart').length<3 || runtime.touches.some(e=>!e.trusted)) throw new Error(`${name}: missing trusted browser touch`);
  if(runtime.events.filter(e=>e.type==='qa_touch').length<3 || runtime.events.filter(e=>e.type==='qa_touch').some(e=>e.payload.real!==true)) throw new Error(`${name}: emulated engine touch fallback`);
  console.log(`QA_RESULT: PASS lifecycle_${name} (${profile}, emulated Chromium)`);
 }
 // Read the browser's actual persisted IDBFS record, never flush it ourselves.
 async function persistedManual(injectMalformed = false) {
  return page.evaluate(async (inject) => {
   for(const info of await indexedDB.databases()) {
    const db = await new Promise((resolve,reject)=>{const q=indexedDB.open(info.name);q.onsuccess=()=>resolve(q.result);q.onerror=()=>reject(q.error);});
    try {
     if(!db.objectStoreNames.contains('FILE_DATA')) continue;
     const records = await new Promise((resolve,reject)=>{
      const tx=db.transaction('FILE_DATA','readonly'), store=tx.objectStore('FILE_DATA');
      const keys=store.getAllKeys(), values=store.getAll();
      tx.oncomplete=()=>resolve(keys.result.map((key,i)=>({key,value:values.result[i]})));tx.onerror=()=>reject(tx.error);
     });
     const manual=records.find(r=>String(r.key).endsWith('/saves/manual.json'));
     if(!manual) continue;
     const text=new TextDecoder().decode(manual.value.contents);
     const data=JSON.parse(text);
     if(inject) await new Promise((resolve,reject)=>{
      const tx=db.transaction('FILE_DATA','readwrite');
      tx.objectStore('FILE_DATA').put({...manual.value,timestamp:new Date(Date.now()+1000),contents:new TextEncoder().encode('{malformed QA fixture')},String(manual.key).replace(/manual\.json$/,'auto.json'));
      tx.oncomplete=resolve;tx.onerror=()=>reject(tx.error);
     });
     return {database:info.name,key:manual.key,state:data.state,bytes:text,malformedInjected:inject};
    } finally {db.close();}
   }
   return null;
  },injectMalformed);
 }
 await page.goto(origin+'/index.html');
 await runStage('save');
 let durable;
 for(let i=0;i<100;i++) {durable=await persistedManual(); if(durable?.state.player_cell?.join(',')==='8,6') break; await page.waitForTimeout(100);}
 if(durable?.state.player_cell?.join(',')!=='8,6') throw new Error('Saved cell did not reach browser IndexedDB');
 await writeFile(join(output,'persisted_manual.json'),JSON.stringify(durable,null,2));
 await page.evaluate(()=>sessionStorage.setItem('wiLifecycleStage','reload'));
 await page.reload();
 await runStage('reload');
 const injected=await persistedManual(true);
 if(injected?.bytes!==durable.bytes) throw new Error('Recovery setup changed the valid manual save');
 await page.evaluate(()=>sessionStorage.setItem('wiLifecycleStage','recovery'));
 await page.reload();
 await runStage('recovery');
 const final=await persistedManual();
 if(final?.bytes!==durable.bytes) throw new Error('Recovery changed the valid manual save');
 if(new Set(stages.map(s=>s.runtime.boot)).size!==3 || stages.some(s=>s.runtime.origin!==origin)) throw new Error('Expected three distinct boots at one origin');
 // Match the existing browser suite's narrow renderer-only warning exception.
 const unexpected=diagnostics.filter(d=>d.type!=='warning' || !/^\[\.WebGL-0x[0-9a-fA-F]+\]GL Driver Message \(OpenGL, Performance, GL_CLOSE_PATH_NV, High\): GPU stall due to ReadPixels(?: \(this message will no longer repeat\))?$/.test(d.text));
 if(unexpected.length) throw new Error(`Unexpected diagnostics: ${JSON.stringify(unexpected)}`);
 if(requests.some(r=>r.status!==200)) throw new Error('Failed HTTP request');
} catch(err) {failure=String(err); console.error(failure);}
finally {
 await writeFile(join(output,'console.json'),JSON.stringify(consoleLog,null,2));
 await writeFile(join(output,'result.json'),JSON.stringify({passed:!failure,failure,profile,emulated:true,stages,diagnostics,requests,scope:'Two real page.reload calls in one browser context and origin; completed manual save restored; injected malformed autosave skipped. Physical suspension, eviction and interruption-caused corruption remain unproven.'},null,2));
 await browser?.close(); server.close();
}
if(failure) process.exitCode=1;
else console.log('LIFECYCLE_RESULT: PASS');
