rm -rf ./Mixpanel_h
rm Mixpanel.h
cat ../Mixpanel/MixpanelPeople.h ../Mixpanel/Mixpanel.h >> Mixpanel.h
headerdoc2html -q -o . Mixpanel.h
rm Mixpanel.h
open Mixpanel_h/index.html
