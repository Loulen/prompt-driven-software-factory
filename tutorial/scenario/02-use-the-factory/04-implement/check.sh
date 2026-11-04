. "$PDSF_TUTO_ROOT/lib/check.sh"

check_that "the domain can submit a belt" grep -qi 'submit' src/blackbelt.js
check_that "the submission rule is tested" sh -c 'grep -qil "submit" test/*.js'
check_that "the test suite passes (node --test)" node --test
check_done
