#!/bin/sh
set -e

MODULE='lib/VMware/API/LabManager.pm'
VERSION=`cvs status $MODULE | grep Working | awk '{ print $3 }'`
DATE=`date '+%Y/%m/%d'`
TARDIR="VMware-API-LabManager-$VERSION";

echo
echo "Module  : $MODULE"
echo "Version : $VERSION"
echo "Date    : $DATE"
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

echo "Building the tar file."
cd build && tar czvf $TARDIR.tar.gz $TARDIR
echo

echo DONE!
