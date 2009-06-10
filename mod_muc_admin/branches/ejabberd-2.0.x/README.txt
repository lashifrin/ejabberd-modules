

	mod_muc_admin - Administrative features for MUC

	Homepage: http://www.ejabberd.im/mod_muc_admin
	Author: Badlop
	Requirements: ejabberd 1.1.x, 2.0.0 or 2.0.1 for basic functionality;
	ejabberd 2.0.2 or higher to get all functionality (like WebAdmin pages)


	CONFIGURATION
	=============

Add the module to your ejabberd.cfg, on the modules section:
{modules, [
  ...
  {mod_muc_admin, []},
  ...
]}.


	USAGE
	=====

Now you have several new commands in ejabberdctl.

Description of some commands:

 - muc-unusued-*
   Those commands related to MUC require an ejabberd version newer than 1.1.x.
   The room characteristics used to decide if a room is unusued:
    - Days since the last message or subject change: 
        greater or equal to the command argument 
    - Number of participants: 0
    - Persistent: not important
    - Has history: not important
    - Days since last join, leave, room config or affiliation edit: 
        not important
    - Just created: no
   Note that ejabberd does not keep room history after a module restart, so
   the history of all rooms is emtpy after a module or server start.

