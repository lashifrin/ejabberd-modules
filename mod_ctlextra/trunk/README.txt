

	mod_ctlextra - Additional commands for ejabberdctl

	Homepage: http://www.ejabberd.im/mod_ctlextra
	Author: Badlop
	Module for ejabberd 1.1.2 or newer


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

Now you have several new commands in ejabberdctl.

Description of some commands:

 - vcard-*
   Example: ejabberdctl eja@host vcard-get joe myjab.net email

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

