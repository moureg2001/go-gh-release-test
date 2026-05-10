# S3-HTTP-Server Workflows

Minimales Go-Projekt zur Validierung der CI/CD-Workflow-Kette.

[![Quality Gate Status](https://sonarcloud.io/api/project_badges/measure?project=moureg2001_go-gh-release-test&metric=alert_status)](https://sonarcloud.io/summary/new_code?id=moureg2001_go-gh-release-test)

---

## Workflows

### Übersicht

```mermaid
Entwickler                    Dependabot
    │                             │
    │ (workflow_dispatch)         │  (öffnet Dockerfile-PR)
    V                             V
 tag.yml                    dependabot-auto-merge.yml
    │                             │
    │ (workflow_call)             │ workflow_run (nach Merge)
    V                             V
trigger-ci.yml                rebuild.yml
    │                             │
    │                 repository_dispatch (new-builder-image)
    │                             │
    V                             V
[Build + Scan + Docker Push nach Nexus]
    │
    V
 release.yml (manuell)
    │
    V
  GitHub Release mit Binaries
```

---

### `trigger-ci.yml` — CI-Pipeline

**Trigger:** Push auf `main`, Tag-Push `v*`, Pull Request, `workflow_dispatch`, `workflow_call`, `repository_dispatch: new-builder-image`

**Jobs:**
-`build-and-scan` — Go Build, Unit Tests, Coverage, go vet, GitLeaks Secret Scan, SonarCloud Analyse
-`docker-build` — baut das Docker Image und pusht es mit drei Tags nach GHCR

**Docker Image Tags** (bei jedem relevanten Trigger):

| Tag | Bedeutung |
|-----|-----------|
| `1.2.3-go1.24-20260510` | exakt/reproduzierbar — Version + Go + Datum |
| `1.2.3` | stabil für diese Semver-Version |
| `latest` | immer das neueste Image |

Die Version wird aus dem letzten Git-Tag ermittelt (`git describe`). Bei einem Tag-Push wird der Tag direkt verwendet.

---

### `tag.yml` — Release-Tag erstellen

**Trigger:** Manuell (`workflow_dispatch`)

**Eingabe:** `version` — Semver-String z.B. `1.2.3`

**Ablauf:**
1.Erstellt und pusht den Git-Tag `v1.2.3`
2.Ruft direkt `trigger-ci.yml` via `workflow_call` auf → baut und pusht das Docker Image mit 3 Tags

**Verwendung:**

```mermaid
Actions → Create Tag → Run workflow → version: 1.2.3
```

---

### `release.yml` — GitHub Release mit Binaries

**Trigger:** Manuell (`workflow_dispatch`)

**Eingabe:** `version` — Semver-String z.B. `1.2.3`

**Ablauf:**
1.Erstellt Git-Tag `v1.2.3`
2.Baut Go-Binaries für `linux/amd64` und `linux/arm64`
3.Erstellt ein GitHub Release mit den Binaries und automatisch generierten Release Notes

**Verwendung:**

```mermaid
Actions → Release → Run workflow → version: 1.2.3
```

> **Hinweis:** `tag.yml` für Docker Image Releases verwenden. `release.yml` nur wenn zusätzlich herunterladbare Binaries benötigt werden.

---

### `dependabot-auto-merge.yml` — Automatischer Merge von Dockerfile-Updates

**Trigger:** PR gegen `main` mit Änderungen in der `Dockerfile`, geöffnet von `dependabot[bot]`

**Ablauf:**
-Merged Dependabot-PRs automatisch per Squash-Merge, die das Docker Base-Image aktualisieren (z.B. `golang:1.24` → `golang:1.25`)
-Nach dem Merge erkennt `rebuild.yml` die geänderte Go-Version und löst einen Rebuild aus

---

### `rebuild.yml` — Rebuild bei neuem Builder-Image

**Trigger:** Nach erfolgreichem Abschluss von `Dependabot Auto-Merge`, oder manuell (`workflow_dispatch`) (mit einen optionalem `force_rebuild` wert von true oder false).

**Ablauf:**

1.Vergleicht die Go-Version des aktuellen Runners mit der Go-Version im letzten Git-Tag
2.Bei Änderung → feuert `repository_dispatch: new-builder-image` → `trigger-ci.yml` baut das Docker Image neu mit der neuen Go-Version im Tag

**Manueller Test:**

```mermaid
Actions → Rebuild on new builder image → Run workflow → force_rebuild: true
```

---

### `dependabot.yml` — Abhängigkeits-Updates

Dependabot prüft wöchentlich (Donnerstahs, 07:00 Uhr MEZ) auf Updates in:
-Go-Module (`go.mod`)
-Docker Base-Images (`Dockerfile`)
-GitHub Actions (`.github/workflows/`)
