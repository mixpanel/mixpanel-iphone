rm -rf ./Mixpanel_h ./MixpanelPeople.h
headerdoc2html -q -o . ../Mixpanel/MixpanelPeople.h ../Mixpanel/Mixpanel.h
gatherheaderdoc . index.html
open index.html
