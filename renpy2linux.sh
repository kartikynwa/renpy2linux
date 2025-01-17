#!/bin/sh
set -e

# Check if wget is available
if ! [ -x "$(command -v wget)" ]; then
  echo '!!Error: wget is not installed' >&2
fi

# Check if tar is available
if ! [ -x "$(command -v tar)" ]; then
  echo '!!Error: tar is not installed' >&2
  exit 1
fi

if test $# -eq 0 ; then
  echo "usage: $0 <game> [renpy_version]"
  exit 1
fi
BASEDIR="$1"
cd "$BASEDIR"
BASEDIR=$(pwd)

trap 'cd "$BASEDIR" && rm -rf __tmp' EXIT

# Read Ren'Py version.
if test $# -gt 1 ; then
    RENPYVER=$2
else
    if [ ! -f renpy/__init__.py ]; then
        echo "!! Could not read renpy/__init__.py -- is this a Ren'Py game?"
        exit 1
    fi
    RENPYVER=$(grep 'version_tuple' renpy/__init__.py | head -1 | cut -d'=' -f2 | cut -d',' -f1,2,3 | sed 's/(//g' | sed 's/,/./g' | sed 's/ //g')
fi
echo "=> Ren'Py version: ${RENPYVER}"

# Extract game title.
PYEXE=$(echo *.py)
TITLE=${PYEXE%.py}

# Flush temporary directory.
rm -rf __tmp
mkdir __tmp
cd __tmp

echo "==> Downloading and extracting RenPy SDK..."
# Get the appropriate Ren'Py version SDK to supplement missing files.
SDKFILE="renpy-${RENPYVER}-sdk.tar.bz2"
SDKURL="http://renpy.org/dl/${RENPYVER}/${SDKFILE}"
if ! wget -q --show-progress "${SDKURL}"; then
    echo "!! Ren'Py SDK Download failed -- aborting."
    exit 3
fi

if ! tar -xf "${SDKFILE}"; then
    echo "!! Extraction failed -- aborting."
    exit 4
fi
rm "${SDKFILE}"

# Finding directory
for x in "renpy-${RENPYVER}-sdk" "renpy-${RENPYVER}" ; do
  if test -d "$x" ; then
    SDKDIR=$x
    break
  fi
done
if test -z "${SDKDIR}" ; then
  echo "!! Couldn't find Ren'Py SDK directory -- aborting."
  exit 5
fi

echo "==> Copying files..."
# Copy the required platform files.
cd "${SDKDIR}"
for x in lib/* ; do
  if ! test -e "../../$x" ; then
    echo "=> $x"
    cp -R "$x" ../../lib
    ln -s renpy "../../$x/${TITLE}"
  fi
done

# Copy over the launch scripts.
for x in exe sh app ; do
  if ! test -e "../../${TITLE}.$x" ; then
    echo "=> ${TITLE}.$x"
    cp -R renpy.$x ../../"${TITLE}".$x
  fi
done
if test -d "../../${TITLE}.app/Contents/MacOS/lib" ; then
  echo "==> Fixing up ${TITLE}.app..."
  rm -rf "../../${TITLE}.app/Contents/MacOS/lib"
  ln -s ../../../lib "../../${TITLE}.app/Contents/MacOS/lib"
  cp "../../${TITLE}.app/Contents/MacOS/renpy" "../../${TITLE}.app/Contents/MacOS/${TITLE}"
  sed -i -e 's!<string>renpy</string>!'"<string>${TITLE}</string>"'!g' "../../${TITLE}.app/Contents/Info.plist"
fi
cd ..

echo "\o/ Done!"
