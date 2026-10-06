// Startup is separate from the driver's four-second per-gesture service budget.
export function runnerStartupInit() {
 window.__WI_QA_RUNNER_READY__ = false;
 window.__WI_QA_STARTUP__ = {initialized_at_ms: performance.now(), ready_at_ms: null};
}

export function startupDelay(args) {
 const raw = args.find(arg => arg.startsWith('--startup-delay-ms='))?.split('=')[1] ?? '0';
 const delay = Number(raw);
 if (!/^\d+$/.test(raw) || !Number.isInteger(delay) || delay > 20000) throw new Error('--startup-delay-ms must be 0..20000');
 return delay;
}

// Call only at pump entry, after navigation, orientation and transport setup.
export async function releaseRunnerStartup(target, {delayMs = 0, withhold = false} = {}) {
 await target.evaluate(() => {
  if (window.__WI_QA__?.wait_for_runner_ready !== true || window.__WI_QA_RUNNER_READY__ !== false) throw new Error('Runner startup was not initialized for this document');
  window.__WI_QA_STARTUP__.prepared_at_ms = performance.now();
 });
 if (delayMs) await new Promise(resolve => setTimeout(resolve, delayMs));
 return target.evaluate(({delayMs, withhold}) => {
  window.__WI_QA_STARTUP__.delay_ms = delayMs;
  if (!withhold) {
   window.__WI_QA_STARTUP__.ready_at_ms = performance.now();
   window.__WI_QA_RUNNER_READY__ = true;
  }
  return window.__WI_QA_STARTUP__;
 }, {delayMs, withhold});
}
