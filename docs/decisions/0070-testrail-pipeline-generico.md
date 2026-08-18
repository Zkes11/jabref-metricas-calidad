---
nav_order: 70
parent: Decision Records
---

# Upload CI test results to TestRail via trcli over a JUnit XML contract, distributed as copy-paste templates

## Context and Problem Statement

This fork of JabRef runs its test suite on two CI platforms (CircleCI and Azure Pipelines) and wants the results stored in a test-management platform — TestRail — so that quality metrics (pass rates, failure history, flaky tests) accumulate over time instead of evaporating with each ephemeral CI build. Beyond this single repository, the whole quality pipeline should be adoptable by other repos, including non-Java ones (Python, Node).

Hard constraints shape the problem: the fork policy forbids changes to Java code, `build-logic/`, and `.github/`; TestRail is commercial (trial-only, no free tier); two different CI platforms are already in place and must behave identically; and the only artifact every test toolchain can emit without custom code is JUnit(-style) XML.

Two decisions are actually bundled here: how to get JUnit XML into TestRail, and how to distribute the resulting pipeline so another repo can adopt it.

## Decision Drivers

* Language-agnostic reusability: JUnit XML is the only universal contract across Java/Gradle, Python/pytest, Node/jest, etc.
* Zero code in consumer repos: adopting the pipeline must not require writing or maintaining an uploader.
* Identical behavior across CI platforms: the same invocation and the same semantics on CircleCI, Azure, and a laptop.
* Credentials optional with a clean skip: forks and local runs without TestRail must keep pipelines green.
* Low maintenance: case matching, batching, and retries should be vendor-maintained, not hand-rolled.
* Fork policy compliance: no Java, no `build-logic/`, no `.github/`.

## Considered Options

* Direct TestRail API v2 integration — custom uploader scripts calling the REST API (`add_result_for_case`, `add_results_for_cases`, …)
* Client libraries wrapping API v2 — `trclient` (TypeScript), `testrail-api` / `testrail-python` (community Python wrappers)
* Framework-specific plugins — e.g. `pytest-testrail`, which pushes results during the test run
* `trcli parse_junit` with `automation_id` auto-matching — Gurock's own CLI, consuming JUnit XML files directly

For the distribution of the pipeline itself:

* Copy-paste templates plus an env-var contract — a `templates/` directory consumers copy and configure
* Native reusability mechanisms as the primary approach — CircleCI orbs (registry/URL), GitHub Actions reusable workflows, Azure remote templates

## Decision Outcome

Chosen options: **`trcli` + `parse_junit`** for the upload, **distributed as copy-paste templates with an env-var contract**.

`trcli` does exactly one thing — upload JUnit XML to TestRail — and is vendor-maintained: case matching by `automation_id` (= `classname.name`), auto-creation of cases and sections, batching (50 results per API call), retries, and JUnit-to-TestRail status mapping all come for free. Any stack that can emit JUnit XML works (verified for Gradle, pytest, and jest during research). One shared script (`scripts/upload-testrail.sh`) consumes the same quoted glob in every CI, and a three-variable credential gate (`TESTRAIL_URL` / `TESTRAIL_EMAIL` / `TESTRAIL_KEY`) keeps credential-less forks green by construction: without them the script prints one skip line and exits 0.

Native reusability mechanisms (orbs, reusable workflows, remote templates) were rejected as the *primary* mechanism: they add platform lock-in, several were outside the fork's boundary (`.github/` untouchable; publishing orbs was a project non-goal), and they solve distribution for one platform at a time while the contract we actually want to distribute is platform-independent. They remain documented as a v2 evolution path in `templates/README.md`.

### Consequences

* Good, because there is no code to maintain against the TestRail API — the integration surface is one bash script plus a pinned pip install.
* Good, because the invocation is identical across CircleCI (`🧷` step), Azure Pipelines (`🚀` step), and local runs — same script, same glob, same gate.
* Good, because every CI build produces an immutable closed run (`--close-run`) — one run per build, distinguishable by title (`CircleCI #N (branch) — date` vs `Azure Pipelines #N (branch) — date`).
* Good, because the JUnit XML contract doubles as the template's API: `templates/CONTRACT.md` documents env vars and report globs, and any repo satisfying the contract gets the same behavior.
* Bad, because the solution carries an external Python dependency that must be pinned (`trcli==1.15.2`) — upgrades are deliberate decisions followed by a re-run of the smoke checklist.
* Bad, because renaming or moving a test changes its `automation_id` (`classname.name`), orphaning the old TestRail case and its history (documented behavior; mitigated by periodic cleanup and `--update-existing-cases yes` after refactors).
* Bad, because TestRail is commercial: when the trial expires, uploads hard-fail until the `TESTRAIL_*` variables are removed — a documented manual step, not an automated one.
* Bad, because copy-paste distribution does not auto-propagate: improvements to the templates must be re-copied into consuming repos.

### Confirmation

`scripts/upload-testrail.sh` is the single invocation source: both the CircleCI `build_test` job and the Azure Pipelines `Build_Test` job call it with a quoted glob (`"**/build/test-results/test/TEST-*.xml"`), and the credential gate is verified credential-free by simulating the skip locally (unset `TESTRAIL_*`, expect exit 0 and exactly one output line). `templates/CONTRACT.md` defines the env-var contract; `docs/calidad/testrail-setup-circleci.md` documents the setup and the smoke checklist that validates the live path.

## Pros and Cons of the Options

### Direct TestRail API v2 integration

Custom scripts calling the REST API directly.

* Good, because it has zero dependencies beyond an HTTP client and full control over every call.
* Bad, because case matching, section creation, batching, retries, and status mapping must all be re-implemented and maintained by hand.
* Bad, because the result is necessarily language- or ecosystem-specific, defeating reuse.

### Client libraries wrapping API v2

`trclient`, `testrail-api`, `testrail-python`.

* Good, because they give an ergonomic typed API for building applications *around* TestRail.
* Bad, because for CI result upload they still leave the matching/orchestration work to the caller.
* Bad, because each library pins the integration to one language ecosystem.

### Framework-specific plugins

E.g. `pytest-testrail`.

* Good, because results flow during the test run with rich framework context.
* Bad, because they lock the integration to one framework (this repo is Gradle/JUnit 5).
* Bad, because the relevant plugins are older and less maintained than trcli.

### `trcli parse_junit`

* Good, because it is the vendor-recommended path for "JUnit XML → TestRail in CI" and handles matching, auto-creation, batching, retries, and status mapping.
* Good, because it is language-agnostic by design: it only consumes JUnit-style XML and never runs tests.
* Neutral, because it requires a one-time TestRail setup (an `automation_id` case field) before the first upload.
* Bad, because it is an external Python dependency to pin and upgrade deliberately.

### Copy-paste templates vs. native reusability mechanisms

* Good (copy-paste), because one `templates/` directory covers all platforms uniformly and stays inside the fork's constraints.
* Good (copy-paste), because the consumer sees and owns the whole pipeline — no hidden indirection.
* Bad (copy-paste), because updates must be re-copied; there is no version pinning across repos.
* Good (native mechanisms), because they give versioned, near-zero-effort distribution per platform (reusable workflows being the strongest).
* Bad (native mechanisms), because each is platform-locked and several were unreachable within this fork's boundaries.

## More Information

* Local docs: `docs/calidad/testrail-setup-circleci.md` (setup guide for CircleCI and Azure), `docs/calidad/guia-lectura-resultados.md` (how to read CI vs TestRail results), `docs/calidad/comparativa-ci.md` (CI platform comparison), `templates/CONTRACT.md` and `templates/README.md` (the contract and adoption checklist).
* Official sources: [gurock/trcli README](https://github.com/gurock/trcli) (installation, flags, matching modes), [JUnit to TestRail mapping](https://support.testrail.com/hc/en-us/articles/12989737200276) (status mapping, properties, attachments), [Getting started with the TestRail CLI](https://support.testrail.com/hc/en-us/articles/7146548750868) (supported frameworks).
* The decision was researched and verified against official documentation in August 2026.
