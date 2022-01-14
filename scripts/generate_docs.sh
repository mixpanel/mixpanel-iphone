#!/bin/bash

echo "Generating documentation."
rm -rf docs
appledoc --project-name mixpanel-iphone --project-company Mixpanel --company-id com.mixpanel --no-repeat-first-par --keep-undocumented-objects --keep-undocumented-members --preprocess-headerdoc --no-create-docset --output docs Sources/Mixpanel.h Sources/MixpanelPeople.h Sources/MixpanelGroup.h
cp -a docs/html/. docs/.
rm -rf docs/html

echo "Updated docs!"
