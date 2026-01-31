# Cron job to rotate LemonLDAP::NG OIDC keys
#5 5 * * 6 __APACHEUSER__ [ -x __BINDIR__/rotateOidcKeys ] && if [ ! -d /run/systemd/system ]; then __BINDIR__/rotateOidcKeys; fi
