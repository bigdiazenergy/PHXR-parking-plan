# PHXR Parking Plan Agent Instructions

Meka/OpenClaw is authorized by the boss to make future updates to this PHXR parking plan repository, including committing, pushing, and publishing the static GitHub Pages site.

## Scope

- Main repository: `H:\AI\PHXR-parking-plan`
- Main branch: `main`
- Live site: `https://bigdiazenergy.github.io/PHXR-parking-plan/`
- Primary site file: `index.html`

## Update Rules

- Preserve unrelated parking plan data when making a focused update.
- For trailer audit updates, apply the latest audit to every audit tab: AM, PM, Transition AM, and Transition PM.
- For OOS updates, replace the prior OOS set with the latest source. Remove stale OOS notations from assets that are no longer on the current OOS report.
- Preserve inbound, Drop Lot, and other existing sections unless the requested update changes them.
- Do not stage backup files such as `*.bak*`.

## Publish Workflow

Use `scripts\meka-publish.ps1` from this repo after editing and reviewing `index.html`.

Example:

```powershell
.\scripts\meka-publish.ps1 -Message "Update trailer audit" -ExpectedText "08/14/2026"
```

The script checks the branch, stages only approved site files, commits if needed, pushes to GitHub, and verifies the live Pages URL.

## GitHub Auth

Preferred auth is a dedicated fine-grained GitHub token for only `bigdiazenergy/PHXR-parking-plan`, stored outside this repo as `MEKA_GITHUB_TOKEN`.

Minimum token permissions:

- Contents: read and write
- Actions: read
- Pages: read, if available

If no token is present, the script uses the Windows user's existing Git Credential Manager auth.
