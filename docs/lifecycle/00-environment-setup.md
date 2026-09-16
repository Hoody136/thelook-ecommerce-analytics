# Stage 0 — Environment Setup (As Built)

**Date:** September 2026 · **Status:** Complete · **Stage in lifecycle:** Pre-work (before Stage 1: Sources)

This document records how the development environment for this project was set up — including the deviations from the original plan and why they
happened. Written as a reference for anyone (including future me) rebuilding
this environment from scratch.

## Final state

| Component | Version / Value |
|---|---|
| OS | macOS (Apple Silicon) |
| Python | 3.14 (Homebrew) |
| dbt Core | 1.12.5 |
| dbt BigQuery adapter | 1.12.1 |
| GCP project ID | `melodic-metrics-508711-u3` |
| BigQuery location | US (required — thelook public dataset is US multi-region) |
| dbt profile name | `thelook_ecommerce` |
| Dev dataset | `dbt_jhood` |
| Repo | github.com/Hoody136/thelook-ecommerce-analytics (public) |
| Git auth | HTTPS via GitHub CLI (`gh`) |

## Steps taken

1. **GCP project + BigQuery API enabled** in the Google Cloud console.
   Key decision: datasets must be created in the **US** region to read the
   `bigquery-public-data.thelook_ecommerce` tables.

2. **Local folder + git:** `mkdir thelook-ecommerce-analytics` → `git init` →
   empty first commit → `git branch -M main`.

3. **GitHub repo:** created and linked with the GitHub CLI over HTTPS:
   `gh auth login` (browser flow — the one-time code must be entered on the
   GitHub device page), then
   `gh repo create thelook-ecommerce-analytics --public --source=. --remote=origin --push`.
   Public by design: this repo is a portfolio piece. Safety comes from
   `.gitignore`, not from repo privacy.

4. **VS Code extensions:** Python, dbt Power User, YAML (Red Hat), SQLFluff,
   Continue (local LLM bridge). GitLens deliberately skipped — VS Code's
   built-in source control covers a solo project.
   User settings added: `*.sql` → `jinja-sql` file association; 2-space
   indentation for YAML and SQL.

5. **Python virtual environment:** `python3 -m venv .venv` →
   `source .venv/bin/activate` → `pip install "dbt-bigquery==1.12.*"`.
   Pinned in `requirements.txt` so anyone can rebuild the environment.

6. **Google Cloud CLI + authentication:** `brew install --cask google-cloud-sdk`,
   then **two separate logins** (a distinction that trips everyone):
   - `gcloud auth application-default login` — credentials for *code* (dbt uses this)
   - `gcloud auth login` — credentials for the *CLI tools* (`gcloud`, `bq`)
   - `gcloud config set project &lt;project-id&gt;`
   - `gcloud auth application-default set-quota-project &lt;project-id&gt;`
     (without this, BigQuery jobs fail with misleading permission errors)

7. **dbt connection profile** at `~/.dbt/profiles.yml` — deliberately
   **outside the repo** so credentials can never be committed.
   Points at the GCP project via OAuth, `location: US`, dev dataset `dbt_jhood`.

8. **`.gitignore`** at repo root: credentials (`profiles.yml`, `*.json`,
   `.env`), dbt build artefacts (`target/`, `dbt_packages/`, `logs/`),
   Python (`.venv/`, `__pycache__/`), macOS (`.DS_Store`).

9. **Verification:** `dbt --version` (Core 1.12.5 + bigquery 1.12.1),
   BigQuery round-trip test via `bq query ... 'SELECT 1'`, repo pushes green.

## Deviations from the original plan (and why)

| Planned | What actually happened | Lesson |
|---|---|---|
| Fresh `profiles.yml` named `thelook_analytics`, dataset `dbt_dev` | A profile already existed from earlier exploration: `thelook_ecommerce` / `dbt_jhood`. Kept it (correct project + region), only raised `threads: 1 → 4` for parallel builds | Check what exists before overwriting; naming consistency matters less than correctness |
| Fresh machine, no dbt | A global **dbt Fusion 2.0 preview** was already installed and shadowed the venv's dbt on `PATH` | `which dbt` tells you *which* binary answers; the venv wins once activated. Chose dbt Core 1.12 deliberately — stable, matches all tutorials, identical in CI |
| `python3 -m venv .venv` is instant | It paused silently on `ensurepip` and got Ctrl+C'd once, leaving a half-built venv (`no such file: bin/activate`) | Silent ≠ frozen. Recreated with `rm -rf .venv` and patience |
| pip install is quick | pip's resolver backtracked ~20 versions of `google-cloud-aiplatform` before finding a compatible set | "This could take a while" is information, not an error |
| `code` command works out of the box | Required `Cmd+Shift+P` → "Shell Command: Install 'code' command in PATH" | One-time setup step on macOS |
| One Google login | Two credential stores (ADC vs CLI) — both needed | Documented above so it's never a mystery again |
| Inline `# comments` in shell snippets are safe | This machine's zsh executed them as commands | Fixed with `setopt interactivecomments` in `~/.zshrc` |

## Cost note

BigQuery free tier (1 TiB queries / 10 GiB storage per month) comfortably
covers this project. Regardless, raw data will be date-bounded to 2024-onward
at ingestion. Cost discipline is a design decision.