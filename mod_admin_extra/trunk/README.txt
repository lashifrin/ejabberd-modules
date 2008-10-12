

	mod_admin_extra - Additional ejabberd commands

	Author: Badlop
	Homepage: http://www.ejabberd.im/mod_admin_extra
	Requirements: ejabberd trunk SVN 1635 or newer


	CONFIGURATION
	=============

Add the module to your ejabberd.cfg, on the modules section:
{modules, [
  ...
  {mod_admin_extra, []},
  ...
]}.


	USAGE
	=====

Now you have several new commands in ejabberdctl.

Description of some commands:

 - vcard-*
   Example: ejabberdctl vcard-get joe myjab.net email

 - pushroster*
   The file used by 'pushroster' and 'pushroster-all' must be placed:
     - Windows: on the directory were you installed ejabberd: 
       'C:/Program Files/ejabberd'
     - Other OS: on the same directory where the .beam files are.
   Example content for the roster file:
   [{"bob", "example.org", "workers", "Bob"},
    {"mart", "example.org", "workers", "Mart"},
    {"Rich", "example.org", "bosses", "Rich"}].

 - srg-create
   If you want to put a group Name with blankspaces, use the characters 
   "' and '" to define when the Name starts and ends.
   For example:
   ejabberdctl srg-create g1 example.org "'Group number 1'" this_is_g1 g1

 - ban-account

   This command kicks all the connected sessions of the account from the
   server.  It also changes his password to another randomly
   generated, so he can't login anymore unless a server administrator
   changes him again the password.

   It is possible to define the reason of the ban.  The new password
   also includes the reason and the date and time of the ban.

   For example, if this command is called:
     ejabberdctl vhost example.org ban-account boby Spammed several MUC rooms
   then the sessions of the local account which JID is boby@example.org
   will be kicked, and its password will be set to something like this:
     BANNED_ACCOUNT--20080425T21:45:07--2176635--Spammed_several_MUC_rooms

