# SPDX-License-Identifier: LGPL-2.1-or-later
# Copyright © 2007-2018 ANSSI. All Rights Reserved.
sbin_PROGRAMS = usersrv usersrvadmin usersrvaudit
usersrv_SOURCES = user.c useradmin.c user.h
usersrv_LDFLAGS = -static 
if CORERM
usersrv_CPPFLAGS = -O -Wall -Wextra -Wcast-qual -Wstrict-prototypes -Werror -fno-common -DUSERADMINSOCKET=\"/mounts/user_priv/var/run/useradmin\" -DTYPE_MACHINE=\"cliprm\"
else
usersrv_CPPFLAGS = -O -Wall -Wextra -Wcast-qual -Wstrict-prototypes -Werror -fno-common -DUSERADMINSOCKET=\"/mounts/user_priv/var/run/useradmin\" -DTYPE_MACHINE=\"clipgtw\"
endif
usersrvaudit_SOURCES = user.c useradmin.c user.h
usersrvaudit_LDFLAGS = -static 
if CORERM
usersrvaudit_CPPFLAGS = -O -Wall -Wextra -Wcast-qual -Wstrict-prototypes -Werror -fno-common -DUSERADMINSOCKET=\"/mounts/audit_priv/var/run/useradmin\" -DTYPE_MACHINE=\"cliprm\"
else
usersrvaudit_CPPFLAGS = -O -Wall -Wextra -Wcast-qual -Wstrict-prototypes -Werror -fno-common -DUSERADMINSOCKET=\"/mounts/audit_priv/var/run/useradmin\" -DTYPE_MACHINE=\"clipgtw\"
endif
usersrvadmin_SOURCES = user.c useradmin.c user.h
usersrvadmin_LDFLAGS = -static
if CORERM
usersrvadmin_CPPFLAGS = -O -Wall -Wextra -Wcast-qual -Wstrict-prototypes -Werror -fno-common -DUSERADMINSOCKET=\"/mounts/admin_priv/var/run/useradmin\" -DUSERADMINFULL=1 -DTYPE_MACHINE=\"cliprm\"
else
usersrvadmin_CPPFLAGS = -O -Wall -Wextra -Wcast-qual -Wstrict-prototypes -Werror -fno-common -DUSERADMINSOCKET=\"/mounts/admin_priv/var/run/useradmin\" -DUSERADMINFULL=1 -DTYPE_MACHINE=\"clipgtw\"
endif
bin_PROGRAMS = cryptpasswd
cryptpasswd_SOURCES = cryptpasswd.c
cryptpasswd_LDFLAGS = -lcrypt
cryptpasswd_CPPFLAGS = -O -Wall -Wextra -Wcast-qual -Wstrict-prototypes -Werror -fno-common
