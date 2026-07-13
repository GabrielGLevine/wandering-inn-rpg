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
const positional = args.filter((a) => a !== "--touch");
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
const page = await browser.newPage({
	viewport: { width: 640, height: 400 },
	deviceScaleFactor: 1,
	hasTouch: touchMode,
});

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

const deadline = Date.now() + TIMEOUT_MS;
let result = null;
while (Date.now() < deadline) {
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
console.log(`audio smoke: ${audioSmokePassed ? "PASS" : "FAIL"}`);

const overallPassed = result.passed && audioSmokePassed;
if (!audioSmokePassed) {
	console.error("FAIL: audio smoke failed (see above) -- web audio is broken even if the QA script itself passed.");
}
if (globalThis.__requiredAudioOutputMissing) {
	console.error("FAIL: required audio OUTPUT missing (WI_REQUIRE_AUDIO_OUTPUT=1) -- the runtime-bus silence class.");
	process.exit(1);
}
process.exit(overallPassed ? 0 : 1);
