#!/bin/bash

echo "Generating documentation."

rm -rf ./Docs
appledoc --project-name mixpanel-iphone --project-company Mixpanel --company-id com.mixpanel --no-repeat-first-par --keep-undocumented-objects --keep-undocumented-members --preprocess-headerdoc --no-create-docset --output Docs Mixpanel/Mixpanel.h Mixpanel/MixpanelPeople.h
rm -rf ../TempMixpanelDocs
cp -a ./Docs/html/. ../TempMixpanelDocs
rm -rf ./Docs
git checkout gh-pages
git pull
cp -a ../TempMixpanelDocs/. .
rm -rf ../TempMixpanelDocs/
git add .
git reset HelloMixpanel/
git commit -m 'updated docs'
git push origin gh-pages
git checkout master

echo "Updated docs and pushed them to gh-pages!"
