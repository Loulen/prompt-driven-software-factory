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

Le script est **`install.sh`**, à la racine du dépôt. Une fois une URL de bootstrap publiée, la
commande figée sera :

```sh
curl -fsSL <URL-du-bootstrap> | sh          # URL renseignée à la publication
```

En attendant, on l'exécute depuis un checkout local — c'est **la** commande concrète aujourd'hui :

```sh
sh install.sh [DOSSIER_CIBLE]               # défaut : le dossier courant
sh install.sh --help                        # options + contrat de variables
```

Le bootstrap :

1. **Résout la source des skills** — un dépôt cloné en `git --depth 1`, une archive `curl`, ou un
   checkout local via `PDSF_SRC` (voir [Mode hors-ligne](#mode-hors-ligne)).
2. **Demande le harness** et y émet **tous** les skills (énumérés depuis `skills/*/`, jamais codés
   en dur) :
   - Claude Code → `.claude/skills/<skill>/`
   - Copilot → `.github/prompts/<skill>.prompt.md`
   - puis câble le fichier d'agent (`CLAUDE.md` pour Claude, `AGENTS.md` sinon) via un bloc marqué
     `<!-- PDSF:BEGIN -->…<!-- PDSF:END -->` — **ré-exécutable**, jamais dupliqué.
3. **Demande si le dépôt est un monorepo** (voir ci-dessous).
4. **Passe la main à `/build-factory`**.

Il n'installe **jamais** dans le dépôt source PDSF lui-même : il refuse et réclame un dossier cible.

### Contrat de variables d'environnement

Chaque prompt a un équivalent `PDSF_*`. Une variable **définie** (même vide) répond à la question
sans l'afficher — c'est ainsi qu'un run **non-interactif** est piloté ; laissée **absente**, la
question est posée sur `/dev/tty` (chemin **interactif** nominal).

| Variable | Sens | Défaut |
| --- | --- | --- |
| `PDSF_SRC` | Checkout PDSF local d'où installer (`skills/`, `CONTEXT.md`, `docs/`). Force le mode **hors-ligne**. | (fetch réseau) |
| `PDSF_HARNESS` | `claude` (→ `.claude/skills/`) ou `copilot` (→ `.github/prompts/`). | `claude` |
| `PDSF_MONOREPO` | `y`/`n` — installer une factory autonome par contexte (`.factory/<ctx>/`) ? | `n` |
| `PDSF_CONTEXT` | Monorepo : nom du contexte / de la factory. | (demandé) |
| `PDSF_MEMBERS` | Monorepo : sous-dossiers membres à câbler, séparés par espace ou virgule. Vide = aucun. | (demandé) |
| `PDSF_ACTION` | Outil résident : `create` (ou `1`) / `wire` (ou `2`). | `create` |
| `PDSF_AGENTFILE` | Force le fichier d'agent câblé. | `CLAUDE.md` / `AGENTS.md` |
| `PDSF_REPO`, `PDSF_TARBALL` | Sources de fetch alternatives quand `PDSF_SRC` est absent. | dépôt public |

### Mode hors-ligne

`PDSF_SRC=<checkout>` fait tourner l'installeur **sans réseau** : aucun clone, aucun téléchargement,
il copie depuis le checkout indiqué. C'est aussi le **seam de test** de la suite agentique. Exemple
d'un run non-interactif complet, mono-projet, dans un dossier cible :

```sh
PDSF_SRC=/chemin/vers/pdsf PDSF_HARNESS=claude PDSF_MONOREPO=n \
  sh install.sh /chemin/vers/mon-projet
```

## Monorepo

Sur `monorepo = oui`, chaque **contexte métier** devient une **factory autonome** dans
`.factory/<contexte>/` :

- sa propre copie de `skills/`, plus les docs de domaine du contexte (`CONTEXT.md`, `docs/adr/`,
  `docs/agents/`, `AGENTS.md`) ;
- les sous-projets membres sont reliés par des **symlinks relatifs, un par skill**, dans leur
  `.claude/skills/`, plus un pointeur relatif depuis leur `AGENTS.md` (`CLAUDE.md` → `AGENTS.md`) ;
- **rien n'est chargé à la racine** du monorepo.

Le seul artefact partagé est **`.factory/pdsf-install.sh`** — une **copie octet-pour-octet** de
`install.sh`, écrite par le bootstrap lors du premier passage en monorepo (source unique : on ne
maintient jamais deux corps de script). Second point d'entrée résident et **re-jouable**, il se
détecte lui-même via son emplacement sous `.factory/`. On l'invoque depuis la racine du monorepo :

```sh
.factory/pdsf-install.sh                     # menu : créer une factory / câbler des sous-dossiers
# non-interactif :
PDSF_ACTION=wire PDSF_CONTEXT=<ctx> PDSF_MEMBERS="apps/api" .factory/pdsf-install.sh
```

Il crée une factory (nommée par l'utilisateur) ou rattache un ou plusieurs sous-dossiers à une
factory sélectionnée ; il découvre les factories existantes en listant `.factory/*/` (pas de fichier
de registre). Une factory créée par l'outil résident réutilise les skills d'une factory existante
comme gabarit — pas besoin de réseau.

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
