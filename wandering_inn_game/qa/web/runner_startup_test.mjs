import assert from 'node:assert/strict';
import { runnerStartupInit, releaseRunnerStartup, startupDelay } from './runner_startup.mjs';

let allowEngine;
let engineGate = new Promise(resolve => {allowEngine = resolve;});
const target = {
 evaluate: async (fn, arg) => fn(arg),
 waitForFunction: async (fn, arg, options) => {
  assert.equal(options.timeout, 30000, 'initial draw wait must be bounded');
  await engineGate;
  assert(fn());
 },
};
globalThis.document = {querySelector: () => ({width: 1280, height: 720, getBoundingClientRect: () => ({width: 640, height: 360})})};
globalThis.window = {__WI_QA__: {wait_for_runner_ready: true}};
runnerStartupInit();
const release = releaseRunnerStartup(target, {delayMs: 60});
await new Promise(resolve => setTimeout(resolve, 10));
assert.equal(window.__WI_QA_RUNNER_READY__, false, 'navigation alone must not release before engine draw');
window.__WI_QA_ENGINE_READY__ = {initial_draw_complete: true, rendered_at_ms: performance.now()};
allowEngine();
await new Promise(resolve => setTimeout(resolve, 10));
assert.equal(window.__WI_QA_RUNNER_READY__, false, 'preparation must not release delayed startup');
const timing = await release;
assert.equal(window.__WI_QA_RUNNER_READY__, true);
assert(timing.ready_at_ms - timing.prepared_at_ms >= 50);
runnerStartupInit();
assert.equal(window.__WI_QA_RUNNER_READY__, false, 'each document/reload resets readiness');
window.__WI_QA_ENGINE_READY__ = {initial_draw_complete: true};
await releaseRunnerStartup(target, {withhold: true});
assert.equal(window.__WI_QA_RUNNER_READY__, false);
assert.equal(window.__WI_QA_STARTUP__.ready_at_ms, null);
runnerStartupInit();
const missingDraw = {...target, waitForFunction: async () => {throw new Error('initial draw timeout');}};
await assert.rejects(releaseRunnerStartup(missingDraw), /initial draw timeout/);
assert.equal(window.__WI_QA_RUNNER_READY__, false, 'missing initial draw must not release QA');
window.__WI_QA__.wait_for_runner_ready = false;
await assert.rejects(releaseRunnerStartup(target), /not initialized/);
assert.equal(startupDelay([]), 0);
assert.equal(startupDelay(['--startup-delay-ms=6000']), 6000);
for (const value of ['-1', '20001', 'NaN', '1.5', '']) assert.throws(() => startupDelay([`--startup-delay-ms=${value}`]));
delete globalThis.window;
delete globalThis.document;
console.log('RUNNER_STARTUP_TEST: PASS');
