// PDSF Tutorial recorder — turns one `claude -p --output-format stream-json --verbose` run (one
// learner turn, on stdin) into the agent turn of a transcript, as the learner would see it in
// their harness: the agent's text, and one `⏺ Tool(target)` line per tool call, in order.
// Subagent traffic (parent_tool_use_id set) is left out: the learner only sees its summary.
//
//   node stream-turn.mjs WORKSPACE META_OUT < run.jsonl > agent-turn.md
//
// META_OUT receives `key=value` lines: session, model, version, error.
import { readFileSync, writeFileSync } from 'node:fs';
import { relative, isAbsolute } from 'node:path';

const [workspace, metaOut] = process.argv.slice(2);
const lines = readFileSync(0, 'utf8').split('\n').filter((line) => line.trim());

const rel = (path) => {
  if (typeof path !== 'string') return '';
  if (!isAbsolute(path)) return path;
  const r = relative(workspace, path);
  return r.startsWith('..') ? path : r || '.';
};
// The recorder's workspace path means nothing to the learner: commands are shown as run from the
// workspace (`cd <ws> && …` dropped), paths relative to it.
const unroot = (text) => String(text ?? '')
  .split(`cd ${workspace} && `).join('')
  .split(`cd ${workspace}; `).join('')
  .split(`${workspace}/`).join('')
  .split(workspace).join('.');
const oneLine = (text, max = 90) => {
  const first = unroot(text).split('\n')[0].trim();
  return first.length > max ? `${first.slice(0, max - 1)}…` : first;
};

const target = (name, input = {}) => {
  switch (name) {
    case 'Bash': return oneLine(input.command);
    case 'Read': case 'Write': case 'Edit': case 'NotebookEdit': return rel(input.file_path ?? input.notebook_path);
    case 'Glob': case 'Grep': return oneLine(input.pattern);
    case 'Skill': return input.skill ?? input.command ?? '';
    case 'Task': case 'Agent': return oneLine(input.description ?? input.subagent_type);
    case 'TodoWrite': return `${(input.todos ?? []).length} items`;
    default: return '';
  }
};

const meta = { session: '', model: '', version: '', error: '' };
const out = [];
let lastWasTool = false;

for (const line of lines) {
  let event;
  try { event = JSON.parse(line); } catch { continue; }
  if (event.type === 'system' && event.subtype === 'init') {
    meta.session = event.session_id ?? meta.session;
    meta.model = event.model ?? meta.model;
    meta.version = event.claude_code_version ?? meta.version;
  }
  if (event.type === 'result') {
    meta.session = event.session_id ?? meta.session;
    if (event.is_error) meta.error = oneLine(event.result ?? event.subtype ?? 'error', 200);
  }
  if (event.type !== 'assistant' || event.parent_tool_use_id) continue;
  for (const block of event.message?.content ?? []) {
    if (block.type === 'text' && block.text.trim()) {
      if (out.length) out.push('');
      out.push(unroot(block.text).trim());
      lastWasTool = false;
    } else if (block.type === 'tool_use') {
      if (out.length && !lastWasTool) out.push('');
      const t = target(block.name, block.input);
      out.push(t ? `⏺ ${block.name}(${t})` : `⏺ ${block.name}`);
      lastWasTool = true;
    }
  }
}

process.stdout.write(out.join('\n') + '\n');
writeFileSync(metaOut, Object.entries(meta).map(([k, v]) => `${k}=${String(v).replace(/\n/g, ' ')}`).join('\n') + '\n');
