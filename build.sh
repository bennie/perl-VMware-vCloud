#!/bin/sh
set -e

VERSION=`./version.pl`
BUILD=`./version.pl --build`
DATE=`date '+%Y/%m/%d'` 
YEAR=`date '+%Y'`
TARDIR="VMware-vCloud-$VERSION";

echo
echo "Version : $VERSION"
echo "Build   : $BUILD"
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

echo "Updating build tags."
find build -type f | xargs perl -p -i -e "s|BUILDTAG|$BUILD|g"
echo

echo "Updating date tags."
find build -type f | xargs perl -p -i -e "s|YEARTAG|$YEAR|g"
echo

echo "Building the tar file."
cd build && tar czvf $TARDIR.tar.gz $TARDIR
echo

git push

echo DONE!
