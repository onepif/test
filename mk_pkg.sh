#!/bin/bash

NAME_PKG=test
VER_PKG=0.0.1

mkdir -p ${NAME_PKG}/debian

cat <<EOF>${NAME_PKG}/debian/control
Source:                 ${NAME_PKG}
Section:                utils
Priority:               optional
Maintainer:             Dmitriy <mail@mail.org>
Build-Depends:          
Standards-Version:      ${VER_PKG}
Homepage:               https://test.org

Package:                ${NAME_PKG}
Architecture:           amd64
Provides:               ${NAME_PKG}
Description: ${NAME_PKG^^} packages.
 Deb Пакет с тестовым заданием.
EOF

cat <<EOF>${NAME_PKG}/debian/changelog
${NAME_PKG} (${VER_PKG}) stable; urgency=medium
  * Initial release
  -- Dmitriy <mail@mail.org> $(date)
EOF

cat <<EOF>${NAME_PKG}/debian/rules
#!/usr/bin/make -f
#export DH_VERBOSE = 1

override_dh_clean:

override_dh_make:

override_dh_install:
	mkdir -p debian/${NAME_PKG}/usr/bin || :
	cp /PKG_SOURCE/${NAME_PKG}.sh debian/${NAME_PKG}/usr/bin/

override_dh_fixperms:
	dh_fixperms
	chmod +x debian/${NAME_PKG}/usr/bin/${NAME_PKG}.sh
	chown root:root -R debian/${NAME_PKG}/usr/bin/${NAME_PKG}.sh

%:
	dh \$@
EOF

cat <<EOF>${NAME_PKG}/debian/compat
12
EOF

cat <<EOF>${NAME_PKG}/debian/postinst
#!/bin/sh
# postinst script for ${NAME_PKG}
#

set -e

chmod +x /usr/bin/${NAME_PKG}.sh

/usr/bin/${NAME_PKG}.sh
EOF

cat <<EOF>${NAME_PKG}/debian/postrm
#!/bin/sh -e
# postrm script for ${NAME_PKG}
#

set -e

rm -f /usr/bin/${NAME_PKG}.sh
EOF

cat <<EOF>${NAME_PKG}/debian/prerm
#!/bin/sh -e
# prerm script for ${NAME_PKG}
#

exit 0
EOF

cat <<EOF>${NAME_PKG}/debian/copyright
Format: http://www.debian.org/doc/packaging-manuals/copyright-format/1.0/
Upstream-Name: ${NAME_PKG}
Source: ftp://ftp.example.com/pub/games

Files: *
Copyright: Copyright 1998 John Doe <jdoe@example.com>
License: GPL-2+
 This program is free software; you can redistribute it
 and/or modify it under the terms of the GNU General Public
 License as published by the Free Software Foundation; either
 version 2 of the License, or (at your option) any later
 version.
 .
 This program is distributed in the hope that it will be
 useful, but WITHOUT ANY WARRANTY; without even the implied
 warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
 PURPOSE.  See the GNU General Public License for more
 details.
 .
 You should have received a copy of the GNU General Public
 License along with this package; if not, write to the Free
 Software Foundation, Inc., 51 Franklin St, Fifth Floor,
 Boston, MA  02110-1301 USA
 .
 On Debian systems, the full text of the GNU General Public
 License version 2 can be found in the file
 '/usr/share/common-licenses/GPL-2'.

Files: debian/*
Copyright: Copyright 1998 Jane Smith <jsmith@example.net>
License: GPL-2+
 [LICENSE TEXT]
EOF
