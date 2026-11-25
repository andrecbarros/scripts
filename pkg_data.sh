#!/bin/bash
# GPL-3.0
# Author: Andre C. Barros <andre.cbarros@yahoo.com>
#
# Index and data structure of registered packages

f_pkg_data_struct_init () {
    declare -g    ds_tag=
    declare -g -i ds_name=0
    declare -g -i ds_link=1
    declare -g -i ds_branch=2
    declare -g -i ds_license=3
    declare -g -i ds_about=4
    declare -g -i ds_sizeof=5
    declare -g -a pkgs=(
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

        -grid-desktop
            https://github.com/pelach/grid-desktop.git
            main
            "GPL-3.0"
            "A high-performance desktop widget ecosystem and icon manager for GNOME Shell"

        -ls_colors
            https://github.com/trapd00r/LS_COLORS.git
            master
            "Artistic License"
            "A collection of LS_COLORS definitions"

        -menubuilder.lua
            https://github.com/ColumPaget/menubuilder.lua.git
            master
            "GPL-3.0"
            "A lua script that builds root menus for several window managers"
    )
}
