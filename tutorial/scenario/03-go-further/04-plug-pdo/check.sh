. "$PDSF_TUTO_ROOT/lib/check.sh"

check_that "the workspace is a git repo" git rev-parse --git-dir
check_that "nothing PDO-specific was needed (no .pdo/)" test ! -e .pdo
check_done
