// SPDX-License-Identifier: LGPL-2.1-or-later
// Copyright © 2007-2018 ANSSI. All Rights Reserved.

/**
 * useradmin.c
 *
 * @brief useradmin starts a daemon listening to the socket /var/run/useradmin.
 *
 **/


#include <stdio.h>
#include <unistd.h>
#include <stdlib.h>
#include <fcntl.h>
#include <string.h>

#include "user.h"

int main(void)
{
	if (start_user_daemon()) {
		fprintf(stderr, "Error starting USERADMIN_DAEMON\n");
		return 1;
	}
	return 0;
}
