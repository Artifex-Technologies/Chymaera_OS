# Progress Log

Running log of multi-session cleanup/maintenance work, so a new chat can pick
up without re-deriving context. Not a changelog of features (that's
`PARITY_CHECKLIST.md`'s job) — this is specifically for work-in-progress
threads that span multiple sessions, like the current codebase-wide
efficiency/dead-code/documentation pass.

Append new entries at the top. When a thread closes out completely, mark it
closed rather than deleting it — the history of *why* is worth keeping.

---

## 2026-09-26 — Chymaera Sentry governance consultation (DONE)

**Ask:** worked from Chymaera_Sentry's board — that repo's Phase 4
(governance layer) needed a real Sarina-side caller to mean anything, and
the user decided to build both halves now rather than propose-then-wait.
Full detail in `CLAUDE.md`'s Coordination Log (2026-09-26 entry) and
`docs/ECOSYSTEM.md` §4b; this entry is the short version.

- New `sarina/sentry_governance.py` (stdlib `urllib.request` only, no new
  dependency). `sarina/memory_security.py`'s `scan_memory_text` — the
  single function both memory-write call sites already funnel through —
  now also consults Sentry's `POST /v1/review` after its own checks pass,
  opt-in via `SENTRY_REVIEW_URL`. Zero other call sites touched.
- Fails open (no `SENTRY_REVIEW_URL`, or Sentry unreachable → behavior
  unchanged from before this existed) and fails closed on an actual deny.
- 10 new tests, offline, against a real loopback `http.server.HTTPServer`
  (same convention `test_chymaera_console.py` already uses). Full suite:
  970 passed, 15 failed — the same pre-existing POSIX-specific set as
  always, confirmed by name.
- **Verified for real against a live Sentry process**, not just per-repo
  unit tests — an injection phrase sent from here came back denied with
  Sentry's own exact reason string, and appeared in Sentry's `/v1/alerts`.

Closed on landing — a single self-contained slice, not an ongoing thread.

## 2026-09-25 — Codebase-wide dead-code/efficiency audit + doc review (IN PROGRESS)

**Ask:** go through the whole `sarina/` codebase (115 Python files, ~40K
lines) for efficiency and dead code, review all 8 markdown files and
update/remove stale ones, track it all here.

### Done

1. **Ruff + vulture pass across all of `sarina/`** (`pip install ruff vulture`,
   dev-time only, not added to `pyproject.toml`). Found and fixed 22 genuine
   issues, all pre-existing (verified via `git blame` — none introduced by
   the prior memory-feature session):
   - Unused imports in `agent_runtime.py`, `agent_slash_commands.py`,
     `main.py`, `builtin_agents.py`, `bundled_skills.py`, `microcompact.py`,
     `prompt_constants.py`, `release_notes.py`, `session_memory_compact.py`,
     `gui/server.py`.
   - Two unused local variables (`mutation` in `agent_tools.py`'s
     `TaskStop` handler, `corrections` in `session_memory_compact.py` — a
     dead placeholder, never appended to or read).
   - One real (if low-severity) bug: `agent_slash_commands.py`'s
     `_changelog_path` had `-> 'Path'` as a return annotation with `Path`
     never imported at module scope (only locally inside the function) —
     harmless under normal execution since `from __future__ import
     annotations` defers evaluation, but would break `typing.get_type_hints()`
     if anything ever called it. Fixed by adding `from pathlib import Path`
     to the file's existing `TYPE_CHECKING` block.
   - Vulture at 80% confidence found only 4 hits, all false positives
     (`Protocol` stub parameters, `__exit__` signature args) — no action.
   - Full suite re-run after: **1166 tests, same 12 failures / 29 errors as
     the documented pre-existing Windows baseline** — zero regressions.

2. **Read all 8 markdown files in full**
   (`README.md`, `PARITY_CHECKLIST.md`, `TESTING_GUIDE.md`,
   `docs/ECOSYSTEM.md`, `packaging/arch/README.md`,
   `blackarch_compat/README.md`, `benchmarks/README.md`, `CLAUDE.md`).
   Conclusion: **none need removal.** `docs/ECOSYSTEM.md`,
   `packaging/arch/README.md`, `blackarch_compat/README.md`,
   `benchmarks/README.md` are all current. `README.md`, `PARITY_CHECKLIST.md`,
   and `TESTING_GUIDE.md` were missing the memory/session-search feature
   added in the prior session — fixed:
   - `PARITY_CHECKLIST.md`: marked the two relevant "Missing" items in
     §4 (memory subsystem parity, memory extraction from conversations) as
     partially done with pointers to the new files; added the FTS5 search
     line; added the 4 new tools to §6's tool list (65 → 69); added the 4
     new files to §20's file inventory.
   - `TESTING_GUIDE.md`: added `test_memory_*`/`test_session_search_fts` to
     §1.6's focused-suite list; added new §18F with concrete commands for
     memory add/replace/remove, the security-scan rejection case,
     `session-search`, and the full `memory-review` → `memory-review-list` →
     `memory-review-approve` flow.
   - `README.md`: added the 6 new CLI commands to the Usage table, the 4 new
     tools to the Tools table, a new "Curated memory and session review"
     section (matching the style of the existing "Local ML" section), and
     the 3 new top-level modules to the project layout tree.

3. **User decisions (resolved):**
   - Scaffold layer: not dead code, don't delete — but verify its
     documentation actually reflects reality rather than leaving it
     untouched on faith. Acted on below.
   - `bash_security.py` vs. the live bash tool's thinner inline check:
     leave as-is for now; tracked as a standalone follow-up, not part of
     this cleanup.
   - Efficiency review: continue across all 115 files, not just the
     "working runtime" subset.

4. **Verified the scaffold layer's documentation against reality, per the
   user's ask, rather than leaving it untouched:**
   - `bash_security.py`'s claimed "163 tests" — confirmed exactly accurate
     (`python -m pytest tests/test_bash_security.py -q` → `163 passed`).
     This file uses `import pytest` / plain functions, not
     `unittest.TestCase` — **`python -m unittest discover` cannot collect
     it at all** (confirmed: running it directly errors with "Ran 1 test...
     FAILED" — the loader's own import-failure placeholder, not real test
     results). It only runs correctly via `python -m pytest`.
   - **This traced back to a bigger problem: my own "baseline" all session
     was wrong.** This dev environment never had `fastapi`/`uvicorn`/
     `pydantic` (`pyproject.toml`'s actual runtime deps, not just the
     `test` extra) installed — only bare Python. That's exactly the
     "~80 GUI/service tests fail at import" scenario CLAUDE.md warns about,
     compounded by the pytest-collection gap above. After
     `pip install -e ".[test]"` (which pulls the real runtime deps too) and
     switching to `python -m pytest tests/` instead of `unittest discover`:
     **1513 tests, 17 failing, 0 collection errors** — a completely
     different picture from the ~1166/12-failures/29-errors number used
     earlier in this session. All 22 ruff/vulture fixes were re-verified
     safe against this correct baseline (same 17 failures before/after, all
     genuinely POSIX-specific: dotenv-guard symlink/grep, bash streaming +
     self-authored-script banner, MCP stdio transport, `platform_info`'s
     Linux/macOS branches, background-process kill semantics).
   - **This falsified a documented claim.** CLAUDE.md and README.md both
     said the GUI/service test stack "does not run at all" on Windows. False
     on this machine once real dependencies are installed — they pass
     cleanly. Corrected both files with what was actually verified (not a
     blanket claim beyond this one verified setup), and fixed README's
     stale "1086 tests" figure to match CLAUDE.md's already-current 1205
     (Arch-verified).
   - `docs/ECOSYSTEM.md` / `CLAUDE.md` changed on disk mid-session — another
     agent added a 5th ecosystem repo, `Chymaera_Sentry` (Go security agent,
     read-only session-file poller, port 8930, contract status
     **proposed**). Not reverted, re-read in full, consistent and
     well-formed — no action needed from this thread.

### Efficiency review across all 115 files — results (DONE)

Ran 6 parallel report-only review agents by subsystem group (core runtime,
runtime modules, session/compaction/memory, scaffold+utility, CLI/plugins,
GUI+service+chymaera+desktop+ml), each briefed on the scaffold-vs-working-
runtime distinction. 17 findings came back; every one was independently
verified against the actual code (not taken on faith) before anything was
applied. One turned out to be a genuine correctness bug, not just
inefficiency.

**Bug fixed (not just slow — wrong):**
- `session_memory_compact.py`'s `adjust_index_to_preserve_api_invariants`:
  `keep_from = idx` was set *before* the line that used the old value to
  scan for newly-included tool_result ids, so `messages[idx:keep_from]` was
  always `messages[idx:idx]` — permanently empty. This silently broke
  multi-hop tool_use/tool_result chain preservation during session-memory
  compaction. No test existed for this function at all (new file,
  `tests/test_session_memory_compact.py`, 4 tests) — one specifically
  constructs the 2-hop chain that proves the fix (confirmed it fails on the
  original code, passes after the fix).

**Dead code removed** (each verified via repo-wide grep before deletion):
- `agent_context.py`: `get_git_status()` — orphaned wrapper, the real path
  (`_get_git_status_cached`) is used directly elsewhere.
- `bash_security.py`: `_deny()` — `SecurityBehavior.DENY` is checked for but
  never produced; no validator in the file ever calls it.
- `commands.py` / `tools.py`: `command_names()` / `tool_names()` — dead
  duplicates of `built_in_command_names()`, not `__all__`-exported, zero
  references anywhere including tests.
- Deliberately **not** removed: `release_notes.py`'s `get_all_release_notes`
  — unlike the above, it's `__all__`-exported public API directly mirroring
  the ported `releaseNotes.ts`'s own surface, same category as the scaffold
  layer discussion, not an accidental orphan. Left in place.

**Real bugs fixed inside the scaffold layer itself** (per the user's "ensure
it's updated as needed" — these are internal correctness issues within
already-tracked ported code, not the "should this be wired in" question):
- `bash_security.py`: `GIT_READ_ONLY_SUBCOMMANDS` contained the two-word
  string `'stash list'`, but `is_command_read_only` only ever compares
  against the single-token `parts[1]`, so it could never match — `git stash
  list` (read-only) was misclassified. Fixed to also check the two-word
  form; added `165 tests` (was 163) and updated `PARITY_CHECKLIST.md`'s
  count to match.
- `ide_path_conversion.py`: `WindowsToWSLConverter.to_local_path` duplicated
  `check_wsl_distro_match`'s exact logic inline instead of calling it — two
  copies of the same distro-matching regex check that could silently drift.
  Now calls the shared function.

**Efficiency fixes** (all behavior-preserving, each verified against its
existing test suite plus new tests where coverage was missing):
- `agent_session.py`: `AgentSessionState.create` computed the same joined
  system/user-context string twice per session start (once for `content`,
  again for `blocks`) — now computed once.
- `agent_tools.py`: `_run_bash` joined+stripped command output twice (once
  for the tool result, again for the metadata preview) — now once.
- `lsp_runtime.py`: `outgoing_calls()` walked the whole workspace index
  twice in a row — now once, shared.
- `mcp_runtime.py`: `render_resource()` resolved the resource via
  `get_resource()`, then `read_resource()` re-resolved it from scratch
  (each resolution can spawn a subprocess per configured MCP server) —
  `read_resource` now accepts the already-resolved resource.
- `background_runtime.py`: `render_logs()`/`render_attach()` loaded the
  session record from disk, then called `read_logs()` which loaded it
  *again* — now loaded once and passed through.
- `task_runtime.py`: `complete_task()` persisted the task store twice (once
  via `update_task`, again if any blocked tasks got unblocked) — now
  persists once regardless.
- `config_runtime.py`: `set_value()` read the target config file twice
  (once for the payload, again for the raw preview text) and did a full
  re-discovery of *every* config source after writing *one* file — now
  reads once and patches just the written source in place (only two
  sources ever exist: `project`, `local`, in that fixed order). Added a
  test exercising two sequential `set_value` calls on one runtime instance
  to prove the in-place merge/ordering is correct.
- `compact.py`: post-compaction token count was computed twice over
  overlapping message ranges — now computed once and reused.
- `microcompact.py`: a constant string's token count was recomputed inside
  a per-message clearing loop — hoisted out. Module had **zero test
  coverage** before this session; added `tests/test_microcompact.py` (9
  tests) covering the trigger, clearing, and edge cases.
- **10 GUI route files** (account/ask_user/remote/remote_trigger/search/
  team/workflow/worktree/tasks/plans `_routes.py`): every mutating endpoint
  did `runtime = _runtime(); runtime.mutate(...); return
  _serialize(_runtime())` — reloading and re-parsing the just-written state
  file instead of reusing the already-mutated `runtime` object in hand.
  Verified each underlying `*Runtime` mutation method actually updates
  `self` in place (not just persists to disk) before making this change.
  All 44 GUI API tests still pass, including the worktree cwd-swap case
  that was the trickiest one to reason about.
- `ml/embeddings.py`: `_mean_pool` hand-rolled mean-pooling with nested
  pure-Python loops over what's actually a numpy array (onnxruntime's
  output) — rewritten with vectorized numpy ops. `numpy` moved into the
  same guarded import block as `onnxruntime` (never a hard dependency —
  numpy is already a transitive dependency of onnxruntime, so this doesn't
  change the "importing this module never fails without the `ml` extra"
  guarantee). Zero existing test exercised this function at all — added
  `MeanPoolTest` (4 tests) to `tests/test_ml_embeddings.py`, including a
  check that the result is plain Python floats, not numpy scalars.
- `main.py`: `build_port_manifest()` (walks the entire `sarina/` package
  tree) ran unconditionally on *every* CLI invocation, including every real
  `agent`/`agent-chat` run, even though only 3 of ~100 subcommands
  (`summary`, `manifest`, `subsystems`) use it. Made lazy.
- `agent_runtime.py`: `load_agent_registry()` (globs + parses every
  `.claude/agents/*.md` file) had no caching, and was reloaded from scratch
  on *every* `delegate_agent`/`Agent` tool call within a single run, on top
  of the reload already done once for the system prompt. Added an
  instance-lifetime cache. **This required care**: had to invalidate it in
  4 places — the 3 `render_agent_{create,update,delete}_report` methods and
  `_apply_runtime_cwd_update` — or a `/agents create` followed by `/agents`
  within the same session would show a stale pre-creation snapshot. Wrote
  a regression test that populates the cache *before* mutating (the
  existing create/update/delete test happened not to exercise this, since
  it never called a cache-reading method before its first mutation) and
  confirmed it fails without the invalidation and passes with it.

**Deliberately left alone** (documented, not silently dropped):
- `lsp_runtime.py`'s `query()` dispatcher calls both a raw method (for
  counts) and the matching `render_*` method (for text) separately, and
  each `render_*` independently recomputes the same underlying query —
  real duplicated work across 6 operation branches, but fixing it safely
  needs threading pre-computed results through 6 render methods with
  slightly different signatures. Higher risk/complexity than the fixes
  above for a bounded win (the expensive part, per-file AST parsing, is
  already cached; only the directory walk + stat calls repeat). Left as a
  scoped follow-up rather than risking the LSP tool's correctness in a
  cleanup pass.
- `gui/server.py`'s `list_sessions`/`list_file_history` both independently
  read every session file on every call — real but the reviewing agent
  itself judged it not worth fixing given the deliberate single-operator,
  no-premature-indexing design already established elsewhere in this
  codebase. Left as-is.

**Final verification:** full suite via `python -m pytest tests/` —
**1515 passed, 17 failed** (the same 17 pre-existing POSIX-specific
failures throughout this entire session, confirmed by name every single
time), 0 collection errors. `ruff check sarina/ --select F,E9,W6` — clean.

### Closed

This thread (codebase-wide dead-code/efficiency audit + doc review) is
complete. Future sessions: start a new dated entry above this line rather
than reopening this one.

---

## 2026-09-26 — Removed the inherited ClawCode "mirror npm Claude Code" apparatus

**Ask:** the user pushed back on the prior thread's "leave the scaffold layer
alone, it's tracked work" conclusion — the real question wasn't "is this dead
code" but "is this even part of what Sarina is anymore." Sarina forked from
ClawCode (itself built on instructkr/claw-code), whose mission was mirroring
the npm Claude Code CLI 1:1 in Python. That's a different mission from what
Sarina actually became: the local-model agent for the Chymaera ecosystem.

### What was found and removed

Mapped every dependency by hand (not just the original 19-module estimate —
grepping surfaced a wider web: `execution_registry.py`, `tool_pool.py`,
`system_init.py`, `setup.py`, `prefetch.py`, `deferred_init.py`,
`release_notes.py`, `permissions.py`, `transcript.py`, `models.py`,
`history.py`, and `gui/diagnostics_routes.py` all turned out to belong to
the same apparatus, not just the original 19). Verified before deleting,
not assumed:
- `cost_tracker.py`: confirmed via grep that the real agent's cost tracking
  (`agent_runtime.py`) never imports it — it uses `ModelPricing`/
  `total_cost_usd` directly. Purely decorative.
- `release_notes.py`: confirmed the *real*, live `/release-notes` slash
  command (`_handle_release_notes` in `agent_slash_commands.py`) implements
  its own changelog parsing directly and never calls this module's
  `parse_changelog`/`check_for_release_notes` at all — despite
  PARITY_CHECKLIST.md claiming this was "done" and wired in.
- `permissions.py`'s `ToolPermissionContext`: confirmed distinct from the
  real `AgentPermissions` (agent_types.py) used everywhere for
  `--allow-write`/`--allow-shell` — only ever used by the mirrored `tools`
  inventory command.
- `query_engine.py`'s `QueryEnginePort` genuinely CAN wrap and drive the real
  `LocalCodingAgent` (`use_runtime_agent=True` mode) — checked carefully
  before removing. But confirmed the real `agent`/`agent-chat`/`agent-resume`
  CLI commands never construct one; that mode was only ever exercised by
  `runtime.py`'s `PortRuntime` backing the `bootstrap`/`turn-loop` demo
  commands, which are also gone.

**Removed: 31 source modules, `reference_data/` (3 JSON files), ~19 CLI
commands from `main.py`, `gui/diagnostics_routes.py` + its GUI frontend
(a whole "Diagnostics" tab in `app.js`/`index.html`/`app.css`), 20 test
files, and `PARITY_CHECKLIST.md`** (user chose "delete" over "retire" or
"replace with a status doc" — its entire subject no longer exists).

Also cleaned up: `sarina/__init__.py`'s exports (dropped everything from
the removed modules, added the previously-missing `MemoryRuntime`),
`pyproject.toml`'s now-stale `reference_data/*.json` package-data entry.

### What was deliberately kept

- `task.py` (`PortingTask`) — despite the "Porting" name, this is the real
  dataclass `task_runtime.py` (heavily used, GUI-wired) depends on. Naming
  collision with the apparatus's `PortingModule`/`PortingBacklog` in the
  now-deleted `models.py`, not an actual relationship.
- The 11 originally-flagged "ported but unwired" modules' *logic* is gone
  with the files, but nothing that duplicated real functionality was found
  missing afterward — full test suite confirms zero regressions.

### Verification

- `python -c "from sarina.main import main"`, `"import sarina"`, and
  `"from sarina.gui.server import create_app"` all import cleanly.
- `ruff check sarina/ --select F,E9,W6` — clean, no orphaned references.
- Full suite: **975 tests total (960 passed, 15 failed)** — the failures are
  the exact same pre-existing POSIX-only set from every prior check this
  session (2 of the original 17 were `platform_info.py`'s own tests,
  correctly gone with the file — not a new gap). **Zero new regressions**
  from removing ~550 lines... actually ~11,000+ lines of source/tests.
- CLI smoke-tested (`--help`, `agent-context`) — command list is now 100%
  real functionality, no inventory/demo commands.

### Documentation rewritten to match

- `README.md`: mission statement rewritten (no longer "reimplement the full
  agent flow" framed as mirroring npm Claude Code — now describes what
  Sarina actually is, the Chymaera-ecosystem agent). ClawCode/
  instructkr-claw-code attribution **kept, factually updated** (per the
  user's explicit ask to keep example-repo references accurate, not erase
  them) to note the mirroring layer it inherited was removed. Chymaera
  Ecosystem table updated to 5 repos (added `Chymaera_Sentry`, proposed
  contract, matching `docs/ECOSYSTEM.md`/`CLAUDE.md` which another session
  had already updated). Project layout, Testing section (current honest
  count: 975/960, flagged Arch's old 1205 figure as stale), and Disclaimer
  updated.
- `TESTING_GUIDE.md`: removed §3 "Mirrored Workspace And Inventory Commands"
  entirely, removed the query-engine-style helper commands from §20, fixed
  §1.6's test list, rewrote the Maintenance Rules (no more "update
  PARITY_CHECKLIST.md" instruction).
- `CLAUDE.md`: build/test section rewritten — recommends `pytest` over
  `unittest discover` outright now (rather than only for one specific
  now-deleted test file), current test counts, and a note explaining why
  the apparatus is gone instead of the stale "1513 tests" snapshot.
- `docs/ECOSYSTEM.md`, `packaging/arch/README.md`, `blackarch_compat/
  README.md`, `benchmarks/README.md` — checked, no stale references found
  (confirmed via repo-wide grep for every removed module/file name).

### Mid-session external context

Two messages arrived from the user while this was in progress, both
addressed inline rather than deferred:
1. "Ensure references are updated... especially example repos" — informed
   how the ClawCode attribution was rewritten (corrected, not deleted) and
   confirms the Hermes Agent citation from the prior memory-feature session
   should stay accurate too (checked, still accurate, untouched).
2. Chymaera_Sentry local path pointer (`C:\...\Chymaera_Sentry`) — used to
   understand the user has that repo open locally for reference, not
   written into README (a contributor's local filesystem path doesn't
   belong in a public doc); acted on by adding Chymaera_Sentry to the
   ecosystem table using the description already agreed in
   `docs/ECOSYSTEM.md`/`CLAUDE.md`.

### Closed

Not committed yet — user has not asked for a commit on this phase.
