# Community Submission Triage — local procedure

The triage workflow (`.github/workflows/triage.yml`) self-skips because
this project runs on a Claude subscription, not an API key. Triage
happens in a local Claude Code session instead. Same contract, same
prompt.

## Procedure (maintainer or a session the maintainer starts)

1. List candidates: `gh issue list -R GabrielGLevine/wandering-inn-rpg
   --label triage --state open`
2. For each issue: `gh issue view <n> --json title,body,labels`
3. Run the contract in `.github/triage-prompt.md` against the submission
   — the prompt's hard bounds apply verbatim (drafts only; never approve
   lore; repo conventions bind all drafted content).
4. Post the single comment: `gh issue comment <n> --body-file <draft>`
5. Remove the label so the queue stays clean:
   `gh issue edit <n> --remove-label triage`

If an `ANTHROPIC_API_KEY` secret is ever added, the Action lights up
with zero changes and this document becomes the fallback.
