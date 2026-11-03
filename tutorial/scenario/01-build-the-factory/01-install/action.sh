# Install PDSF for real into the workspace, with the harness the learner chose.
PDSF_SRC="$PDSF_TUTO_SRC" PDSF_HARNESS="$PDSF_TUTO_HARNESS" PDSF_MONOREPO=n \
  sh "$PDSF_TUTO_SRC/install.sh" "$PDSF_TUTO_WORKSPACE" </dev/null
