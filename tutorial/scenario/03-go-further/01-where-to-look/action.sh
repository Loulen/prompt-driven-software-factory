# Point at the two reference documents, and at the skills now installed in the workspace.
printf '%s\n' \
  "README:           https://github.com/Loulen/prompt-driven-software-factory#readme" \
  "docs/INSTALL.md:  https://github.com/Loulen/prompt-driven-software-factory/blob/main/docs/INSTALL.md" \
  "" \
  "The skills installed in this workspace (.agents/skills/):"
for _s in .agents/skills/*/; do
  _s=${_s%/}
  printf '  /%s\n' "${_s##*/}"
done
