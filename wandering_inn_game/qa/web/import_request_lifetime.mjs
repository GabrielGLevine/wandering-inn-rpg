// Delayed real FileReader fault injection after trusted Import-row taps.
// Empty chooser selection is a cancellation surrogate, not physical OS Back.
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
const profile = process.argv[2] ?? 'iphone';
const expectStale = process.argv.includes('--expect-stale');
const profiles = {iphone: {width: 844, height: 390}, android: {width: 915, height: 412}};
assert(profiles[profile], 'Expected iphone or android');
const output = join(game, 'qa_output', `import_request_lifetime_${profile}`);
await mkdir(output, {recursive: true});
const script = JSON.parse(await readFile(join(game, 'qa/scripts/import_request_lifetime.json'), 'utf8'));
const fixture = JSON.parse(await readFile(join(game, 'qa/fixtures/near_pallass.json'), 'utf8'));
const staleSave = structuredClone(fixture);
staleSave.state.gold = 777;
const validText = JSON.stringify(fixture);
const choices = [
 ['wi-delayed-cancel.json', JSON.stringify(staleSave)],
 null,
 ['wi-delayed-reopen.json', JSON.stringify(staleSave)],
 ['wi-delayed-replacement-empty.json', ''],
 ['wi-delayed-close.json', JSON.stringify(staleSave)],
 ['wi-valid.json', validText],
];
const diagnostics = [], consoleLog = [], requests = [], checkpoints = [], chooserLog = [];
const mime = {'.html':'text/html', '.js':'text/javascript', '.wasm':'application/wasm', '.pck':'application/octet-stream', '.png':'image/png'};
const server = createServer(async (req, res) => {
 const name = decodeURIComponent(new URL(req.url, 'http://localhost').pathname);
 const path = resolve(root, '.' + (name === '/' ? '/index.html' : name));
 if (!path.startsWith(root + sep)) {res.writeHead(403).end(); return;}
 try {
  const bytes = await readFile(path);
  res.writeHead(200, {'Content-Type':mime[extname(path)] ?? 'application/octet-stream'}).end(bytes);
  requests.push({name, status:200});
 } catch {res.writeHead(404).end(); requests.push({name, status:404});}
});
await new Promise(done => server.listen(0, '127.0.0.1', done));
const origin = `http://127.0.0.1:${server.address().port}`;
let browser, page, result, baseline, runtime, failure = null, chooserFailure = null;

async function persistedManual() {
 return page.evaluate(async () => {
  for (const info of await indexedDB.databases()) {
   const db = await new Promise((done, fail) => {
    const request = indexedDB.open(info.name);
    request.onsuccess = () => done(request.result);
    request.onerror = () => fail(request.error);
   });
   try {
    if (!db.objectStoreNames.contains('FILE_DATA')) continue;
    const records = await new Promise((done, fail) => {
     const tx = db.transaction('FILE_DATA', 'readonly'), store = tx.objectStore('FILE_DATA');
     const keys = store.getAllKeys(), values = store.getAll();
     tx.oncomplete = () => done(keys.result.map((key, i) => ({key, value:values.result[i]})));
     tx.onerror = () => fail(tx.error);
    });
    const manual = records.find(record => String(record.key).endsWith('/saves/manual.json'));
    if (manual) return {database:info.name, key:manual.key, bytes:new TextDecoder().decode(manual.value.contents)};
   } finally {db.close();}
  }
  return null;
 });
}

try {
 browser = await chromium.launch({args:['--single-process']});
 const context = await browser.newContext({viewport:profiles[profile], hasTouch:true, isMobile:true, deviceScaleFactor:1});
 page = await context.newPage();
 page.on('console', message => {
  const row = {type:message.type(), text:message.text()};
  consoleLog.push(row);
  if (['error', 'warning'].includes(row.type) || /SCRIPT ERROR|Parse Error|ERROR:|WARNING/.test(row.text)) diagnostics.push(row);
 });
 page.on('pageerror', error => diagnostics.push({type:'pageerror', text:String(error)}));
 page.on('filechooser', async chooser => {
  try {
   const index = chooserLog.length;
   assert(index < choices.length, 'Unexpected extra file chooser');
   const choice = choices[index];
   chooserLog.push({index, name:choice?.[0] ?? null, mechanism:choice ? 'automation-selected file after trusted tap' : 'automation empty-selection cancellation surrogate'});
   await chooser.setFiles(choice ? {name:choice[0], mimeType:'application/json', buffer:Buffer.from(choice[1])} : []);
  } catch (error) {chooserFailure = String(error);}
 });
 await page.addInitScript(() => {
  window.__WI_QA__ = {script:'res://qa/scripts/import_request_lifetime.json', seed:'9'};
  window.__WI_IMPORT_CONTACTS__ = [];
  for (const type of ['touchstart', 'touchend', 'touchcancel']) document.addEventListener(type, event => {
   window.__WI_IMPORT_CONTACTS__.push({type, trusted:event.isTrusted, time:performance.now()});
  }, {capture:true, passive:true});
  window.__WI_IMPORT_READS__ = {pending:[], delivered:[], aborted:[]};
  const NativeReader = FileReader;
  window.FileReader = class extends NativeReader {
   readAsText(file, ...args) {
    if (file.name.startsWith('wi-delayed-')) {
     const completion = this.onload;
     this.onload = () => {
      // Retain the completion even if application cleanup removes handlers.
      window.__WI_IMPORT_READS__.pending.push({name:file.name, deliver:() => {
       window.__WI_IMPORT_READS__.delivered.push(file.name);
       completion.call(this, new ProgressEvent('load'));
      }});
     };
     const abort = this.abort.bind(this);
     this.abort = () => {window.__WI_IMPORT_READS__.aborted.push(file.name); return abort();};
    }
    return super.readAsText(file, ...args);
   }
  };
 });
 await page.goto(origin + '/index.html');
 const deadline = Date.now() + 120000;
 while (Date.now() < deadline) {
  if (chooserFailure) throw new Error(chooserFailure);
  const tap = await page.evaluate(() => window.__WI_QA_TOUCH_REQ__ ?? null);
  if (tap) {
   await page.evaluate(() => {window.__WI_QA_TOUCH_REQ__ = null;});
   await page.touchscreen.tap(tap.x, tap.y);
   await page.evaluate(() => {window.__WI_QA_TOUCH_DONE__ = (window.__WI_QA_TOUCH_DONE__ || 0) + 1;});
  }
  const shot = await page.evaluate(() => window.__WI_QA_SHOT__ ?? null);
  if (shot) {
   if (shot === '00_baseline') {
    for (let i = 0; i < 100; i++) {
     baseline = await persistedManual();
     if (baseline && JSON.parse(baseline.bytes).state.gold === 60) break;
     await page.waitForTimeout(100);
    }
    assert(baseline && JSON.parse(baseline.bytes).state.gold === 60, 'No durable valid baseline manual save');
   }
   if (shot.endsWith('_read_ready')) await page.waitForFunction(() => window.__WI_IMPORT_READS__.pending.length === 1, null, {timeout:10000});
   if (shot === '02_reopen_release') await page.waitForFunction(() => window.__WI_IMPORT_READS__.pending.length === 2, null, {timeout:10000});
   if (shot.endsWith('_release') || shot === '02_replacement_finish') {
    await page.evaluate(() => {
     const pending = window.__WI_IMPORT_READS__.pending.shift();
     if (!pending) throw new Error('No delayed read to release');
     pending.deliver();
    });
   }
   const persisted = await persistedManual();
   checkpoints.push({name:shot, persisted});
   if (shot.endsWith('_preserved')) assert.equal(persisted?.bytes, baseline.bytes, `${shot}: durable manual bytes changed`);
   await page.screenshot({path:join(output, `${shot}.png`)});
   await page.evaluate(() => {window.__WI_QA_SHOT__ = null;});
  }
  result = await page.evaluate(() => window.__WI_RESULT__ ?? null);
  if (result) break;
  await page.waitForTimeout(40);
 }
 assert(result, 'No completed game result');
 runtime = await page.evaluate(() => ({events:window.__WI_QA_EVENTS__, contacts:window.__WI_IMPORT_CONTACTS__, reads:{delivered:window.__WI_IMPORT_READS__.delivered, aborted:window.__WI_IMPORT_READS__.aborted}}));
 assert(diagnostics.filter(row => !isKnownRendererDiagnostic(row)).length === 0, `Unexpected diagnostics: ${JSON.stringify(diagnostics)}`);
 assert(requests.every(row => row.status === 200), 'Failed export request');
 const imported = runtime.events.filter(event => event.type === 'game_loaded' && event.payload.reason === 'import');
 if (expectStale) {
  const until = Date.now() + 10000;
  let durable;
  do {durable = await persistedManual(); if (durable && JSON.parse(durable.bytes).state.gold === 777) break; await page.waitForTimeout(100);} while (Date.now() < until);
  assert(result.passed === false && imported.length > 0 && durable && JSON.parse(durable.bytes).state.gold === 777, 'Expected stale import did not corrupt the live/durable state');
  console.log('IMPORT_REQUEST_REPRODUCED: PASS (delayed selected file accepted after reopen/cancel)');
 } else {
  assert(result.passed === true && result.aborted === false && result.failures.length === 0, JSON.stringify(result));
  assert(result.script === 'res://qa/scripts/import_request_lifetime.json' && result.steps_run === script.steps.length && result.steps_total === script.steps.length, 'Incomplete or wrong game result');
  assert.equal(chooserLog.length, choices.length, 'Expected every actual chooser');
  assert.equal(imported.length, 1, 'Only the final current request may import');
  const snapshots = runtime.events.filter(event => event.type === 'qa_state_dump');
  assert.deepEqual(snapshots.map(event => event.payload.label), ['baseline', 'after_cancel', 'after_reopen', 'after_close', 'after_valid_import']);
  for (const snapshot of snapshots.slice(1)) assert.deepEqual(snapshot.payload.snapshot, snapshots[0].payload.snapshot, `${snapshot.payload.label}: live state changed`);
  assert.deepEqual(runtime.reads.delivered, ['wi-delayed-cancel.json', 'wi-delayed-reopen.json', 'wi-delayed-replacement-empty.json', 'wi-delayed-close.json']);
  assert(runtime.contacts.filter(row => row.type === 'touchstart').length >= 9 && runtime.contacts.every(row => row.trusted), 'Missing trusted browser touch');
  console.log('IMPORT_REQUEST_RESULT: PASS');
 }
} catch (error) {failure = String(error); console.error(failure);}
finally {
 if (page && !runtime) runtime = await page.evaluate(() => ({events:window.__WI_QA_EVENTS__ ?? [], contacts:window.__WI_IMPORT_CONTACTS__ ?? []})).catch(() => null);
 const buildPckSha256 = createHash('sha256').update(await readFile(join(root, 'index.pck'))).digest('hex');
 await writeFile(join(output, 'console.json'), JSON.stringify(consoleLog, null, 2));
 await writeFile(join(output, 'result.json'), JSON.stringify({passed:!failure, failure, expectStale, profile, browser:browser?.version(), host:origin, buildPckSha256, emulated:true, scope:'Actual exported Import-row browser taps; real FileReader completions deliberately delayed. Local direct hosting, Chromium viewport emulation, automated chooser selection/cancellation surrogate. No physical OS picker/Back, Safari or itch proof.', result, runtime, baseline, checkpoints, chooserLog, diagnostics, requests}, null, 2));
 await browser?.close();
 server.close();
}
if (failure) process.exitCode = 1;
