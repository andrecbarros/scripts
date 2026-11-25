#!/bin/bash
# GPL-3.0
# Author: Andre C. Barros <andre.cbarros@yahoo.com>
#
# keep local copies of registered repositories up-to-date
# and generate packages with tags/releases information,
# when they exist

set -u             # Error on unset variables
set -Eeuo pipefail # Catch failures inside pipelines
set -T             # Inherit DEBUG trap inside functions and subshells
set -x             # print each line as it runs
# trap 'read -p "$LINENO: \$> $BASH_COMMAND"' DEBUG

error_code=
error_handler () {
    echo "Error [$1] $2: \$> $3"
}
#trap 'error_handler $? $LINENO "$BASH_COMMAND"' ERR

# .................................................

pkg_version () {
    # generate a tag/release information for current
    # source tree
    set +e
    ds_tag=$( git describe --tags --exact-match 2>/dev/null )

    if [[ -z "$ds_tag" ]]; then
        for mode in tags always; do
            ds_tag=$( git describe --$mode | \
                    sed -En ' s;^v?([0-9][[:alnum:].]*)$;\1;i; t1;
                              s;^v?([0-9][[:alnum:].]*)-([0-9]+)-(g[[:xdigit:]]+)$;\1+\2-\3;i; t1;
                              s;^g?[[:xdigit:]]+$;;i;
                             :1; p' )
            [[ -n "$ds_tag" ]] \
                && break
        done
        if [[ -z "$ds_tag" ]]; then
            ds_tag=$( git rev-list refs/heads/${pkgs[$(( idx + ds_branch ))]} --count )
            #  --no-merges
            ds_tag="$( date --utc +%Y%m%d )-$ds_tag.g$( git describe --always )"
        fi
    else
        ds_tag=$( echo "$ds_tag" | \
                sed -En ' s;^v?([0-9][[:alnum:].]*)$;\1;i; t1;
                          s;^v?([0-9][[:alnum:].]*)-([0-9]+)-(g[[:xdigit:]]+)$;\1+\2-\3;i;
                         :1; p' )
    fi
    set -e
}

# .MAIN. ..........................................
#
. "$( dirname $0 )"/pkg_data.sh

[[ $( type -t f_pkg_data_struct_init ) == function ]] \
    || ( echo -e "Package data structure init function not found." ;
         exit 1 )

f_pkg_data_struct_init

# clone, sync and generate the final release/tag of
# registered packages
for (( idx=0 ; idx < ${#pkgs[@]} ; idx+=ds_sizeof )); do

    pkg=${pkgs[$(( idx ))]}

    [[ ."${pkg:0:1}" == .- ]] \
        && echo -e "Skipping: $pkg\n" \
        && continue

    echo -e "\nSyncing: $pkg ...\n"

    pdir=$pkg
    [[ -d $pdir ]] || mkdir -p $pdir

    pushd $pdir # pdir

    ptar=$pkg-git.tar.lz4
    psig=$pkg-git.commit

    # before procede to real expansion and download
    # of files, get the commit signature of the
    # remote package repository, what can avoid
    # unneeded operations
    sig=$( git ls-remote ${pkgs[$(( idx + ds_link ))]} \
               origin refs/heads/${pkgs[$(( idx + ds_branch ))]} )
    error_code=$?
    (( ${error_code} )) \
        && echo -e "$pkg [${error_code}]: error on remote polling commit" \
        && popd \
        && continue
    sig=${sig%%[![:xdigit:]]*}

    if [[ -e $ptar ]]; then

        # if possible, avoid more expensive operations
        [[ -e $psig && "$( cat $psig )" == "$sig" ]] \
            && popd \
            && continue

        tar -I lz4 -xf $ptar

        # sync, parse and save the commit of local
        # repository copy

        pushd $pkg-git # pkg-git
        # remove any remote-tracking references that no longer exist
        git fetch --prune
        # reset itto the remote position, and clear out the local
        # changes (non-committed changes & non-pushed commits)
        git reset --hard
        # remove untracked and ignored files
        git clean -f -d -x
        # be extra sure all things are in place
        git pull -p
        git rev-parse refs/heads/${pkgs[$(( idx + ds_branch ))]} \
            > ../$psig
        error_code=$?
        popd # pkg-git

        (( ${error_code} )) \
            && echo -e "$pkg [${error_code}]: error on parsing local commit"
    else
        # since there is no tar archive, it is better to
        # to assume that no successful clonning happened
        [[ -d $pkg-git ]] \
            && rm -rf $pkg-git

        git clone \
            -b ${pkgs[$(( idx + ds_branch ))]} \
            --single-branch --depth 1 \
            ${pkgs[$(( idx + ds_link ))]} \
            $pkg-git

        pushd $pkg-git # pkg-git
        git rev-parse refs/heads/${pkgs[$(( idx + ds_branch ))]} \
            > ../$psig
        error_code=$?
        popd # pkg-git

        (( ${error_code} )) \
            && echo -e "$pkg [${error_code}]: error on parsing 1st local commit"
    fi

    if [[ -d $pkg-git && ${error_code} == 0 ]]; then

        pushd $pkg-git
        pkg_version
        popd # pkg-git

        # generate a tar package with tag/release information
        [[ ! -e "$pkg-$ds_tag.tar.lz4" ]] \
            && tar -I lz4 -cf $pkg-$ds_tag.tar.lz4 $pkg-git --transform "s/^$pkg-git/$pkg-$ds_tag/"

        tar --remove-files -I lz4 -cf $ptar $pkg-git
    fi

    popd # pdir
done
