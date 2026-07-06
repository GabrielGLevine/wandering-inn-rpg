// Drive the Godot web export through a QA script under headless Chromium.
// Usage: node run_web_qa.mjs <script-name> [seed]
// Loads build/web/ through Playwright request interception with
// window.__WI_QA__ set, polls for screenshot requests (__WI_QA_SHOT__) and the
// final result (__WI_RESULT__). All assertions run in-engine; this runner is
// only the renderer, screenshot hands, and result reader.
import { readFile, writeFile, mkdir, rm } from "node:fs/promises";
import { join, dirname, extname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { chromium } from "playwright";

const scriptName = process.argv[2];
const seedArg = process.argv[3];
if (!scriptName) {
	console.error("usage: node run_web_qa.mjs <script-name> [seed]");
	process.exit(2);
}

const here = dirname(fileURLToPath(import.meta.url));
const projRoot = resolve(here, "../..");
const webRoot = join(projRoot, "build/web");
const outDir = join(projRoot, "qa_output", `web_${scriptName}`);
const BASE_URL = "http://localhost/";
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

async function fulfillFromBuild(route) {
	const url = new URL(route.request().url());
	const pathName = decodeURIComponent(url.pathname);
	const relPath = pathName === "/" ? "index.html" : pathName.replace(/^\/+/, "");
	const path = join(webRoot, relPath);
	try {
		const body = await readFile(path);
		await route.fulfill({
			status: 200,
			contentType: MIME[extname(path)] ?? "application/octet-stream",
			body,
		});
	} catch {
		await route.fulfill({ status: 404, body: "not found" });
	}
}

await rm(outDir, { recursive: true, force: true });
await mkdir(outDir, { recursive: true });

const browser = await chromium.launch({ args: ["--single-process"] });
const page = await browser.newPage({ viewport: { width: 640, height: 400 } });
await page.route(`${BASE_URL}**/*`, fulfillFromBuild);
page.on("console", (msg) => {
	const text = msg.text();
	if (text.startsWith("QA_")) console.log(`[game] ${text}`);
});
await page.addInitScript(
	({ name, seed }) => {
		window.__WI_QA__ = { script: `res://qa/scripts/${name}.json`, seed: seed ?? "" };
	},
	{ name: scriptName, seed: seedArg ?? "" },
);
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

await browser.close();

if (!result) {
	console.error(`FAIL: no result within ${TIMEOUT_MS / 1000}s (game never finished the QA script)`);
	process.exit(1);
}
await writeFile(join(outDir, "result.json"), JSON.stringify(result, null, 2));
console.log(`result: ${JSON.stringify(result, null, 2)}`);
console.log(`outputs in: ${outDir}`);
process.exit(result.passed ? 0 : 1);
