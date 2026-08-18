# Installation de PDSF — détails

Ce document couvre les invocations exactes et les canaux d'installation. Pour la vue d'ensemble
(philosophie, monorepo), voir la section **Installation** du [README](../README.md). Les principes
sont fixés par [ADR-0002](adr/0002-self-contained-and-harness-portable.md) (self-contained &
harness-portable) et [ADR-0003](adr/0003-monorepo-factory-per-context.md) (une factory par contexte
en monorepo).

## Bootstrap `curl … | sh`

L'installation de référence est un **bootstrap first-party, sans dépendance**. Il installe **tous**
les skills (pas de sélection à la carte), demande le harness cible et l'éventuel mode monorepo, puis
passe la main à `/build-factory`.

```sh
curl -fsSL <URL-du-bootstrap> | sh
```

> **URL et flags exacts** : renseignés par le ticket d'outillage d'installation (le script
> `install.sh` / `.factory/pdsf-install.sh`). Tant que ce ticket n'est pas livré, cette section
> décrit le comportement visé, pas encore la commande figée.

Le bootstrap :

1. **Résout la source des skills** — un dépôt cloné en `--depth 1`, une archive, ou un chemin local
   via la variable `PDSF_SRC` (sert aussi aux tests hors-ligne).
2. **Demande le harness** et y émet les skills :
   - Claude Code → `.claude/skills/`
   - Copilot → `.github/prompts/`
   - puis câble `CLAUDE.md` et/ou `AGENTS.md`.
3. **Demande si le dépôt est un monorepo** (voir ci-dessous).
4. **Passe la main à `/build-factory`**.

Les prompts acceptent des **valeurs par défaut via variables d'environnement**
(`PDSF_HARNESS`, `PDSF_MONOREPO`, `PDSF_CONTEXT`, …) pour un usage non-interactif ; l'exécution
interactive reste le chemin nominal.

## Monorepo

Sur `monorepo = oui`, chaque **contexte métier** devient une **factory autonome** dans
`.factory/<contexte>/` :

- sa propre copie de `skills/`, plus les docs de domaine du contexte (`CONTEXT.md`, `docs/adr/`,
  `docs/agents/`, `AGENTS.md`) ;
- les sous-projets membres sont reliés par des **symlinks relatifs, un par skill**, dans leur
  `.claude/skills/`, plus un pointeur relatif depuis leur `AGENTS.md` (`CLAUDE.md` → `AGENTS.md`) ;
- **rien n'est chargé à la racine** du monorepo.

Le seul artefact partagé est **`.factory/pdsf-install.sh`** — le même code que le bootstrap, second
point d'entrée résident et **re-jouable**. Il crée une factory (nommée par l'utilisateur) ou rattache
un ou plusieurs sous-dossiers à une factory sélectionnée ; il découvre les factories existantes en
listant `.factory/*/` (pas de fichier de registre).

**Anti-absence silencieuse** : les symlinks sont **relatifs** (ils survivent à un re-clone), et
`.factory/` ne doit **jamais** être exclu en sparse-checkout. Windows sans symlinks reste une
limitation connue.

## Autres canaux (escape hatches)

| Canal | Quand |
| --- | --- |
| `npx skills` | Un harness vers lequel le bootstrap n'émet pas encore. Copie les skills dans `.claude/skills/` ; dépend de Node. |
| Plugin Claude Code | Disponible dans tous tes projets, versionné et updatable. Les skills sont alors **préfixés** : `/pdsf:build-factory`, `/pdsf:grill-with-docs`, etc. — dans ce cas, retirer la ligne `@import` de `git-flow` dans le `CLAUDE.md` généré (le skill se charge à la demande). |

## Après l'installation

`/build-factory` câble le workflow dans ton projet (deux modes : **scaffold** puis **context**), et
`/verify-factory` rejoue à tout moment un health check (sources externes joignables, driver agentique
qui se lance, santé git-flow). Voir le README.
