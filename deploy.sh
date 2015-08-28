#!/bin/bash

echo "Bumping version number."
VERSION=$(grep -o "VERSION @\"[0-9]*\.[0-9]*\.[0-9]*" Mixpanel/Mixpanel.m | tail -1 | tr -d 'VERSION @"')
VERSION_MAJOR=$(echo $VERSION | awk -F \. '{print $1}')
VERSION_MINOR=$(echo $VERSION | awk -F \. '{print $2}')
VERSION_PATCH=$(echo $VERSION | awk -F \. '{print $3}')

if [ $VERSION_PATCH ==  9 ]; then
    if [ $VERSION_MINOR ==  9 ]; then
        ((VERSION_MAJOR++))
        VERSION_MINOR="0"
        VERSION_PATCH="0"
    else
        ((VERSION_MINOR++))
        VERSION_PATCH="0"
    fi
else
    ((VERSION_PATCH++))
fi
INCREMENTED_VERSION="$VERSION_MAJOR.$VERSION_MINOR.$VERSION_PATCH"
echo "New version: " $INCREMENTED_VERSION

sed -i '' -e "s/${VERSION}/${INCREMENTED_VERSION}/" Mixpanel/Mixpanel.m
sed -i '' -e "s/${VERSION}/${INCREMENTED_VERSION}/" Mixpanel.podspec

echo "Generating documentation."

rm -rf ./Docs/HeaderDoc
headerdoc2html -q -o ./Docs ./Mixpanel/Mixpanel.h > /dev/null 2>&1
mv ./Docs/Mixpanel_h ./Docs/HeaderDoc
cp -r ./Docs/HeaderDoc/* ../analytics/media/doctyl/uploads/iPhone-spec/

echo "Updated docs in ../analytics. Ensure you commit and PR from that repo as well!"

echo "Creating new tag vX.X.X"
git tag "v$INCREMENTED_VERSION"
git push origin "v$INCREMENTED_VERSION"

echo "Verifying podspec"
pod spec lint

echo "Pushing pod to trunk"
pod trunk push

echo "Finished! Please draft a new release on GitHub"
open "https://github.com/mixpanel/mixpanel-iphone/releases/new" 
