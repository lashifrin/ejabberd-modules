
	mod_logsession - Log session connections to file

	Homepage: http://www.ejabberd.im/mod_logsession
	Author: Badlop
	Module for ejabberd trunk SVN r1301 or newer


	DESCRIPTION
	-----------

This module is intended to log in a text file the session connections.
Right now it only logs the forbidden connection attempts.
Each vhost is logged in a different file.


	INSTALL
	-------

1 Copy this file to ejabberd/src/mod_logsession.erl
2 Recompile ejabberd
3 Add to ejabberd.cfg, 'modules' section the basic configuration:
    {mod_logsession,     []},
4 With this configuration, the log files are:
    /tmp/ejabberd_logsession_@HOST@.log


	CONFIGURABLE PARAMETERS
	-----------------------

sessionlog: 
  Define the name of log files.
  The keyword @HOST@ will be substituted with the name of each vhost.
  Default value: "/tmp/ejabberd_logsession_@HOST@.log"


	EXAMPLE CONFIGURATION
	---------------------

{modules, [
  ...
  {mod_logsession, [
    {sessionlog, "/var/log/ejabberd/session_@HOST@.log"}
  ]},
  ...
]}.

With that configuration, if the server has three vhosts:
  "localhost", "example.org" and "example.net",
then the forbidden accesses will be logged in the files:
  /var/log/ejabberd/session_localhost.log
  /var/log/ejabberd/session_example.org.log
  /var/log/ejabberd/session_example.net.log


	FORMAT OF LOG
	-------------

The content of the file is the date and time of the attempted login
and the JID of the denied user.

For example:
2008-01-08 12:20:50 Forbidden session for tron@localhost/teeest
2008-01-08 12:36:01 Forbidden session for baduser@localhost/aaa22


	REOPEN LOG FILES
	----------------

This module also provides a new ejabberdctl command for each vhost:
  reopen-seslog

Example usage:
  $ sudo ejabberdctl vhost localhost reopen-seslog
  $ sudo ejabberdctl vhost example.org reopen-seslog
  $ sudo ejabberdctl vhost example.net reopen-seslog

