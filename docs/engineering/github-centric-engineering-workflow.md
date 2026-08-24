# GitHub-Centric Engineering Workflow

GGEN MUST BE DEVELOPED USING A GITHUB-CENTRIC WORKFLOW.

GitHub is the canonical engineering source of truth.

The local/sandbox environment is ONLY an execution and verification environment.

--------------------------------------------------
CANONICAL SOURCE OF TRUTH
--------------------------------------------------

Treat these as authoritative, in this order:

1. GitHub repository state
2. GitHub branches
3. GitHub commits
4. GitHub pull requests
5. GitHub Actions / CI results
6. Repository documentation
7. Local working tree
8. Agent memory / previous claims

Never treat previous agent statements as authoritative if GitHub can verify the fact.

If local state conflicts with GitHub:

STOP.

Investigate the discrepancy.

Do NOT blindly push local state.

--------------------------------------------------
GITHUB-FIRST PROCEDURE
--------------------------------------------------

Before making any meaningful change:

1. Inspect the GitHub repository.
2. Verify the current `main` commit SHA.
3. Verify relevant recent commits.
4. Verify branch state.
5. Inspect relevant files from the repository.
6. Inspect existing GitHub Actions workflows.
7. Inspect current CI status.
8. Only then inspect/use the local checkout.

The local checkout must be synchronized with the intended GitHub state before implementation.

--------------------------------------------------
LOCAL ENVIRONMENT POLICY
--------------------------------------------------

Local tools may be installed or used ONLY when they are genuinely required for:

- compilation
- formatting
- static analysis
- unit/widget tests
- APK generation
- device validation
- repository tooling

Examples:

- Dart SDK
- Flutter SDK
- Android SDK components
- Gradle dependencies
- required CLI utilities

However:

DO NOT download software merely because it might be useful.

DO NOT install random packages/tools without a concrete engineering reason.

DO NOT replace the repository's pinned toolchain with an arbitrary newer version.

First inspect:

- CI toolchain versions
- repository configuration
- pubspec constraints
- workflow files
- existing scripts

Then use the same/pinned versions whenever possible.

--------------------------------------------------
NO LOCAL-ONLY DEVELOPMENT
--------------------------------------------------

Never consider work complete merely because:

- it works in the sandbox
- local tests pass
- local APK builds
- local analyzer passes

Completion requires the relevant GitHub state to reflect the work.

The expected flow is:

GitHub state
    ↓
local synchronized checkout
    ↓
implementation
    ↓
local verification
    ↓
commit
    ↓
push / PR
    ↓
GitHub Actions
    ↓
CI verification
    ↓
GitHub becomes canonical final state

--------------------------------------------------
COMMIT DISCIPLINE
--------------------------------------------------

Every meaningful implementation stage should produce a meaningful Git commit.

Commit messages must describe the actual change.

Never:

- invent a SHA
- invent a CI result
- claim a push that was not verified
- claim a merge that was not verified
- force-push
- rewrite main history
- push an unrelated local reconstruction

After pushing:

VERIFY THE ACTUAL REMOTE SHA.

Do not infer it.

--------------------------------------------------
BRANCH / PR POLICY
--------------------------------------------------

Prefer:

feature branch
    ↓
implementation
    ↓
tests
    ↓
commit
    ↓
push
    ↓
PR
    ↓
CI
    ↓
merge when valid

If the repository's established workflow permits direct `main` commits for a specific maintenance operation, follow the repository rules.

Do not bypass existing branch protection/governance.

Never force-push.

--------------------------------------------------
CI IS THE FINAL SOFTWARE VALIDATION
--------------------------------------------------

Local tests are preliminary evidence.

GitHub Actions is authoritative for repository CI.

After pushing:

1. Locate the exact commit on GitHub.
2. Inspect all relevant check runs.
3. Wait for completion where necessary.
4. Inspect failures instead of assuming they are unrelated.
5. Fix failures.
6. Push a follow-up commit.
7. Re-check CI.

Do NOT report:

"CI green"

unless GitHub actually shows green.

--------------------------------------------------
APK BUILD POLICY
--------------------------------------------------

APK builds may be performed locally or through GitHub Actions depending on repository architecture.

Before attempting an APK build:

1. Inspect the repository's Android build workflow.
2. Determine whether Android platform files are intentionally generated/managed externally.
3. Prefer the established `android-build.yml` or repository-supported build mechanism.
4. Do not introduce an Android project structure merely because the local environment lacks one.
5. Do not commit generated APKs or large build artifacts unless repository policy explicitly requires it.

If a local APK is produced:

- treat it as a validation artifact
- do not treat it as the canonical repository state
- record the source commit SHA
- record the toolchain used
- record whether the APK corresponds exactly to GitHub main/PR state

--------------------------------------------------
DEPENDENCY / SOFTWARE INSTALLATION POLICY
--------------------------------------------------

Before installing anything locally, answer:

1. Is it required?
2. Is it already available?
3. Is it specified by the repository?
4. Is it specified by CI?
5. Is there an existing repository script for it?
6. Can the task be completed without installing it?

If not required:

DO NOT INSTALL IT.

Avoid:

- unnecessary SDK downloads
- duplicate Flutter/Dart versions
- random global npm/pip packages
- unrelated system packages
- large model downloads
- arbitrary build tools
- temporary software that changes the environment unpredictably

Keep the environment reproducible.

--------------------------------------------------
TOOLCHAIN REPRODUCIBILITY
--------------------------------------------------

When a toolchain is required:

Prefer the exact versions used by CI.

For example, if the repository CI specifies:

Flutter 3.47.0
Dart 3.13.0

use those versions for validation instead of silently using:

Flutter beta
Dart beta
or another newer release.

If a local version differs from CI:

DO NOT declare the repository validated.

Instead either:

- install/use the pinned version, or
- explicitly report that validation was performed against a different toolchain.

--------------------------------------------------
LOCAL CHANGES MUST BE TRACEABLE
--------------------------------------------------

Before pushing any local change:

Run:

git status
git diff
git log
git remote -v
git branch --show-current

Then verify:

- intended files only
- no accidental generated files
- no secrets
- no credentials
- no local machine paths
- no unrelated modifications

Never push a dirty/unreviewed reconstruction.

--------------------------------------------------
SECRETS / TOKENS
--------------------------------------------------

NEVER commit:

- GitHub PATs
- API keys
- passwords
- private credentials
- tokens
- device secrets

Never place credentials in:

- git remote URLs
- source files
- documentation
- test fixtures
- logs

If a credential is exposed in conversation, local configuration, logs, or command history:

STOP and report it.

Recommend rotation/revocation immediately.

--------------------------------------------------
DOCUMENTATION MUST FOLLOW GITHUB STATE
--------------------------------------------------

Documentation must describe the state that actually exists in GitHub.

Do not write:

"implemented"

until the implementation exists in the repository.

Do not write:

"CI validated"

until GitHub CI confirms it.

Do not write:

"device validated"

until actual device evidence exists.

Do not write:

"APK available"

unless an actual APK artifact exists and its source commit is known.

--------------------------------------------------
SANDBOX RESET / LOCAL STATE LOSS
--------------------------------------------------

The local environment may be reset, reconstructed, or partially lost.

Therefore:

NEVER assume local files represent the previous session.

When starting a new session:

GitHub → reconstruct local state.

NOT:

memory → reconstruct local state → push.

If the local checkout appears newer/older/different from GitHub:

do not merge the states blindly.

First determine which state is canonical.

--------------------------------------------------
FINAL HANDOFF REQUIREMENT
--------------------------------------------------

At the end of the milestone, the handoff MUST contain:

- repository
- branch
- verified GitHub HEAD SHA
- commits made
- PR number if applicable
- CI status
- exact test results
- toolchain versions
- APK status
- device validation status
- documentation updated
- known limitations
- remaining work
- exact next recommended action

Every factual statement must be traceable to GitHub, CI, device evidence, or an explicitly identified local verification.

FINAL PRINCIPLE:

GitHub is the memory.

The local environment is the workshop.

The agent's conversation memory is NOT the source of truth.
