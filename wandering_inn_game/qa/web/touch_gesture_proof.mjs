export function gestureProof(request, allEvents) {
 const events = allEvents.filter(e => e.time >= request.started && e.time <= request.finished);
 const start = events[0], end = events.at(-1);
 const moves = events.filter(e => e.type === 'touchmove');
 const drag = request.gesture?.drag === true;
 const repeat = Math.max(1, Math.min(3, request.gesture?.repeat ?? 1));
 const near = (event, x, y) => event?.points?.length === 1
  && Math.abs(event.points[0].x - x) < 1 && Math.abs(event.points[0].y - y) < 1;
 const passed = request.gesture?.cancel !== true && events.length >= 2 && events.every(e => e.trusted === true)
  && start.type === 'touchstart' && end.type === 'touchend'
  && events.filter(e => e.type === 'touchstart').length === (drag ? 1 : repeat)
  && !events.some(e => e.type === 'touchcancel')
  && near(start, request.x, request.y)
  && near(end, drag ? request.gesture.end_x : request.x, drag ? request.gesture.end_y : request.y)
  && (drag ? moves.length > 0 && events.slice(1, -1).every(e => e.type === 'touchmove') && end.time - start.time >= 80
   : events.length === repeat * 2 && events.every((e, i) => e.type === (i % 2 ? 'touchend' : 'touchstart') && near(e, request.x, request.y)));
 return {passed: !!passed, moves: moves.length, domOrder: events.map(e => e.type)};
}

export function cancelProof(request, allEvents) {
 const events = allEvents.filter(e => e.time >= request.started && e.time <= request.finished);
 const start = events[0], cancel = events.at(-1);
 const moves = events.slice(1, -1);
 const gesture = request.gesture ?? {};
 const drag = gesture.drag === true;
 const endX = drag ? gesture.end_x : request.x;
 const endY = drag ? gesture.end_y : request.y;
 const near = (event, x, y) => event?.points?.length === 1
  && Math.abs(event.points[0].x - x) < 1 && Math.abs(event.points[0].y - y) < 1;
 const dx = endX - request.x, dy = endY - request.y;
 const distanceSquared = dx * dx + dy * dy;
 const progressTolerance = 0.001 / Math.max(1, Math.sqrt(distanceSquared));
 let previousProgress = 0;
 const pathValid = moves.every(event => {
  if (event.type !== 'touchmove' || event.points?.length !== 1) return false;
  const {x, y} = event.points[0];
  if (!Number.isFinite(x) || !Number.isFinite(y)) return false;
  const progress = distanceSquared === 0 ? 0 : ((x - request.x) * dx + (y - request.y) * dy) / distanceSquared;
  const valid = progress >= previousProgress - progressTolerance && progress >= -progressTolerance && progress <= 1 + progressTolerance
   && Math.abs(x - (request.x + progress * dx)) < 1
   && Math.abs(y - (request.y + progress * dy)) < 1;
  previousProgress = progress;
  return valid;
 });
 const holdMs = Math.max(0, Math.min(1000, gesture.hold_ms ?? 0));
 const passed = gesture.cancel === true && (gesture.repeat ?? 1) === 1 && !gesture.follow_purchase_buy
  && [request.x, request.y, endX, endY, request.started, request.finished].every(Number.isFinite)
  && events.length >= 2 && events.every((e, i) => e.trusted === true && Number.isFinite(e.time)
   && (i === 0 || e.time >= events[i - 1].time))
  && start.type === 'touchstart' && cancel.type === 'touchcancel'
  && near(start, request.x, request.y) && near(cancel, endX, endY) && pathValid
  && (drag ? holdMs === 0 && moves.length > 0 && near(moves.at(-1), endX, endY)
    && cancel.time - start.time >= 80
   : moves.length === 0 && cancel.time - start.time >= holdMs);
 return {passed: !!passed, moves: moves.length, domOrder: events.map(e => e.type)};
}
