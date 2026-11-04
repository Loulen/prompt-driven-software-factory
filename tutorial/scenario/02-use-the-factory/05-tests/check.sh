. "$PDSF_TUTO_ROOT/lib/check.sh"

# The learner ran the tests for real in the shell: they pass, Belt US-1's included.
check_that "the test suite passes (node --test)" node --test
check_that "Belt US-1 is tested: a submission is refused while objectives remain" sh -c 'grep -l "submit" test/*.js | xargs grep -qi "Run a refactoring workshop\|still to validate"'
check_done
