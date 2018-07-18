// SPDX-License-Identifier: LGPL-2.1-or-later
// Copyright © 2007-2018 ANSSI. All Rights Reserved.


/**
 * user.c
 *
 * @brief user listen to the socket /var/run/useradmin and executes scripts depending on the action requested.
 *
 **/


#include <stdio.h>
#include <unistd.h>
#include <stdlib.h>
#include <string.h>
#include <pwd.h>
#include <grp.h>
#include <signal.h>
#include <sys/param.h>
#include <sys/socket.h>
#include <sys/wait.h>
#include <sys/un.h>
#include <sys/stat.h>
#include <errno.h>
#include <syslog.h>
#include <arpa/inet.h>

#include <clip.h>

#include "user.h"

#ifdef USERADMINFULL
#define CREATE_COMMAND 'C'
#define CREATE_SCRIPT "/sbin/create_user.sh" 
#define DELETE_COMMAND 'D'
#define DELETE_SCRIPT "/sbin/delete_user.sh" 
#define LOCK_COMMAND 'L'
#define LOCK_SCRIPT "/sbin/lock_user.sh" 
#define UNLOCK_COMMAND 'U'
#define UNLOCK_SCRIPT "/sbin/unlock_user.sh" 
#define LIST_COMMAND 'S'
#define LIST_SCRIPT "/sbin/list_users.sh" 
#endif
#define MODIFY_COMMAND 'M'
#define MODIFY_SCRIPT "/sbin/modify_user.sh" 

#define ERROR(fmt, args...) \
	syslog(LOG_DAEMON|LOG_ERR, fmt, ##args)

#define INFO(fmt, args...) \
	syslog(LOG_DAEMON|LOG_INFO, fmt, ##args)

#define PERROR(msg) \
	syslog(LOG_DAEMON|LOG_ERR, msg ": %s", strerror(errno))

static int launch_script(char *script, char *user)
{
	INFO("Lancement de %s %s", script, user);
	char *const argv[] = { script, user, TYPE_MACHINE, NULL };
	char *envp[] = { NULL };
	return -execve(argv[0], argv, envp);
}

int start_user_daemon(void)
{
	if (clip_daemonize()) {
		PERROR("clip_fork");
		return 1;
	}

	openlog("USERADMIN", LOG_PID, LOG_DAEMON);
	
	int s, s_com, status;
	pid_t f, wret;
	socklen_t len;
	struct sockaddr_un sau;
	char command= 0;
	char user[PATH_MAX];
	char userCar=1;
	int indice=0;

	/* We will write to a socket that may be closed on client-side, and
	   we don't want to die. */
	if (signal(SIGPIPE, SIG_IGN) == SIG_ERR) {
		PERROR("signal");
		return 1;
	}

        INFO("Start listening to %s ...",USERADMINSOCKET);
	
	s = clip_listenOnSock(USERADMINSOCKET, &sau, 0);

	if (s < 0) {
		return 1;
	}

	for (;;) {
		len = sizeof(struct sockaddr_un);
		s_com = accept(s, (struct sockaddr *)&sau, &len);
		if (s_com < 0) {
			PERROR("accept");
			close(s);
			return 1;
		}

		INFO("Connection accepted");

		/* Get the command */
		if ( read(s_com, &command, 1) != 1)
		{
			PERROR("read command");
			close(s);
			return 1;
		}

		INFO("Command %c",command);

		indice = 0;
		user[indice]='\0';
		userCar=1;

		/* Get the user */
		while ( (userCar != '\0') && (indice < PATH_MAX) )
		{
			if ( read(s_com, &userCar, 1) != 1)
			{
				PERROR("read username");
				close(s);
				return 1;
			}

			user[indice] = userCar;
			indice ++;
		}
		if (!strcmp(user,""))
		{
			ERROR("Username is empty");
			close(s);
			return 1;
		}

		f = fork();
		if (f < 0) {
			PERROR("fork");
			close(s_com);
			continue;
		} else if (f > 0) {
			/* Father */
			wret = waitpid(f, &status, 0);
			if (!WEXITSTATUS(status)) {
				if (write(s_com, "Y", 1) != 1)
					PERROR("write Y");
			} else {
				if (write(s_com, "N", 1) != 1)
					PERROR("write N");
			}
			close(s_com);
			continue;
		} else {
			/* Child */
			close(s);

			switch (command)
			{
#ifdef USERADMINFULL
				case CREATE_COMMAND:
					exit(launch_script(CREATE_SCRIPT, user));
					break;
				case DELETE_COMMAND:
					exit(launch_script(DELETE_SCRIPT, user));
					break;
				case LOCK_COMMAND:
					exit(launch_script(LOCK_SCRIPT, user));
					break;
				case UNLOCK_COMMAND:
					exit(launch_script(UNLOCK_SCRIPT, user));
					break;
				case LIST_COMMAND:
					exit(launch_script(LIST_SCRIPT, user));
					break;
#endif
				case MODIFY_COMMAND:
					exit(launch_script(MODIFY_SCRIPT, user));
					break;
				default:
					exit(-1);
			}
		}
	}

	INFO("Stop listening...");

	return 0;
}
