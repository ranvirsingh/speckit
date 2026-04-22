<!--
  Speckit-tracked PR. Fill EVERY checkbox below. If you must skip a phase,
  add `skip-speckit: <phase> — <reason>` on its own line in this body and CI will allow it.
-->

## Linked issue

Closes #<!-- issue number -->

## What changed

<!-- 1–3 sentences. Skip the long story — the issue holds the spec. -->

## Speckit phases

- [ ] **Specify** — issue body contains the spec (acceptance criteria + checklist)
- [ ] **Research** — needed? if yes, findings recorded in issue or `docs/research.md`
- [ ] **Plan** — needed? if yes, design notes + tasks appended to issue
- [ ] **Implement** — code complete, conventional commits reference `#N`
- [ ] **Test (UAT)** — every acceptance scenario in the issue passes
- [ ] **E2E** — proof-of-work artifact attached below (gif / video / `.http` / log)
- [ ] **Retro** — living docs updated; TODOs triaged into `docs/PARKING_LOT.md`

## Test results

```
<!-- paste test summary -->
```

## E2E artifact

<!-- gif / video link / e2e-NN-results.md path / .http file path -->

## Skipped phases

<!--
  If any checkbox is unchecked, add a justification line per phase:
    skip-speckit: <phase> — <reason>
  Examples:
    skip-speckit: research — no library or pattern unknowns
    skip-speckit: e2e — pure refactor, no observable behaviour change
  CI fails if a checkbox is unchecked AND no matching skip line exists.
-->
