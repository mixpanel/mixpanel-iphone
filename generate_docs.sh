#!/bin/bash

echo "Generating documentation."

rm -rf docs
appledoc --project-name mixpanel-iphone --project-company Mixpanel --company-id com.mixpanel --no-repeat-first-par --keep-undocumented-objects --keep-undocumented-members --preprocess-headerdoc --no-create-docset --output docs Mixpanel/Mixpanel.h Mixpanel/MixpanelPeople.h
cp -a docs/html/. docs/.
rm -rf docs/html
git add docs
git commit -m 'updated docs'
git push

echo "Updated docs!"
