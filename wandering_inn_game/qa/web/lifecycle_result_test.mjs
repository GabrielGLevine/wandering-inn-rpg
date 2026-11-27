import assert from 'node:assert/strict';
import { stageResultFailures } from './lifecycle_result.mjs';
const valid = {passed:true,aborted:false,failures:[],script:'res://qa/scripts/lifecycle_reload.json',steps_total:12,steps_run:12};
assert.deepEqual(stageResultFailures(valid,'reload',12),[]);
for (const patch of [{passed:false},{aborted:true},{failures:['bad']},{failures:null},{script:'res://qa/scripts/lifecycle_save.json'},{steps_run:0,steps_total:0},{steps_run:11},{steps_total:13}]) {
 assert.ok(stageResultFailures({...valid,...patch},'reload',12).length, JSON.stringify(patch));
}
assert.ok(stageResultFailures(null,'reload',12).length);
assert.ok(stageResultFailures({...valid,steps_total:0,steps_run:0},'reload',0).length);
console.log('PASS: lifecycle results reject missing, partial, empty, aborted and wrong-stage green claims');

const { isKnownRendererDiagnostic } = await import('./lifecycle_result.mjs');
const known = {type:'warning',text:'[.WebGL-0x123abc]GL Driver Message (OpenGL, Performance, GL_CLOSE_PATH_NV, High): GPU stall due to ReadPixels'};
assert.equal(isKnownRendererDiagnostic(known),true);
assert.equal(isKnownRendererDiagnostic({...known,type:'error'}),false);
assert.equal(isKnownRendererDiagnostic({...known,text:known.text+' ERROR: unexpected'}),false);
assert.equal(isKnownRendererDiagnostic({type:'warning',text:'unknown warning'}),false);
assert.equal(isKnownRendererDiagnostic({type:'log',text:'WARNING: ImageLoaderSVG: Target canvas dimensions 51500×51500 (with scale 1.00) exceed the max supported dimensions 16384×16384. The target canvas will be scaled down.'}),true);
console.log('PASS: only exact known renderer diagnostics are exempt');

const { browserResultFailures } = await import('./lifecycle_result.mjs');
assert.deepEqual(browserResultFailures(valid,'lifecycle_reload',12),[]);
for (const patch of [{passed:false},{aborted:true},{failures:['bad']},{failures:null},{script:'res://qa/scripts/other.json'},{steps_run:0,steps_total:0},{steps_run:11},{steps_total:13}]) {
 assert.ok(browserResultFailures({...valid,...patch},'lifecycle_reload',12).length);
}
for (const type of ['error','pageerror','warning']) {
 assert.ok(browserResultFailures(valid,'lifecycle_reload',12,[{type,text:'unrelated diagnostic'}]).length);
}
for (const text of ['SCRIPT ERROR: broken','Parse Error: broken','ERROR: broken','WARNING: broken']) {
 assert.ok(browserResultFailures(valid,'lifecycle_reload',12,[{type:'log',text}]).length);
}
assert.deepEqual(browserResultFailures(valid,'lifecycle_reload',12,[known]),[]);
assert.ok(browserResultFailures(valid,'lifecycle_reload',12,[{...known,type:'error'}]).length);
assert.ok(browserResultFailures(valid,'lifecycle_reload',12,[{...known,text:known.text+' ERROR: unexpected'}]).length);
console.log('PASS: shared browser verdict rejects errors, warnings and incomplete or wrong-script results');
