import assert from 'node:assert/strict';
import {gestureProof} from './touch_gesture_proof.mjs';

const request = {x: 100, y: 200, started: 0, finished: 300, gesture: {drag: true, end_x: 100, end_y: 100}};
const event = (type, time, y) => ({type, time, trusted: true, points: [{x: 100, y}]});
const good = [event('touchstart', 10, 200), event('touchmove', 100, 150), event('touchend', 200, 100)];
assert.equal(gestureProof(request, good).passed, true);
for (const bad of [[good[0], event('touchend', 20, 200), good[1], good[2]], [], good.slice(1), good.slice(0, -1), [good[0], good[2]],
 [good[0], good[1], event('touchcancel', 200, 100)],
 [good[0], good[1], event('touchend', 200, 110)],
 good.map(e => ({...e, trusted: false})), good.map(e => ({...e, time: e.time / 10}))]) {
 assert.equal(gestureProof(request, bad).passed, false);
}
const tap = {...request, gesture: {}};
assert.equal(gestureProof(tap, [event('touchstart', 10, 200), event('touchend', 20, 200)]).passed, true);
assert.equal(gestureProof(tap, good).passed, false);
assert.equal(gestureProof(tap, [event('touchstart', 10, 201), event('touchend', 20, 201)]).passed, false);
console.log('TOUCH_GESTURE_RESULT: PASS');
