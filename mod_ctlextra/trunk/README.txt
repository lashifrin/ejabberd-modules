mod_ctlextra - Additional commands for ejabberdctl


	CONFIGURATION
	=============

Add the module to your ejabberd.cfg, on the modules section:
{modules, [
  ...
  {mod_ctlextra, []},
  ...
]}.


	USAGE
	=====

Now you have several new options for ejabberd-ctl

Example for vcard: ejabberdctl eja@host vcard-get joe myjab.net email

The file used by 'pushroster' and 'pushroster-all' must be placed:
 * Windows: on the directory were you installed ejabberd: 'C:/Program Files/ejabberd'
 * Other OS: on the same directory where the .beam files are.
Example content for the roster file:
   [{"bob", "example.org", "workers", "Bob"},
    {"mart", "example.org", "workers", "Mart"},
    {"Rich", "example.org", "bosses", "Rich"}].


	CHANGELOG
	=========

0.2.5 - 26/Jan/2007
  * New command for server and vhosts: muc-online-rooms (thanks to tsventon)

0.2.4 - 22/Sep/2006
  * Added new commands: status-num and status-list
