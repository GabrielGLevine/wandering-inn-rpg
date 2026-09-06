// Drive the Godot web export through a QA script under headless Chromium.
// Usage: node run_web_qa.mjs <script-name> [seed] [--touch]
// Serves build/web/ via a REAL local HTTP server (random free port) -- see
// "Why a real server" below -- with window.__WI_QA__ set via an init script,
// polls for screenshot requests (__WI_QA_SHOT__) and the final result
// (__WI_RESULT__). All game-state assertions run in-engine; this runner is
// the server, the renderer, the screenshot hands, the console/error capture,
// and the audio-worklet smoke check.
//
// Why a real server (issue #105): the previous runner served build/web via
// Playwright route interception (page.route + route.fulfill) on a fake
// "http://localhost/" host with no real listener behind it. AudioWorklet
// module fetches (AudioContext.audioWorklet.addModule(...)) run in a
// separate worklet execution context whose network requests bypass Chromium
// page-level request routing entirely -- so under interception, every
// worklet module fetch silently failed, every web QA run logged "Failed to
// create PositionWorklet" / "Unable to load a worklet's module", and every
// web run was audio-silent, in every version. Verified this session against
// a real python http.server: same build, zero worklet errors. Interception
// is not needed for anything else here -- window.__WI_QA__ is set via
// addInitScript (runs before any page script, real server or not),
// __WI_QA_SHOT__/__WI_RESULT__ are read via page.evaluate (page-scope, not
// network), and screenshots are taken via page.screenshot. So interception
// is dropped entirely, not kept for anything.
//
// Worklet-response tracking is done via the HTTP SERVER's own request log,
// not Playwright's page.on('response')/CDP Network domain: verified this
// session (page.on('request'/'response'), a CDP Network.enable session, and
// page.on('requestfailed') were all tried against a real server) that
// AudioWorklet module fetches are NOT observable through any Playwright- or
// CDP-visible network event in headless Chromium -- they never fire,
// despite the request demonstrably reaching the server (confirmed via the
// server's own access log) and succeeding. The server's own log is the only
// reliable place to see them, so that's what the audio smoke below reads.
import { readFile } from "node:fs/promises";
import { join, dirname, extname, resolve, sep } from "node:path";
import { fileURLToPath } from "node:url";
import { createServer } from "node:http";
import { mkdir, rm, writeFile } from "node:fs/promises";
import { chromium } from "playwright";

const args = process.argv.slice(2);
const touchMode = args.includes("--touch");
// #503 device presets: EMULATED phone contexts (Chromium + a phone UA/viewport/
// touch). They are labelled emulated in every log line -- a Playwright run is
// never evidence about real iPhone Safari or Android Chrome.
const DEVICE_PRESETS = {
	desktop: { viewport: { width: 640, height: 400 }, isMobile: false, label: "desktop Chromium 640x400" },
	iphone: {
		viewport: { width: 844, height: 390 },
		userAgent: "Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Mobile/15E148 Safari/604.1",
		isMobile: true,
		label: "EMULATED iPhone-Safari UA on Chromium 844x390 landscape",
	},
	android: {
		viewport: { width: 915, height: 412 },
		userAgent: "Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Mobile Safari/537.36",
		isMobile: true,
		label: "EMULATED Android-Chrome UA on Chromium 915x412 landscape",
	},
};
const deviceArg = args.find((a) => a.startsWith("--device="));
const deviceName = deviceArg ? deviceArg.slice("--device=".length) : "desktop";
const device = DEVICE_PRESETS[deviceName];
if (!device) {
	console.error(`unknown --device=${deviceName} (known: ${Object.keys(DEVICE_PRESETS).join(", ")})`);
	process.exit(2);
}
// --portrait-entry (#503 orientation policy): open the page in PORTRAIT, prove
// the rotate overlay is showing (CSS `(orientation:portrait) and
// (pointer:coarse)` in export_presets html/head_include), then rotate to
// landscape WITHOUT reloading and let the script play on -- progress kept.
const portraitEntry = args.includes("--portrait-entry");
const positional = args.filter((a) => !a.startsWith("--"));
const scriptName = positional[0];
const seedArg = positional[1];
if (!scriptName) {
	console.error("usage: node run_web_qa.mjs <script-name> [seed] [--touch]");
	process.exit(2);
}

const here = dirname(fileURLToPath(import.meta.url));
const projRoot = resolve(here, "../..");
const webRoot = join(projRoot, "build/web");
const outDir = join(projRoot, "qa_output", `web_${scriptName}`);
const TIMEOUT_MS = 120_000;

const MIME = {
	".html": "text/html",
	".js": "text/javascript",
	".wasm": "application/wasm",
	".pck": "application/octet-stream",
	".png": "image/png",
	".ico": "image/x-icon",
	".json": "application/json",
};

// Console/pageerror lines that mean "the AudioWorklet never actually loaded"
// -- the exact symptoms of the fake-host bug this rework fixes (issue #105).
const WORKLET_ERROR_PATTERNS = ["Failed to create PositionWorklet", "Unable to load a worklet"];

function isWorkletError(text) {
	return WORKLET_ERROR_PATTERNS.some((p) => text.includes(p));
}

/// Real local HTTP server for build/web/, correct MIME per extension, bound
/// to a random free port (listen(0)). Logs every request (path + status)
/// into `requestLog` -- the audio smoke's only reliable source for "did the
/// worklet modules actually load" (see file header).
function startServer(root, requestLog) {
	return new Promise((res) => {
		const server = createServer(async (req, response) => {
			const url = new URL(req.url, "http://localhost");
			let pathName = decodeURIComponent(url.pathname);
			if (pathName === "/") pathName = "/index.html";
			const relPath = pathName.replace(/^\/+/, "");
			const filePath = join(root, relPath);
			// Path-traversal guard: resolved path must stay under webRoot.
			if (!filePath.startsWith(root + sep) && filePath !== root) {
				requestLog.push({ path: pathName, status: 403 });
				response.writeHead(403);
				response.end("forbidden");
				return;
			}
			try {
				const body = await readFile(filePath);
				response.writeHead(200, { "Content-Type": MIME[extname(filePath)] ?? "application/octet-stream" });
				response.end(body);
				requestLog.push({ path: pathName, status: 200 });
			} catch {
				response.writeHead(404);
				response.end("not found");
				requestLog.push({ path: pathName, status: 404 });
			}
		});
		server.listen(0, "127.0.0.1", () => res(server));
	});
}

await rm(outDir, { recursive: true, force: true });
await mkdir(outDir, { recursive: true });

const requestLog = [];
const server = await startServer(webRoot, requestLog);
const port = server.address().port;
const BASE_URL = `http://127.0.0.1:${port}/`;

const browser = await chromium.launch({ args: ["--single-process"] });
// deviceScaleFactor pinned to 1: without it, headless Chromium on some CI
// runners reports an absurd devicePixelRatio, and Godot's ImageLoaderSVG then
// rasterizes engine-theme SVGs at gigantic canvases (the runner-only
// "51500x51500" WARNING caught by the public repo's first CI run).
// hasTouch (--touch mode, issue #105, the #106 prerequisite): configures the
// Chromium context so page.touchscreen.tap(...) dispatches real touch events
// the browser accepts -- without it Playwright refuses touchscreen calls
// outright. This is groundwork only: the QA DSL's click_* actions
// (qa/test_driver.gd's `_inject_mouse_click`) push InputEventMouseButton
// directly into the SceneTree root's viewport -- an engine-internal call
// that never touches the browser/DOM at all, identically whether this flag
// is set or not, so no existing DSL script exercises the browser's real
// touch pipeline. What --touch mode DOES prove: (a) the harness can stand
// up a genuine touch-capable browser context against the real-server build
// without anything regressing (every existing click_* script, driven
// engine-internally as always, must still pass -- see mouse_loop below),
// and (b) a REAL page.touchscreen.tap() lands on the canvas and reaches
// Godot's web runtime without a page/console error, which is only
// meaningful because project.godot carries no `emulate_mouse_from_touch`
// override (confirmed absent -- Godot's default `true` applies), so a real
// device touch there auto-emulates a mouse event the exact same
// mouse-consuming code (world.gd, hotbar, etc.) already handles. Issue #106
// builds the actual `touch_*` DSL tier (real per-step page.touchscreen.tap
// calls at live element coordinates) on top of this.
const landscapeViewport = { ...device.viewport };
const startViewport = portraitEntry ? { width: device.viewport.height, height: device.viewport.width } : landscapeViewport;
const page = await browser.newPage({
	viewport: startViewport,
	deviceScaleFactor: 1,
	hasTouch: touchMode || device.isMobile,
	isMobile: device.isMobile,
	...(device.userAgent ? { userAgent: device.userAgent } : {}),
});
console.log(`MODE: ${device.label}${touchMode ? " + real Playwright touch servicing (--touch)" : ""}${portraitEntry ? " + portrait entry then rotate" : ""} -- EMULATED; not evidence about real hardware`);

// Permanent console + page-error capture (issue #105: this session's
// throwaway "print everything" patch, made permanent and tidied). QA_-
// prefixed lines are the existing script-progress log; every console ERROR
// and every uncaught page error is now ALSO surfaced, not swallowed --
// among them the exact worklet-failure text the audio smoke below checks.
const capturedErrors = [];
page.on("console", (msg) => {
	const text = msg.text();
	if (text.startsWith("QA_")) {
		console.log(`[game] ${text}`);
		return;
	}
	if (msg.type() === "error") {
		console.log(`[console:error] ${text}`);
		capturedErrors.push(text);
	}
});
page.on("pageerror", (err) => {
	const text = String(err);
	console.log(`[pageerror] ${text}`);
	capturedErrors.push(text);
});

await page.addInitScript(
	({ name, seed }) => {
		window.__WI_QA__ = { script: `res://qa/scripts/${name}.json`, seed: seed ?? "" };
	},
	{ name: scriptName, seed: seedArg ?? "" },
);

// Output-level audio probe (silence diagnosis 2026-07-13): taps every
// AudioNode.connect() into an AnalyserNode wherever the target is the
// context destination, so the run can measure REAL rendered samples --
// the worklet-fetch smoke proves loading, this proves OUTPUT. Headless
// Chromium still processes the WebAudio graph (null sink), so RMS > 0
// here means genuinely audible in a real browser.
await page.addInitScript(() => {
	window.__WI_AUDIO_TAPS__ = [];
	window.__WI_CTX_STATES__ = [];
	const origConnect = AudioNode.prototype.connect;
	AudioNode.prototype.connect = function (...args) {
		try {
			const target = args[0];
			const ctx = this.context;
			if (target === ctx.destination) {
				const analyser = ctx.createAnalyser();
				analyser.fftSize = 2048;
				origConnect.call(this, analyser);
				origConnect.call(analyser, ctx.destination);
				window.__WI_AUDIO_TAPS__.push({ analyser, node: this.constructor.name });
				window.__WI_CTX_STATES__.push(() => ctx.state);
				return target;
			}
		} catch (e) { /* fall through to the untapped connect */ }
		return origConnect.apply(this, args);
	};
});
await page.goto(`${BASE_URL}index.html`);

// #503 orientation probe: portrait entry must show the rotate overlay on a
// coarse-pointer device and hide it again after rotation; the page is NEVER
// reloaded across the rotation, so anything the game did before it survives.
let rotationProbe = null;
if (portraitEntry) {
	const readOverlay = () => page.evaluate(() => {
		const el = document.getElementById("wi-rotate-overlay");
		return {
			overlayShown: !!el && getComputedStyle(el).display !== "none",
			portrait: matchMedia("(orientation: portrait)").matches,
			coarse: matchMedia("(pointer: coarse)").matches,
			innerSize: [window.innerWidth, window.innerHeight],
		};
	});
	await new Promise((ok) => setTimeout(ok, 1500));
	const before = await readOverlay();
	await page.screenshot({ path: join(outDir, "portrait_entry.png") });
	await page.setViewportSize(landscapeViewport);
	await new Promise((ok) => setTimeout(ok, 500));
	const after = await readOverlay();
	rotationProbe = { before, after };
	console.log(`rotation probe: portrait overlayShown=${before.overlayShown} (portrait=${before.portrait} coarse=${before.coarse} inner=${before.innerSize}) -> landscape overlayShown=${after.overlayShown} (portrait=${after.portrait} inner=${after.innerSize})`);
}

// #503 real-touch servicing: the in-game driver publishes window-pixel tap
// requests (test_driver.gd `_touch_at`); this loop performs each one with
// page.touchscreen.tap -- a genuine browser touch event -- and acknowledges
// it. Without --touch the context has no touchscreen and requests go
// unserviced, which the driver turns into a step FAILURE (no fallback).
let realTouches = 0;
const serviceTouch = async () => {
	const req = await page.evaluate(() => window.__WI_QA_TOUCH_REQ__ ?? null);
	if (!req) return;
	await page.evaluate(() => { window.__WI_QA_TOUCH_REQ__ = null; });
	if (touchMode) {
		await page.touchscreen.tap(req.x, req.y);
		realTouches += 1;
		console.log(`[touch] real tap #${realTouches} ${req.label} @ (${req.x.toFixed(0)},${req.y.toFixed(0)})`);
	} else {
		console.log(`[touch] request ${req.label} left UNSERVICED (no --touch) -- the driver fails this step`);
		return;
	}
	await page.evaluate(() => { window.__WI_QA_TOUCH_DONE__ = (window.__WI_QA_TOUCH_DONE__ || 0) + 1; });
};

const deadline = Date.now() + TIMEOUT_MS;
let result = null;
while (Date.now() < deadline) {
	await serviceTouch();
	const shot = await page.evaluate(() => window.__WI_QA_SHOT__ ?? null);
	if (shot) {
		await page.screenshot({ path: join(outDir, `${shot}.png`) });
		await page.evaluate(() => {
			window.__WI_QA_SHOT__ = null;
		});
	}
	result = await page.evaluate(() => window.__WI_RESULT__ ?? null);
	if (result) break;
	await new Promise((ok) => setTimeout(ok, 100));
}

// Output-level audio measurement (silence diagnosis): sample every tap's
// time-domain buffer a few times across ~2s and report peak RMS + context
// state. Runs on every invocation -- cheap, and the numbers land in the log.
const audioProbe = await page.evaluate(async () => {
	const taps = window.__WI_AUDIO_TAPS__ || [];
	const states = (window.__WI_CTX_STATES__ || []).map((f) => { try { return f(); } catch { return "?"; } });
	let peakRms = 0;
	const buf = new Float32Array(2048);
	for (let round = 0; round < 10; round++) {
		for (const t of taps) {
			t.analyser.getFloatTimeDomainData(buf);
			let sum = 0;
			for (let i = 0; i < buf.length; i++) sum += buf[i] * buf[i];
			peakRms = Math.max(peakRms, Math.sqrt(sum / buf.length));
		}
		await new Promise((ok) => setTimeout(ok, 200));
	}
	// CONTROL: a plain oscillator through the same tap machinery -- if THIS
	// reads zero too, the headless context renders nothing and the game
	// numbers above are inconclusive; if it registers, the game graph is
	// genuinely silent.
	let controlRms = 0;
	try {
		const taps0 = window.__WI_AUDIO_TAPS__.length;
		const ctx2 = new AudioContext();
		const osc = ctx2.createOscillator();
		osc.connect(ctx2.destination); // patched: inserts a tap
		osc.start();
		await ctx2.resume();
		await new Promise((ok) => setTimeout(ok, 400));
		const tap = window.__WI_AUDIO_TAPS__[taps0];
		if (tap) {
			const b2 = new Float32Array(2048);
			tap.analyser.getFloatTimeDomainData(b2);
			let sum2 = 0;
			for (let i = 0; i < b2.length; i++) sum2 += b2[i] * b2[i];
			controlRms = Math.sqrt(sum2 / b2.length);
		}
		osc.stop(); await ctx2.close();
	} catch (e) { controlRms = -1; }
	return { taps: taps.length, tapNodes: taps.map((t) => t.node), states, peakRms, controlRms };
});
console.log(`audio OUTPUT probe: taps=${audioProbe.taps} [${audioProbe.tapNodes}] ctxStates=[${audioProbe.states}] peakRMS=${audioProbe.peakRms.toFixed(6)} oscillatorControlRMS=${audioProbe.controlRms.toFixed(6)} => ${audioProbe.peakRms > 0.0001 ? "OUTPUT PRESENT" : "SILENT GRAPH"}`);
// THE TOOTH (web-silence root cause, 2026-07-13): with WI_REQUIRE_AUDIO_OUTPUT=1
// a silent graph is a HARD FAIL when the tap machinery itself is proven live
// (oscillator control > 0). Set for scripts that always play audio
// (combat_walkthrough boots into field music) -- this is the assert that would
// have caught the runtime-bus silence the day it shipped.
if (process.env.WI_REQUIRE_AUDIO_OUTPUT === "1" && audioProbe.controlRms > 0.0001 && audioProbe.peakRms <= 0.0001) {
	console.error("audio OUTPUT probe: REQUIRED output missing (graph silent while control oscillator renders) -- the runtime-bus silence class");
	globalThis.__requiredAudioOutputMissing = true;
}

// --touch groundwork smoke (see the hasTouch comment above): one real,
// post-result touchscreen tap at a corner of the canvas -- after the QA
// script has already produced its result, so it can never perturb script
// assertions -- to prove Playwright's touch API actually reaches this
// real-server-hosted canvas without erroring.
let touchSmokeOk = true;
if (touchMode && result) {
	try {
		await page.touchscreen.tap(2, 2);
		await page.waitForTimeout(200);
	} catch (e) {
		touchSmokeOk = false;
		console.log(`[touch smoke] page.touchscreen.tap failed: ${e}`);
	}
}

await browser.close();
server.close();

if (!result) {
	console.error(`FAIL: no result within ${TIMEOUT_MS / 1000}s (game never finished the QA script)`);
	process.exit(1);
}
await writeFile(join(outDir, "result.json"), JSON.stringify(result, null, 2));
console.log(`result: ${JSON.stringify(result, null, 2)}`);
console.log(`outputs in: ${outDir}`);

// --- Audio smoke (issue #105's actual contract) ---------------------------
// (a) zero worklet-failure console/page-error lines across the whole run.
const workletErrors = capturedErrors.filter(isWorkletError);
// (b) the worklet module URLs were actually requested and returned 200 (via
// the server's own request log -- see file header for why not
// page.on('response')).
const workletRequests = requestLog.filter(
	(r) => r.path.endsWith(".audio.worklet.js") || r.path.endsWith(".audio.position.worklet.js"),
);
const workletMainOk = workletRequests.some((r) => r.path.endsWith(".audio.worklet.js") && r.status === 200);
const workletPositionOk = workletRequests.some(
	(r) => r.path.endsWith(".audio.position.worklet.js") && r.status === 200,
);
const audioSmokePassed = workletErrors.length === 0 && workletMainOk && workletPositionOk && touchSmokeOk;

console.log("--- audio smoke (issue #105) ---");
console.log(`worklet error lines: ${workletErrors.length}`);
for (const e of workletErrors) console.log(`  FAIL: ${e}`);
console.log(
	`audio.worklet.js request: ${workletMainOk ? "200 OK" : "MISSING/FAILED"} (${workletRequests
		.filter((r) => r.path.endsWith(".audio.worklet.js"))
		.map((r) => `${r.status} ${r.path}`)
		.join(", ") || "no request seen"})`,
);
console.log(
	`audio.position.worklet.js request: ${workletPositionOk ? "200 OK" : "MISSING/FAILED"} (${workletRequests
		.filter((r) => r.path.endsWith(".audio.position.worklet.js"))
		.map((r) => `${r.status} ${r.path}`)
		.join(", ") || "no request seen"})`,
);
if (touchMode) console.log(`touch smoke (page.touchscreen.tap reached the canvas): ${touchSmokeOk ? "OK" : "FAIL"}`);
if (touchMode) console.log(`real touch taps performed by the runner: ${realTouches} (EMULATED browser touch; not real hardware)`);
// The rotation probe is part of the verdict: `process.exit(...)` below would
// override a bare exitCode, so it feeds overallPassed directly.
let rotationOk = true;
if (rotationProbe) {
	rotationOk = rotationProbe.before.overlayShown && !rotationProbe.after.overlayShown;
	console.log(`rotation probe: ${rotationOk ? "OK" : "FAIL"} (overlay shown in portrait, hidden after rotation, no reload)`);
}
console.log(`audio smoke: ${audioSmokePassed ? "PASS" : "FAIL"}`);

const overallPassed = result.passed && audioSmokePassed && rotationOk;
if (!rotationOk) {
	console.error("FAIL: portrait-entry rotation probe failed (see above).");
}
if (!audioSmokePassed) {
	console.error("FAIL: audio smoke failed (see above) -- web audio is broken even if the QA script itself passed.");
}
if (globalThis.__requiredAudioOutputMissing) {
	console.error("FAIL: required audio OUTPUT missing (WI_REQUIRE_AUDIO_OUTPUT=1) -- the runtime-bus silence class.");
	process.exit(1);
}
process.exit(overallPassed ? 0 : 1);
