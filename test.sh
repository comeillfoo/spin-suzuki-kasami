#!/usr/bin/env bash

RED='\033[0;31m'
GRN='\033[0;32m'
RST='\033[0m' # No Color

# @brief build directory
BUILDDIR='build'

# @brief source directory
SRCDIR='src'

# @brief path to verifier
PAN='./pan'

# @brief formulas to verify
EXPRS=('cs_prop' 'only_owner_in_cs' 'finite_token_queue'
    'finite_nr_requests' 'liveness')

# @brief exit code
RC=0

# @brief creates build directory
# @return 0 on success
builddir()
{
    mkdir -p "${BUILDDIR}"
}

# @brief cleans all build files
# @return 0 on success
clean()
{
    rm -rf "${BUILDDIR}"
    rm -f pan ./*.pml.trail pan.*
}

# @brief generates verifier source code
# @param[in] 0: number of nodes in protocol
# @param[in] 1: number of node with token on start
# @return 0 on success
generate_verifier()
{
    local n=$1
    local owner=$2
    builddir
    (cd "${BUILDDIR}" && spin -D"N=${n}" -D"DEFAULT_OWNER=${owner}" \
        -a "../${SRCDIR}/proto.pml")
}

# @brief builds verifier
# @param[in] 0: number of nodes in protocol
# @param[in] 1: number of node with token on start
# @return 0 on success
build_pan()
{
    local n=$1
    local owner=$2
    generate_verifier "${n}" "${owner}"
    gcc -DNXT -o pan "${BUILDDIR}/pan.c"
}

usage()
{
    cat <<EOF
Usage: ${0##*/} [options] N

Options:
    -h, --help    Prints this help message
    -v, --verbose Increases verbosity level
EOF
    exit 22 # EINVAL: Invalid argument
}

# @brief should be verbose
verbose=false
while true; do
    case $1 in
        -h|--help)
            usage
            ;;
        -v|--verbose)
            verbose=true
            shift
            ;;
        *)
            break
            ;;
    esac
done

[ $# -lt 1 ] && usage

# @brief N
N="${1:-2}"
set -euo pipefail

echo 'TAP version 14'
echo "1..${N}"
i=1
for default_owner in $(seq 0 $((N - 1))); do
    test_rc=0
    clean |& awk '$0="# "$0' -
    build_pan "${N}" "${default_owner}" |& awk '$0="# "$0' -
    if [ ! -f "${PAN}" ]; then
        echo "# ${PAN} not built"
        echo 'Bail out!'
        exit 1
    fi
    for expr in "${EXPRS[@]}"; do
        output=$("${PAN}" -a -N "${expr}")
        nr_errors=$(echo "${output}" | grep -Eo 'errors: [0-9]+' \
            | cut -d' ' -f2)
        "${verbose}" && echo "${output}" |& awk '$0="# "$0' -
        if [ "${nr_errors}" -gt 0 ]; then
            test_rc=1
            RC=1
            echo -e "# ${RED}[ FAILED]${RST} LTL '${expr}' is false"
        else
            echo -e "# ${GRN}[SUCCEED]${RST} LTL '${expr}' is true"
        fi
    done
    if [ "${test_rc}" -ne 0 ]; then
        echo -n 'not '
    fi
    echo "ok ${i} - verification[${N}, ${default_owner}]"
    i=$((i + 1))
done
exit "${RC}"
