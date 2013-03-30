#!/bin/sh
set -e

MODULE='lib/VMware/vCloud.pm'
VERSION=`cvs status $MODULE | grep Working | awk '{ print $3 }' | tr '.' ' ' | awk '{ printf "v%d.%02d", $1, $2 }'`
DATE=`date '+%Y-%m-%d'`
YEAR=`date '+%Y'`
TARDIR="VMware-vCloud-$VERSION";

echo
echo "Module  : $MODULE"
echo "Version : $VERSION"
echo "Date    : $DATE"
echo "Year    : $YEAR"
echo "Tar Dir : $TARDIR"
echo

if [ -d build ];
  then echo "Cleaning Build directory:"; rm -rfv build; echo; 
fi

echo "Creating the build directory:"
mkdir -pv "build/$TARDIR"
echo

echo "Copying files"
rsync -av --files-from=MANIFEST ./ "build/$TARDIR/"
echo

echo "Updating date tags."
find build -type f | xargs perl -p -i -e "s|DATETAG|$DATE|g"
echo

echo "Updating version tags."
find build -type f | xargs perl -p -i -e "s|VERSIONTAG|$VERSION|g"
echo

echo "Updating date tags."
find build -type f | xargs perl -p -i -e "s|YEARTAG|$YEAR|g"
echo

echo "Building the tar file."
cd build && tar czvf $TARDIR.tar.gz $TARDIR
echo

echo DONE!
