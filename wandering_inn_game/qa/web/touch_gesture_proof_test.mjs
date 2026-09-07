import assert from 'node:assert/strict';
import {gestureProof, cancelProof} from './touch_gesture_proof.mjs';

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
const cancelTap = {...tap, gesture: {cancel: true}};
const canceledTap = [event('touchstart', 10, 200), event('touchcancel', 20, 200)];
assert.deepEqual(cancelProof(cancelTap, canceledTap), {
 passed: true, moves: 0, domOrder: ['touchstart', 'touchcancel'],
});
assert.equal(gestureProof(cancelTap, canceledTap).passed, false);
assert.equal(gestureProof(cancelTap, [event('touchstart', 10, 200), event('touchend', 20, 200)]).passed, false);
const cancelDrag = {...request, gesture: {...request.gesture, cancel: true}};
const canceledDrag = [good[0], good[1], event('touchmove', 180, 100), event('touchcancel', 200, 100)];
assert.deepEqual(cancelProof(cancelDrag, canceledDrag), {
 passed: true, moves: 2, domOrder: ['touchstart', 'touchmove', 'touchmove', 'touchcancel'],
});
assert.equal(gestureProof(cancelDrag, canceledDrag).passed, false);
for (const bad of [[], canceledTap.slice(1), canceledTap.slice(0, -1),
 [canceledTap[0], event('touchend', 20, 200)],
 [...canceledTap, event('touchend', 21, 200)],
 [canceledTap[0], event('touchend', 15, 200), canceledTap[1]],
 [canceledTap[0], event('touchstart', 15, 200), canceledTap[1]],
 [canceledTap[0], event('touchmove', 15, 200), canceledTap[1]],
 [event('touchstart', 10, 210), canceledTap[1]],
 [canceledTap[0], event('touchcancel', 20, 210)],
 canceledTap.map(e => ({...e, trusted: false})),
 [canceledTap[0], {...canceledTap[1], points: []}],
 [canceledTap[0], {...canceledTap[1], points: [{x: 100, y: 200}, {x: 101, y: 200}]}],
 [canceledTap[0], {...canceledTap[1], time: 9}],
]) assert.equal(cancelProof(cancelTap, bad).passed, false);
for (const bad of [good, [good[0], event('touchcancel', 200, 100)],
 [good[0], good[1], event('touchcancel', 200, 100)],
 [...canceledDrag, event('touchend', 210, 100)],
 [good[0], event('touchmove', 100, 90), ...canceledDrag.slice(2)],
 [good[0], event('touchmove', 100, 150), event('touchmove', 120, 170), ...canceledDrag.slice(2)],
 [good[0], {...good[1], points: [{x: 110, y: 150}]}, ...canceledDrag.slice(2)],
 [good[0], {...good[1], points: [{x: NaN, y: 150}]}, ...canceledDrag.slice(2)],
 canceledDrag.map(e => ({...e, time: e.time / 10})),
 [good[0], {...good[1], trusted: false}, ...canceledDrag.slice(2)],
]) assert.equal(cancelProof(cancelDrag, bad).passed, false);
for (const gesture of [{}, {cancel: true, repeat: 2}, {cancel: true, follow_purchase_buy: true}]) {
 assert.equal(cancelProof({...cancelTap, gesture}, canceledTap).passed, false);
}
assert.equal(cancelProof({...cancelTap, gesture: {cancel: true, hold_ms: 100}}, canceledTap).passed, false);
assert.equal(cancelProof({...cancelTap, gesture: {cancel: true, hold_ms: 100}},
 [canceledTap[0], event('touchcancel', 120, 200)]).passed, true);
for (const [endX, endY] of [[200, 200], [200, 100], [100, 200]]) {
 const diagonal = {...cancelDrag, gesture: {...cancelDrag.gesture, end_x: endX, end_y: endY}};
 const stream = [event('touchstart', 10, 200),
  {...event('touchmove', 100, (200 + endY) / 2), points: [{x: (100 + endX) / 2, y: (200 + endY) / 2}]},
  {...event('touchmove', 180, endY), points: [{x: endX, y: endY}]},
  {...event('touchcancel', 200, endY), points: [{x: endX, y: endY}]}];
 assert.equal(cancelProof(diagonal, stream).passed, true);
}
const repeatedTap = {...tap, gesture: {repeat: 2}};
const repeatedEvents = [...canceledTap.map((e, i) => ({...e, type: i ? 'touchend' : 'touchstart'})),
 event('touchstart', 40, 200), event('touchend', 50, 200)];
assert.equal(gestureProof(repeatedTap, repeatedEvents).passed, true);
assert.equal(gestureProof(repeatedTap, repeatedEvents.slice(0, -1)).passed, false);
console.log('TOUCH_GESTURE_RESULT: PASS');
