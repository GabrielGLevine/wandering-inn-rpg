# Low-gold recovery evidence (#513 / #515)

The existing free bed supplies class-independent HP/MP recovery even when the
player spends all earned gold and a former money producer is permanently gone.
No economy, item, combat, or recovery rules changed for this evidence.

## Actual continuous history

Rogue route at composed289f0984 reaches the ending and Inn:3464steps,
8wins/3retained losses/18sleeps;146gold earned−142spent=4. The optional58gold
gear spend remains in the history. Full headless and native runs pass their
steps but emit shutdown shader errors and remain INVALID under the current
zero-noise gate. #586 owns that defect; no exception is assumed.

At originalstep882, the fresh run saves an earned14gold checkpoint. The next
segment buys Hunter’s Fang for14, equips it, wins the scouts and leaves with
10/44HP,0/14MP,0gold and no consumable stock. The road encounter that previously
paid2gold is already permanently removed. Real movement returns through the
sewers/street/floodplains to the Inn and upstairs bed. Sleep restores44HP/14MP.
The continuous route subsequently returns to win the joined Awakened boss.
No new income or repeated-action farming funds the recovery.

## Bounded regression and window proof

`poor_retired_producer_recovery` uses the unchanged version12 save emitted at
that checkpoint; SHA25693652e6b29375ad0779c9cd417aee12dc9a0de0cb74e909aec834a43fdb682f6.
The fixture supplies the earned kit/history/RNG as setup. This test is a
checkpoint-based regression, not a new fresh journey or acquisition claim.
Original883–1018 inputs are retained. Added observations pin14→0gold,10HP/0MP,
empty stock, permanent road removal and absence of its rendered entity. Exactly
one gold_changed event (purchase−14), one fight and one victory exclude hidden
income, repayment, respawn and repeated fight rewards during this segment.

The first external-script control at289f0984 passes167/167 with exit0/PASS,
valid result and no engine errors/warnings. Evidence:
`/private/tmp/wi-567-evidence/poor-visual-289f0984` includes exact script hash,
command/source, full log, events/result and two inspected native captures.
`poor_depleted_after_scouts` visibly readsHP10/44 MP0/14. After actual bed input,
`poor_retired_producer_real_bed` shows the full matching receipt:
“Rested: HP44/44 (+34), MP14/14 (+14).” The script waits for the exact captured
recovery event before taking that picture. Production message timing begins
before bed; earlier route controls use default QA timing. Native mouse/touch
emulation is not browser or physical touch proof. No mobile test was added.

Portable fixture/script registration follows that identical control; final
registered/composed checks are recorded by the integrating PR.

## Limits and next action

Sleep refreshes per-waking chores and may settle progression. It does not
restore the permanently removed road encounter. Free sleep restores resources;
it does not pay mandatory travel fees. Basic Cooking’s Hot Meal restoresHP
only; MP food requires the relevant earned cooking Skill. Existing kitchen
access stays unlimited, with no new resale or farming claim.

This resolves the bounded poor/removed-producer resource mechanism. Full#513
still needs supported-route ledgers and accepted imperfect-spend/missed-reward
findings through monetary blockers. The worker and newly rested martial vault
walls are combat findings for#453, not proven lack of HP/MP recovery. Caster
acceptance remains#438. Additional mobile/device testing is deferred to#585.
