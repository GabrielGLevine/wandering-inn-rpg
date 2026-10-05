const pause = (milliseconds) => new Promise(resolve => setTimeout(resolve, milliseconds));

export async function dispatchDrag(session, request, delay = pause) {
 const contacts = [{type: 'touchStart', touchPoints: [{x: request.x, y: request.y}]}];
 for (let index = 1; index <= 8; index++) {
  contacts.push({type: 'touchMove', touchPoints: [{
   x: request.x + (request.gesture.end_x - request.x) * index / 8,
   y: request.y + (request.gesture.end_y - request.y) * index / 8,
  }]});
 }
 contacts.push({type: 'touchEnd', touchPoints: []});
 // Pace the wire messages without adding one compositor reply delay per move.
 await Promise.all(contacts.map(async (contact, index) => {
  await delay(index * 20);
  await session.send('Input.dispatchTouchEvent', contact);
 }));
}
