#!/bin/bash
# License: MIT
# Author: Andre C. Barros <andre.cbarros@yahoo.com>
#
# Steps to make julia work in termux
# - install glibc-runner
# - download julia package
# - extract juli package contents to opt/julia dir
# - run julia.run

set -u             # Error on unset variables
set -Eeuo pipefail # Catch failures inside pipelines
set -T             # Inherit DEBUG trap inside functions and subshells
#set -x             # print each line as it runs
# trap 'read -p "$LINENO: \$> $BASH_COMMAND"' DEBUG

error_handler () {
    echo "Error [$1] $2: \$> $3"
}
#trap 'error_handler $? $LINENO "$BASH_COMMAND"' ERR

pfx=julia
ver=1.13.4
sfx=linux-aarch64.tar.gz
pkg="$pfx-$ver-$sfx"
tdir=/data/data/com.termux/files
julia_dir=$tdir/opt/julia
julia_files=~/julia-files

pushd ${julia_files} || exit
echo "wget -c \"https://julialang-s3.julialang.org/bin/linux/aarch64/${ver%.*}/$pkg\""
wget -c "https://julialang-s3.julialang.org/bin/linux/aarch64/${ver%.*}/$pkg"
[ $? != 0 ] \
  && echo "Could not download: '$pkg'" \
  && exit
popd

# files=$( tar --list -f "$1" )

echo -en "Select action:\nr - remove julia;\ni - install julia\n-> "
read -r opt

if [ .$opt = .r ]; then
  rm -rf "${julia_dir}"
  exit
elif [ .$opt = .i ]; then
  :
else
  exit
fi

if [ ! -d "${julia_dir}" -o .$opt = .i ]; then
  [ -d "${julia_dir}" ] \
    && rm -rf "${julia_dir}" \
    && mkdir -p "${julia_dir}"
  [ $? != 0 ] \
    && echo "Could not create temporary dir: '${julia_dir}'" \
    && exit

  tar --checkpoint=.1000 --strip-components=1 -C "${julia_dir}" -xf "${julia_files}/$pkg"
  [ $? != 0 ] \
    && echo "Error extraction '$pkg': removing '${julia_dir}'" \
    && rm -rf "${julia_dir}" \
    && exit

  # Move license notice
  mv "${julia_dir}/LICENSE.md" "${julia_dir}/share/doc/julia"
fi

for d in etc include lib libexec share share/doc; do
  ( cd "$tdir/usr/glibc/$d" ; [ ! -e julia ] && ln -s "${julia_dir}/$d/julia" julia )
  [ $d = lib -o $d = libexec ] \
    && ( cd "$tdir/usr/$d" ; [ ! -e julia ] && ln -s "${julia_dir}/$d/julia" julia )
done

for l in $( ls -1 "${julia_dir}/lib" ); do
  ( cd "$tdir/usr/glibc/lib" ; [ ! -e "${l##*/}" ] && ln -s "${julia_dir}/lib/${l##*/}" "${l##*/}" )
done

for d in bin share/appdata share/applications share/man/man1 share/metainfo; do
  ( cd "$tdir/usr/glibc"
    if [ -e "$d" ]; then
      cd "$d"
      for f in $( ls -1 "${julia_dir}/$d" ); do
        [ ! -e "${f##*/}" ] && ln -s "${julia_dir}/$d/${f##*/}" "${f##*/}"
      done
    fi
    cd "$tdir/usr"
    if [ -e "$d" ]; then
      cd "$d"
      for f in $( ls -1 "${julia_dir}/$d" ); do
        [ ! -e "${f##*/}" ] && ln -s "${julia_dir}/$d/${f##*/}" "${f##*/}"
      done
    fi
  )
done

if [[ "$( ls -1 ${julia_files}/*.so.* | wc -l )" -gt 4 ]]; then
  for l in ${julia_files}/*.so.*; do
    cp -a $l "${julia_dir}/lib"
  done
else
  pushd "${julia_dir}/lib"
  for l in ld-linux-aarch64.so.1 libc.so.6 libdl.so.2 libpthread.so.0 ; do
    ln -s "$tdir/usr/glibc/lib/$l" "$l"
  done
  popd
fi

[ ! -e ~/julia.run ] \
  && echo -e "#!/bin/sh\n" \
             "grun /data/data/com.termux/files/usr/bin/julia" \
     > ~/julia.run \
  && chmod 0755 ~/julia.run
