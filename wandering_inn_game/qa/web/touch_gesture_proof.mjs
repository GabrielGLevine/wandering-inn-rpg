export function gestureProof(request, allEvents) {
 const events = allEvents.filter(e => e.time >= request.started && e.time <= request.finished);
 const start = events[0], end = events.at(-1);
 const moves = events.filter(e => e.type === 'touchmove');
 const drag = request.gesture?.drag === true;
 const repeat = Math.max(1, Math.min(3, request.gesture?.repeat ?? 1));
 const near = (event, x, y) => event?.points?.length === 1
  && Math.abs(event.points[0].x - x) < 1 && Math.abs(event.points[0].y - y) < 1;
 const passed = events.length >= 2 && events.every(e => e.trusted === true)
  && start.type === 'touchstart' && end.type === 'touchend'
  && events.filter(e => e.type === 'touchstart').length === (drag ? 1 : repeat)
  && !events.some(e => e.type === 'touchcancel')
  && near(start, request.x, request.y)
  && near(end, drag ? request.gesture.end_x : request.x, drag ? request.gesture.end_y : request.y)
  && (drag ? moves.length > 0 && events.slice(1, -1).every(e => e.type === 'touchmove') && end.time - start.time >= 80
   : events.length === repeat * 2 && events.every((e, i) => e.type === (i % 2 ? 'touchend' : 'touchstart') && near(e, request.x, request.y)));
 return {passed: !!passed, moves: moves.length, domOrder: events.map(e => e.type)};
}
