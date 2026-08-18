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

Le script est **`install.sh`**, à la racine du dépôt. La commande de référence :

```sh
curl -fsSL https://raw.githubusercontent.com/Loulen/prompt-driven-software-factory/main/install.sh | sh
```

> Tant que `install.sh` n'est pas sur la branche `main` du dépôt, le `curl` renvoie 404 :
> publier d'abord.

On peut aussi l'exécuter depuis un checkout local (fetch réseau, sauf `PDSF_SRC` — voir
[Mode hors-ligne](#mode-hors-ligne)) :

```sh
sh install.sh [DOSSIER_CIBLE]               # défaut : le dossier courant
sh install.sh --help                        # options + contrat de variables
```

Le bootstrap :

1. **Résout la source des skills** — un dépôt cloné en `git --depth 1`, une archive `curl`, ou un
   checkout local via `PDSF_SRC` (voir [Mode hors-ligne](#mode-hors-ligne)).
2. **Émet tous les skills** (énumérés depuis `skills/*/`, jamais codés en dur) au **format générique** :
   des skills réguliers (dossiers `SKILL.md`) sous `.agents/skills/`, plus un `AGENTS.md` câblé via un
   bloc marqué `<!-- PDSF:BEGIN -->…<!-- PDSF:END -->` (**ré-exécutable**, jamais dupliqué). `AGENTS.md`
   est le standard inter-harness que **Copilot, Cursor, Codex…** lisent déjà.
3. **Demande le harness** — `generic` (défaut) ou `claude`.
4. **Demande si le dépôt est un monorepo** (voir ci-dessous).
5. **Passe la main à `/build-factory`**.

Il n'installe **jamais** dans le dépôt source PDSF lui-même : il refuse et réclame un dossier cible.

### Harness : `generic` (défaut) ou `claude`

La base est **générique** et se suffit à elle-même — `.agents/skills/` + `AGENTS.md`. Le choix
`claude` ne fait qu'**ajouter un overlay de symlinks** par-dessus cette base, pour que Claude Code
retrouve ses chemins :

| Harness | Ce qui est posé |
| --- | --- |
| `generic` (défaut) | `.agents/skills/<skill>/` (fichiers réels) + `AGENTS.md` câblé. Lu par Copilot, Cursor, Codex, … |
| `claude` | le générique **+** `.claude/skills → ../.agents/skills` **+** `CLAUDE.md → AGENTS.md` (symlinks relatifs). |

Copilot n'a donc **pas** de traitement spécifique : il consomme le `AGENTS.md` générique comme les
autres. « Avoir Claude, c'est juste un symlink au-dessus du défaut générique. »

### Contrat de variables d'environnement

Chaque prompt a un équivalent `PDSF_*`. Une variable **définie** (même vide) répond à la question
sans l'afficher — c'est ainsi qu'un run **non-interactif** est piloté ; laissée **absente**, la
question est posée sur `/dev/tty` (chemin **interactif** nominal).

| Variable | Sens | Défaut |
| --- | --- | --- |
| `PDSF_SRC` | Checkout PDSF local d'où installer (`skills/`, `CONTEXT.md`, `docs/`). Force le mode **hors-ligne**. | (fetch réseau) |
| `PDSF_HARNESS` | `generic` (`.agents/skills/` + `AGENTS.md`) ou `claude` (générique + overlay symlinks). | `generic` |
| `PDSF_MONOREPO` | `y`/`n` — installer une factory autonome par contexte (`.factory/<ctx>/`) ? | `n` |
| `PDSF_CONTEXT` | Monorepo : nom du contexte / de la factory. | (demandé) |
| `PDSF_MEMBERS` | Monorepo : sous-dossiers membres à câbler, séparés par espace ou virgule. Vide = aucun. | (demandé) |
| `PDSF_ACTION` | Outil résident : `create` (ou `1`) / `wire` (ou `2`). | `create` |
| `PDSF_REPO`, `PDSF_TARBALL` | Sources de fetch alternatives quand `PDSF_SRC` est absent. | dépôt public |

### Mode hors-ligne

`PDSF_SRC=<checkout>` fait tourner l'installeur **sans réseau** : aucun clone, aucun téléchargement,
il copie depuis le checkout indiqué. C'est aussi le **seam de test** de la suite agentique. Exemple
d'un run non-interactif complet, mono-projet, dans un dossier cible :

```sh
PDSF_SRC=/chemin/vers/pdsf PDSF_HARNESS=generic PDSF_MONOREPO=n \
  sh install.sh /chemin/vers/mon-projet
```

## Monorepo

Sur `monorepo = oui`, chaque **contexte métier** devient une **factory autonome** dans
`.factory/<contexte>/` :

- sa propre copie de `skills/`, plus les docs de domaine du contexte (`CONTEXT.md`, `docs/adr/`,
  `docs/agents/`, `AGENTS.md`) ;
- les sous-projets membres sont reliés par des **symlinks relatifs, un par skill**, dans leur
  `.agents/skills/`, plus un pointeur relatif depuis leur `AGENTS.md` vers la factory. En harness
  `claude`, le membre reçoit en plus l'overlay `.claude/skills → .agents/skills` et `CLAUDE.md → AGENTS.md` ;
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
| `npx skills` | Un harness aux conventions particulières que tu veux servir explicitement. Dépend de Node. |
| Plugin Claude Code | Disponible dans tous tes projets, versionné et updatable. Les skills sont alors **préfixés** : `/pdsf:build-factory`, `/pdsf:grill-with-docs`, etc. — dans ce cas, retirer la ligne `@import` de `git-flow` dans le `AGENTS.md` généré (le skill se charge à la demande). |

## Après l'installation

`/build-factory` câble le workflow dans ton projet (deux modes : **scaffold** puis **context**), et
`/verify-factory` rejoue à tout moment un health check (sources externes joignables, driver agentique
qui se lance, santé git-flow). Voir le README.
