// Two-origin proof of the old-site save hand-off against REAL web builds.
// Usage: node save_transfer_e2e.mjs <old-build-dir> <new-build-dir> [out-dir]
//   old-build-dir: an exported web build whose game writes the saves (the
//                  v0.20.0 tag for the release proof; any build works).
//   new-build-dir: the export of this checkout.
// Origin A serves the old build at /play/ and web/pages-redirect at /; origin
// B (another port = another origin) serves the new build. Saves on A are
// written by the old GAME itself; nothing here writes A's IndexedDB.
// Emulated Chromium only -- no claim about physical phones or Safari.
import { createServer } from "node:http";
import { readFile, mkdir, rm, writeFile } from "node:fs/promises";
import { dirname, extname, join, resolve, sep } from "node:path";
import { fileURLToPath } from "node:url";
import { chromium } from "playwright";

const here = dirname(fileURLToPath(import.meta.url));
const [oldBuild, newBuild, outArg] = process.argv.slice(2);
if (!oldBuild || !newBuild) { console.error("usage: node save_transfer_e2e.mjs <old-build-dir> <new-build-dir> [out-dir]"); process.exit(2); }
const out = resolve(outArg ?? join(here, "../../qa_output/save_transfer_e2e"));
const pageDir = resolve(here, "../../../web/pages-redirect");
const MIME = {".html": "text/html", ".js": "text/javascript", ".wasm": "application/wasm", ".pck": "application/octet-stream", ".png": "image/png"};
const SLOTS = ["auto", "auto_prev", "auto_pre_combat", "manual", "manual_2", "manual_3"];
const DIR = "/userfs/godot/app_userdata/Wandering Inn RPG/";
const PROFILES = {
	desktop: {viewport: {width: 960, height: 540}},
	iphone: {viewport: {width: 844, height: 390}, deviceScaleFactor: 2, hasTouch: true, isMobile: true, userAgent: "Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Mobile/15E148 Safari/604.1"},
	android: {viewport: {width: 915, height: 412}, deviceScaleFactor: 2, hasTouch: true, isMobile: true, userAgent: "Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Mobile Safari/537.36"},
};

function serve(mounts) {
	return new Promise((ok) => {
		const server = createServer(async (req, response) => {
			let path = decodeURIComponent(new URL(req.url, "http://localhost").pathname);
			for (const [prefix, root] of mounts) {
				if (!path.startsWith(prefix)) continue;
				let rel = path.slice(prefix.length);
				if (rel === "" || rel.endsWith("/")) rel += "index.html";
				const file = join(root, rel);
				if (!file.startsWith(root + sep)) break;
				try {
					const body = await readFile(file);
					response.writeHead(200, {"Content-Type": MIME[extname(file)] ?? "application/octet-stream"});
					response.end(body);
					return;
				} catch { break; }
			}
			response.writeHead(path === "/favicon.ico" ? 204 : 404);
			response.end();
		});
		server.listen(0, "127.0.0.1", () => ok(server));
	});
}

const serverA = await serve([["/play/", resolve(oldBuild)], ["/", pageDir]]);
const serverB = await serve([["/", resolve(newBuild)]]);
const A = `http://127.0.0.1:${serverA.address().port}/`;
const B = `http://127.0.0.1:${serverB.address().port}/`;
const MIGRATE = `${A}?wi_target=${encodeURIComponent(B)}`;
await rm(out, {recursive: true, force: true});
await mkdir(out, {recursive: true});
const browser = await chromium.launch();
const rows = [];

// Read-only dump of one origin's save files: {slot: {text, t, type}}.
const readSaves = (page) => page.evaluate(async ({SLOTS, DIR}) => {
	const names = (await indexedDB.databases()).map((d) => d.name);
	if (!names.includes("/userfs")) return {};
	const db = await new Promise((ok) => { const r = indexedDB.open("/userfs"); r.onsuccess = () => ok(r.result); });
	const store = db.transaction("FILE_DATA").objectStore("FILE_DATA");
	const found = {};
	for (const slot of [...SLOTS, "settings"]) {
		const key = slot === "settings" ? `${DIR}settings.cfg` : `${DIR}saves/${slot}.json`;
		const value = await new Promise((ok) => { const r = store.get(key); r.onsuccess = () => ok(r.result); });
		if (value) found[slot] = {text: new TextDecoder().decode(value.contents), t: +value.timestamp, type: Object.prototype.toString.call(value.contents)};
	}
	db.close();
	return found;
}, {SLOTS, DIR});

async function newContext(profile) {
	const context = await browser.newContext(PROFILES[profile]);
	context.diagnostics = [];
	context.oldGameDiagnostics = [];
	context.on("page", (page) => {
		// The old build's own game (origin A /play/) is not under test; its lines are kept apart.
		const where = () => (page.url().startsWith(`${A}play/`) ? context.oldGameDiagnostics : context.diagnostics);
		page.on("console", (m) => { if (m.type() === "error" || m.type() === "warning" || /^(SCRIPT ERROR|Parse Error|ERROR:|WARNING)/.test(m.text())) where().push(`[${m.type()}] ${m.text()}`); });
		page.on("pageerror", (e) => where().push(`[pageerror] ${e}`));
	});
	return context;
}

// Run one of the build's own QA scripts so the GAME writes the saves.
async function play(context, base, script, seed) {
	const page = await context.newPage();
	await page.addInitScript(({script, seed}) => { window.__WI_QA__ = {script: `res://qa/scripts/${script}.json`, seed}; }, {script, seed: String(seed)});
	await page.goto(base);
	await page.waitForFunction(() => window.__WI_RESULT__, null, {timeout: 300000, polling: 250});
	const result = await page.evaluate(() => window.__WI_RESULT__);
	await page.waitForTimeout(1500);
	await page.close();
	if (!result.passed) throw new Error(`${script} failed on ${base}: ${JSON.stringify(result.failures)}`);
}

// Boot the new site (optionally through the old page or a raw fragment) and
// drive the prompt like a player: taps on the buttons' real rects.
async function visit(context, url, plan, shot) {
	const page = await context.newPage();
	await page.addInitScript(() => { if (location.hash.startsWith("#migrate=")) sessionStorage.__wiEntry = String(location.href.length); });
	await page.goto(url, {waitUntil: "commit"});
	if (!url.startsWith(B)) await page.waitForURL((u) => u.href.startsWith(B), {timeout: 30000});
	const game = (expr) => page.evaluate(expr);
	const seen = {entryLength: 0, addressAfterBoot: null, pages: []};
	await page.waitForTimeout(plan.bootMs ?? 12000);
	seen.entryLength = Number(await game(() => sessionStorage.__wiEntry ?? 0));
	seen.addressAfterBoot = await game(() => location.href);
	// Phones: real touchscreen taps on the prompt's buttons (bottom row, either
	// side of centre in the 1280x720 design space the canvas letterboxes).
	// Desktop: keyboard. The cursor always opens on the choice that changes nothing.
	const touch = PROFILES[plan.profile ?? "desktop"].hasTouch === true;
	const size = page.viewportSize();
	const scale = Math.min(size.width / 1280, size.height / 720);
	const at = (dx, y) => [size.width / 2 + dx * scale, size.height / 2 + (y - 360) * scale];
	if (touch) await page.touchscreen.tap(...at(0, 40));
	else await page.keyboard.press("Enter");
	await page.waitForTimeout(1500);
	for (const step of plan.taps ?? []) {
		await page.screenshot({path: join(out, `${shot}_${seen.pages.length}_${step}.png`)});
		seen.pages.push(step);
		const second = ["import", "use_old"].includes(step);
		if (touch) {
			await page.touchscreen.tap(...at(step === "ok" ? 0 : second ? 137 : -137, 639));
		} else {
			if (second) await page.keyboard.press("ArrowRight");
			await page.keyboard.press("Enter");
		}
		await page.waitForTimeout(1800);
	}
	await page.screenshot({path: join(out, `${shot}_end.png`)});
	await page.waitForTimeout(1500);
	seen.addressAtEnd = await game(() => location.href);
	seen.saves = await readSaves(page);
	await page.close();
	return seen;
}

const same = (a, b) => JSON.stringify(Object.fromEntries(Object.entries(a).map(([k, v]) => [k, v.text]))) === JSON.stringify(Object.fromEntries(Object.entries(b).map(([k, v]) => [k, v.text])));
const slotTexts = (saves) => Object.fromEntries(Object.entries(saves).filter(([k]) => k !== "settings").map(([k, v]) => [k, v.text]));
function record(id, title, passed, detail, context) {
	const noise = context ? context.diagnostics.filter((line) => !/GPU stall due to ReadPixels|ImageLoaderSVG/.test(line)) : [];
	rows.push({id, title, passed: passed && noise.length === 0, detail, diagnostics: noise, oldBuildGameDiagnostics: context ? context.oldGameDiagnostics.length : 0});
	console.log(`SCENARIO ${id} ${passed && noise.length === 0 ? "PASS" : "FAIL"}: ${title} ${JSON.stringify(detail)}${noise.length ? " NOISE " + JSON.stringify(noise.slice(0, 3)) : ""}`);
}

async function oldSaves(context) {
	const page = await context.newPage();
	await page.goto(`${A}play/index.png`);
	const saves = await readSaves(page);
	await page.close();
	return saves;
}

async function scenarioA(id, profile) {
	const context = await newContext(profile);
	await play(context, `${A}play/`, "save_load_roundtrip", 9);
	const before = await oldSaves(context);
	const seen = await visit(context, MIGRATE, {profile, taps: ["import", "ok"]}, id);
	const after = await oldSaves(context);
	const want = slotTexts(before);
	const got = slotTexts(seen.saves);
	const ok = Object.keys(want).length >= 3 && JSON.stringify(got) === JSON.stringify(want) && same(before, after)
		&& seen.entryLength > 0 && seen.addressAfterBoot === B && seen.addressAtEnd === B;
	record(id, `fresh new site, ${profile}: every old-site slot arrives byte-identical`, ok, {slots: Object.keys(want), contentsType: before.auto?.type, entryUrlChars: seen.entryLength, addressAfterBoot: seen.addressAfterBoot, oldSiteUntouched: same(before, after)}, context);
	return context;
}

// (a) + (g): fresh new site, several slots, on each profile.
const contextA = await scenarioA("a", "desktop");

// (c) migrate twice: same payload again -> no prompt, no change.
{
	const before = await visit(contextA, B, {bootMs: 9000}, "c_before");
	const again = await visit(contextA, MIGRATE, {taps: []}, "c_again");
	record("c", "migrating twice changes nothing and shows no prompt", same(before.saves, again.saves) && again.addressAfterBoot === B, {slots: Object.keys(slotTexts(again.saves))}, contextA);
}
// (f) the fragment is gone after load; a reload re-imports nothing.
{
	const page = await contextA.newPage();
	await page.goto(MIGRATE, {waitUntil: "commit"});
	await page.waitForURL((u) => u.href.startsWith(B));
	await page.waitForTimeout(3000);
	const early = await page.evaluate(() => ({href: location.href, pending: typeof window.__wi_migrate}));
	await page.reload();
	await page.waitForTimeout(9000);
	const late = await page.evaluate(() => ({href: location.href, pending: window.__wi_migrate ?? null, history: history.length}));
	await page.close();
	record("f", "fragment leaves the address bar at once and does not survive reload", early.href === B && late.href === B && late.pending === null, {early, late}, contextA);
}
await contextA.close();

// (b) the new site already has its own saves: nothing is overwritten; a choice is offered.
{
	const context = await newContext("desktop");
	await play(context, `${A}play/`, "save_load_roundtrip", 9);
	await play(context, B, "save_load_roundtrip", 9);
	const mine = (await visit(context, B, {bootMs: 9000}, "b_before")).saves;
	const old = await oldSaves(context);
	const conflicts = Object.keys(slotTexts(old)).filter((slot) => mine[slot] && mine[slot].text !== old[slot].text);
	// Import, then answer every conflict with the default (Keep what's here).
	const kept = await visit(context, MIGRATE, {taps: ["import", ...conflicts.map(() => "keep"), "ok"]}, "b_keep");
	record("b", "new site already has saves: a choice is offered and keeping changes nothing", conflicts.length > 0 && same(mine, kept.saves), {conflicts, slotsOnNewSite: Object.keys(slotTexts(mine))}, context);
	await context.close();
}

// (d) no saves on the old origin: straight redirect, no prompt, no fragment.
{
	const context = await newContext("desktop");
	const page = await context.newPage();
	const requests = [];
	page.on("framenavigated", (frame) => { if (frame === page.mainFrame()) requests.push(frame.url()); });
	await page.goto(MIGRATE, {waitUntil: "commit"});
	await page.waitForURL((u) => u.href.startsWith(B));
	const databases = await (async () => { const probe = await context.newPage(); await probe.goto(`${A}play/index.png`); const names = await probe.evaluate(async () => (await indexedDB.databases()).map((d) => d.name)); await probe.close(); return names; })();
	record("d", "no saves on the old site: plain redirect, and the page creates no database", page.url() === B && databases.length === 0, {navigations: requests, oldSiteDatabases: databases}, context);
	await context.close();
}

// (e) hostile fragments opened directly on the new site: refusal, no writes, no engine errors.
{
	const context = await newContext("desktop");
	const hostile = {
		garbage: "wi1.p.!!!not-base64!!!",
		traversal: "wi1.p." + Buffer.from(JSON.stringify({v: 1, slots: {"../settings": {t: 1, d: "x"}}})).toString("base64url"),
		badGzip: "wi1.g." + Buffer.from("definitely not gzip").toString("base64url"),
		oversized: "wi1.p." + "A".repeat(70000),
		script: "wi1.p.\"><img src=x onerror=alert(1)>';window.__pwned=1;//",
		badSave: "wi1.p." + Buffer.from(JSON.stringify({v: 1, slots: {manual: {t: 1, d: JSON.stringify({version: 99, state: {}})}}})).toString("base64url"),
	};
	const detail = {};
	let ok = true;
	for (const [name, payload] of Object.entries(hostile)) {
		const seen = await visit(context, `${B}#migrate=${payload}`, {bootMs: 10000, taps: ["ok"]}, `e_${name}`);
		const clean = Object.keys(slotTexts(seen.saves)).length === 0 && seen.addressAfterBoot === B;
		detail[name] = {slotsWritten: Object.keys(slotTexts(seen.saves)), address: seen.addressAfterBoot};
		ok = ok && clean;
	}
	record("e", "hostile fragments: refusal message, nothing written, no error lines", ok, detail, context);
	await context.close();
}

// (g) the fresh-site migration again on emulated phone profiles.
for (const profile of ["iphone", "android"]) {
	try {
		await (await scenarioA(`g_${profile}`, profile)).close();
	} catch (error) {
		record(`g_${profile}`, `fresh new site, ${profile}`, false, {error: String(error)}, null);
	}
}

await browser.close();
serverA.close();
serverB.close();
const passed = rows.every((row) => row.passed);
await writeFile(join(out, "result.json"), JSON.stringify({passed, oldBuild: resolve(oldBuild), newBuild: resolve(newBuild), browser: "chromium (Playwright, emulated profiles)", scenarios: rows}, null, 2) + "\n");
console.log(`SAVE TRANSFER E2E ${passed ? "PASS" : "FAIL"}: ${rows.filter((r) => r.passed).length}/${rows.length}; artifacts ${out}`);
process.exit(passed ? 0 : 1);
