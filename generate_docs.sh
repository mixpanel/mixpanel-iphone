#!/bin/bash

echo "Generating documentation."

rm -rf ./Docs/
headerdoc2html -q -o ./Docs ./Mixpanel/Mixpanel.h ./Mixpanel/MixpanelPeople.h > /dev/null 2>&1
rm -rf ../TempMixpanelDocs
mkdir ../TempMixpanelDocs
cp -a ./Docs/Mixpanel_h/. ../TempMixpanelDocs/.
rm -rf ./Docs/
git checkout gh-pages
git pull
cp -a ../TempMixpanelDocs/. .
rm -rf ../TempMixpanelDocs/
git commit -am "updated docs"
git push origin gh-pages
git checkout master

echo "Updated docs and pushed them to gh-pages!"
