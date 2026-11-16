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

error_handler () {
    echo "Error [$1] $2: \$> $3"
}
#trap 'error_handler $? $LINENO "$BASH_COMMAND"' ERR

pkg_version () {
    # generate a tar package with tag/release information
    set +e
    ptag=$( git describe --tags --exact-match 2>/dev/null )

    if [[ -z "$ptag" ]]; then
        for mode in tags always; do
            ptag=$( git describe --$mode | \
                    sed -En ' s;^v?([0-9][[:alnum:].]*)$;\1;i; t1;
                              s;^v?([0-9][[:alnum:].]*)-([0-9]+)-(g[[:xdigit:]]+)$;\1+\2-\3;i; t1;
                              s;^g?[[:xdigit:]]+$;;i;
                             :1; p' )
            [[ -n "$ptag" ]] \
                && break
        done
        if [[ -z "$ptag" ]]; then
            ptag=$( git rev-list refs/heads/${pkgs[$(( idx + pbranch ))]} --count )
            #  --no-merges
            ptag="$( date --utc +%Y%m%d )-$ptag.g$( git describe --always )"
        fi
    else
        ptag=$( echo "$ptag" | \
                sed -En ' s;^v?([0-9][[:alnum:].]*)$;\1;i; t1;
                          s;^v?([0-9][[:alnum:].]*)-([0-9]+)-(g[[:xdigit:]]+)$;\1+\2-\3;i;
                         :1; p' )
    fi
    set -e
}

error_code=
ptag=
declare -i psize=5
declare -i pbranch=2
declare -i plink=1
declare -a pkgs=(
    smenu
        https://github.com/p-gen/smenu.git
        master
        "MPL-2.0"
        "Powerful and versatile CLI selection tool for interactive or scripting use."
    gum
        https://github.com/charmbracelet/gum.git
        main
        "MIT"
        "A tool for glamorous shell scripts"
    ncurses-st-menu
        https://github.com/vikasnkumar/ncurses-st-menu.git
        master
        "BSD-2-clause"
        "ncurses (pdcurses) based library for CUA look menu"

    awf-extended
        https://github.com/luigifab/awf-extended.git
        levelup
        "GPL-3.0"
        "A Widget Factory. Create and display classic themes to:
         * GTK 2, 3, 4;
         * Qt 5, 6;
         * Adwaita;
         * Handy,
         using the same window layout throughout."

    Xdialog
        https://github.com/wdlkmpx/Xdialog.git
        master
        "GPL-2.0"
        "simple gtk dialog app compatible with (ncurses) dialog."

    gtkhash
        https://github.com/gtkhash/gtkhash.git
        master
        "GPL-2.0"
        "A desktop utility for computing file checksums"

    themix-gui
        https://github.com/themix-project/themix-gui.git
        master
        "GPL-3.0"
        "Graphical application for generating different color themes variations"
)

# clone, sync and generate the final release/tag of
# registered packages
for (( idx=0 ; idx < ${#pkgs[@]} ; idx+=psize )); do

    pkg=${pkgs[$(( idx ))]}

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
    sig=$( git ls-remote ${pkgs[$(( idx + plink ))]} \
               origin refs/heads/${pkgs[$(( idx + pbranch ))]} )
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
        git rev-parse refs/heads/${pkgs[$(( idx + pbranch ))]} \
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
            -b ${pkgs[$(( idx + pbranch ))]} \
            --single-branch --depth 1 \
            ${pkgs[$(( idx + plink ))]} \
            $pkg-git

        pushd $pkg-git # pkg-git
        git rev-parse refs/heads/${pkgs[$(( idx + pbranch ))]} \
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

        [[ ! -e "$pkg-$ptag.tar.lz4" ]] \
            && tar -I lz4 -cf $pkg-$ptag.tar.lz4 $pkg-git --transform "s/^$pkg-git/$pkg-$ptag/"

        tar --remove-files -I lz4 -cf $ptar $pkg-git
    fi

    popd # pdir
done
