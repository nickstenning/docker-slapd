#!/bin/sh

set -eu

status () {
  echo "---> ${@}" >&2
}

set +x
: LDAP_ROOTPASS=${LDAP_ROOTPASS}
: LDAP_DOMAIN=${LDAP_DOMAIN}
: LDAP_ORGANISATION=${LDAP_ORGANISATION}

if [ ! -e /var/lib/ldap/docker_bootstrapped ]; then
  status "configuring slapd for first run"

  cat <<EOF | debconf-set-selections
slapd slapd/password1 password ${LDAP_ROOTPASS}
slapd slapd/password2 password ${LDAP_ROOTPASS}
slapd slapd/dump_database_destdir string /var/backups/slapd-VERSION
slapd slapd/domain string ${LDAP_DOMAIN}
slapd shared/organization string ${LDAP_ORGANISATION}
slapd slapd/backend string MDB
slapd slapd/purge_database boolean true
slapd slapd/move_old_database boolean true
slapd slapd/allow_ldap_v2 boolean false
slapd slapd/no_configuration boolean false
slapd slapd/dump_database select when needed
EOF

  DEBIAN_FRONTEND=noninteractive dpkg-reconfigure slapd

  touch /var/lib/ldap/docker_bootstrapped
else
  status "found already-configured slapd"
fi

# Adjust the soft nofile limit downwards to restrict slapd's memory usage.
ULIMIT_NOFILE_SYS=$(ulimit -Sn)
ULIMIT_NOFILE_SET=${SLAPD_NOFILE_SOFT:-16384}
ULIMIT_NOFILE=$(( $ULIMIT_NOFILE_SYS < $ULIMIT_NOFILE_SET ? $ULIMIT_NOFILE_SYS : $ULIMIT_NOFILE_SET ))

status "starting slapd"
set -x
ulimit -Sn "$ULIMIT_NOFILE"
exec /usr/sbin/slapd -h "ldap:///" -u openldap -g openldap -d 0
