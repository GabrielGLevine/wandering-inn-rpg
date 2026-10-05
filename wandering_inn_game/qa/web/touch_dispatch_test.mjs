import assert from 'node:assert/strict';
import {dispatchDrag} from './touch_dispatch.mjs';

const sent = [], replies = [], delays = [];
const session = {send(method, contact) {
 assert.equal(method, 'Input.dispatchTouchEvent');
 sent.push(contact);
 return new Promise(resolve => replies.push(resolve));
}};
const request = {x: 100, y: 200, gesture: {end_x: 180, end_y: 120}};
let complete = false;
const run = dispatchDrag(session, request, async milliseconds => {delays.push(milliseconds);})
 .then(() => {complete = true;});
await new Promise(resolve => setImmediate(resolve));
assert.deepEqual(delays, Array.from({length: 10}, (_, index) => index * 20));
assert.equal(sent.length, 10, 'all contacts must dispatch before any slow reply');
assert.deepEqual(sent.map(contact => contact.type), ['touchStart', ...Array(8).fill('touchMove'), 'touchEnd']);
assert.deepEqual(sent[0].touchPoints, [{x: 100, y: 200}]);
assert.deepEqual(sent[8].touchPoints, [{x: 180, y: 120}]);
assert.equal(complete, false, 'completion must await every reply');
replies.slice(0, -1).forEach(resolve => resolve());
await new Promise(resolve => setImmediate(resolve));
assert.equal(complete, false);
replies.at(-1)();
await run;
assert.equal(complete, true);
await assert.rejects(dispatchDrag({send: async () => {throw new Error('protocol failure');}}, request, async () => {}), /protocol failure/);
console.log('TOUCH_DISPATCH_RESULT: PASS');
