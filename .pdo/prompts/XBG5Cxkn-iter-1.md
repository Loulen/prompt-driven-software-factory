# PDO Runtime Preamble

You are node `XBG5Cxkn` in pipeline `implement-loop`, iteration 1.

## Inputs

- `in`: read `/home/ubuntu/prompt-driven-software-factory/.pdo/runs/20261104-102700-9fbe78d/worktree/.pdo/artifacts/_input/output.md`
- `in`: read `/home/ubuntu/prompt-driven-software-factory/.pdo/runs/20261104-102700-9fbe78d/worktree/.pdo/artifacts/b4kko9SV/iter-1/out/output.md`

## Input Images

The following images were uploaded alongside the text prompt. Use the Read tool to view them:
- `/home/ubuntu/prompt-driven-software-factory/.pdo/runs/20261104-102700-9fbe78d/worktree/.pdo/artifacts/_input/v2-t-01-before.png`
- `/home/ubuntu/prompt-driven-software-factory/.pdo/runs/20261104-102700-9fbe78d/worktree/.pdo/artifacts/_input/v2-t-02-after.png`
- `/home/ubuntu/prompt-driven-software-factory/.pdo/runs/20261104-102700-9fbe78d/worktree/.pdo/artifacts/_input/v2-t-02-before.png`
- `/home/ubuntu/prompt-driven-software-factory/.pdo/runs/20261104-102700-9fbe78d/worktree/.pdo/artifacts/_input/v2-t-05-after.png`
- `/home/ubuntu/prompt-driven-software-factory/.pdo/runs/20261104-102700-9fbe78d/worktree/.pdo/artifacts/_input/v2-t-06-after.png`
- `/home/ubuntu/prompt-driven-software-factory/.pdo/runs/20261104-102700-9fbe78d/worktree/.pdo/artifacts/_input/v2-t-06-asking.png`
- `/home/ubuntu/prompt-driven-software-factory/.pdo/runs/20261104-102700-9fbe78d/worktree/.pdo/artifacts/_input/v2-t-06-before.png`
- `/home/ubuntu/prompt-driven-software-factory/.pdo/runs/20261104-102700-9fbe78d/worktree/.pdo/artifacts/_input/v2-t-07-before.png`
- `/home/ubuntu/prompt-driven-software-factory/.pdo/runs/20261104-102700-9fbe78d/worktree/.pdo/artifacts/_input/v2-t-08-after.png`
- `/home/ubuntu/prompt-driven-software-factory/.pdo/runs/20261104-102700-9fbe78d/worktree/.pdo/artifacts/_input/v2-t-09-after.png`
- `/home/ubuntu/prompt-driven-software-factory/.pdo/runs/20261104-102700-9fbe78d/worktree/.pdo/artifacts/_input/v2-t-10-after.png`
- `/home/ubuntu/prompt-driven-software-factory/.pdo/runs/20261104-102700-9fbe78d/worktree/.pdo/artifacts/_input/v2-t-11-before.png`
- `/home/ubuntu/prompt-driven-software-factory/.pdo/runs/20261104-102700-9fbe78d/worktree/.pdo/artifacts/_input/v2-t-12-after.png`
- `/home/ubuntu/prompt-driven-software-factory/.pdo/runs/20261104-102700-9fbe78d/worktree/.pdo/artifacts/_input/v2-t-12-asking.png`
- `/home/ubuntu/prompt-driven-software-factory/.pdo/runs/20261104-102700-9fbe78d/worktree/.pdo/artifacts/_input/v2-t-13-after.png`
- `/home/ubuntu/prompt-driven-software-factory/.pdo/runs/20261104-102700-9fbe78d/worktree/.pdo/artifacts/_input/v2-t-14-after.png`
- `/home/ubuntu/prompt-driven-software-factory/.pdo/runs/20261104-102700-9fbe78d/worktree/.pdo/artifacts/_input/v2-t-15-after.png`
- `/home/ubuntu/prompt-driven-software-factory/.pdo/runs/20261104-102700-9fbe78d/worktree/.pdo/artifacts/_input/v2-t-16-after.png`
- `/home/ubuntu/prompt-driven-software-factory/.pdo/runs/20261104-102700-9fbe78d/worktree/.pdo/artifacts/_input/v2-t-17-before.png`

## Input Files

The following files were passed to the entry node alongside the text prompt (the run's attachments). Read them as part of your input:
- `/home/ubuntu/prompt-driven-software-factory/.pdo/runs/20261104-102700-9fbe78d/worktree/.pdo/artifacts/_input/chosen-design.md`
- `/home/ubuntu/prompt-driven-software-factory/.pdo/runs/20261104-102700-9fbe78d/worktree/.pdo/artifacts/_input/fp-report-21.md`
- `/home/ubuntu/prompt-driven-software-factory/.pdo/runs/20261104-102700-9fbe78d/worktree/.pdo/artifacts/_input/impl-report-21.md`
- `/home/ubuntu/prompt-driven-software-factory/.pdo/runs/20261104-102700-9fbe78d/worktree/.pdo/artifacts/_input/spec-plan-iter2.md`

## Outputs

- `out`: write to `/home/ubuntu/prompt-driven-software-factory/.pdo/runs/20261104-102700-9fbe78d/worktree/.pdo/artifacts/XBG5Cxkn/iter-1/out/output.md`

## Source code edits

Your working directory `/home/ubuntu/prompt-driven-software-factory/.pdo/runs/20261104-102700-9fbe78d/worktree` is the **run's shared worktree**: other nodes of this run may work in it at the same time. Make **all** source code edits there — do not `cd` elsewhere to edit files.

You do not have to run any git command. When this node finishes, PDO keeps whatever you committed yourself and commits everything else you left behind onto the run's branch. Anything the repository's `.gitignore` covers stays out, and so does PDO's own `.pdo/artifacts/`; everything else goes in.

## Completion

When you are done, signal completion by running:
```
pdo complete
```

**`pdo complete` can be REFUSED**, and its exit code tells you what to do next (#490):
- **0** — granted, or a legal duplicate. Nothing more to do.
- **3** — refused, *and it is still your turn*: the refusal names its cause on stderr (missing outputs, a frontmatter mismatch, a completion the user has not released yet, child runs still in flight, …) and tells you what to do. The node is still running and nothing has failed. Do what stderr says, then run `pdo complete` again. **Do NOT run `pdo fail`.**
- **4** — refused, *and the runtime has already ruled*: the failure is already recorded in the run log. **Do NOT run `pdo fail`** — you would record it a second time, with a wrong reason. Stop and report what happened.
- **1** — the daemon could not be reached or gave no verdict. This is the only case where signalling failure yourself is right.

If you cannot complete the task, signal failure:
```
pdo fail --reason "<description of the problem>"
```

If there is legitimately nothing to do — your input/pool is empty through no error (e.g. the eligible items were all claimed before you ran) — record a graceful no-op instead of a failure. This ends the run as `skipped` (not `failed`) and short-circuits downstream:
```
pdo skip --reason "<why there is nothing to do>"
```

If you are blocked on a question only your user can answer, declare it instead of waiting silently:
```
pdo wait-user --message "<your question, under 100 characters>"
```
The run turns awaiting-user with your question on its banner; the wait lifts by itself when the user answers in the PDO terminal. The command returns at once — never block or poll for the answer.

---

/implement the entire scope of what is asked by the user. if an issue is mentionned, go read it. 
Do not defer any work, the scope of your work was already decided upstream.
do not use subagents for the majority of the implementation.
if there is a prototype, it is your visual ground truth. It might add things that were not in the issue.
No failing unit test should be tolerated, even if considered pre exising. Consider it your job to also fix them. 
your job is not to run agentic tests like FP though.