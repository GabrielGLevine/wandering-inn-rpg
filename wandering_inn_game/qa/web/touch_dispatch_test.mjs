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
assert.equal(sent.length, 1, 'start must be delivered before scheduling moves');
assert.deepEqual(delays, []);
assert.equal(complete, false);
replies[0]();
await new Promise(resolve => setImmediate(resolve));
assert.deepEqual(delays, Array.from({length: 9}, (_, index) => (index + 1) * 20));
assert.equal(sent.length, 10, 'all moves and end must dispatch before any slow move reply');
assert.deepEqual(sent.map(contact => contact.type), ['touchStart', ...Array(8).fill('touchMove'), 'touchEnd']);
assert.deepEqual(sent[0].touchPoints, [{x: 100, y: 200}]);
assert.deepEqual(sent[8].touchPoints, [{x: 180, y: 120}]);
assert.equal(complete, false, 'completion must await every reply');
replies.slice(1, -1).forEach(resolve => resolve());
await new Promise(resolve => setImmediate(resolve));
assert.equal(complete, false);
replies.at(-1)();
await run;
assert.equal(complete, true);
let failedSends = 0, failedDelays = 0;
await assert.rejects(dispatchDrag({send: async () => {failedSends++; throw new Error('protocol failure');}}, request, async () => {failedDelays++;}), /protocol failure/);
assert.equal(failedSends, 1, 'a failed start must never dispatch moves or end');
assert.equal(failedDelays, 0, 'a failed start must never schedule timers');
await assert.rejects(dispatchDrag({send: async (_, contact) => {
 if (contact.type === 'touchMove') throw new Error('move failure');
}}, request, async () => {}), /move failure/);
console.log('TOUCH_DISPATCH_RESULT: PASS');
