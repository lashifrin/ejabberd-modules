
	mod_logxml - Log XMPP packets to XML file

	Homepage: http://ejabberd.jabber.ru/mod_logxml
	Author: Badlop
	Version: 0.2.3 - 2007-03-20
	Module for ejabberd 0.7.5 or newer


	DESCRIPTION
	-----------

This module sniffs all the XMPP traffic send and received by ejabberd,
both internally and externally transmitted. It logs the XMPP packets
to a XML formatted file. It's posible to filter transmitted packets 
by orientation, stanza and direction. It's possible to configure the 
file rotation rules and intervals.

This module reuses code from mod_log_forensic, mod_stats2file, mod_muc_log


	INSTALL
	-------

 1 Copy this file to ejabberd/src/mod_logxml.erl
 2 Recompile ejabberd
 3 Add to ejabberd.cfg, 'modules' section the basic configuration:
    {mod_logxml,     []},


	CONFIGURABLE PARAMETERS
	-----------------------

stanza: 
    Log packets only when stanza matches
    Default value: [iq, message, presence, other]
direction: 
    Log packets only when direction matches
    Default value: [internal, vhosts, external]
orientation: 
    Log packets only when orientation matches
    Default value: [send, revc]
logdir: 
    Base filename, including absolute path
    Default value: "/tmp/jabberlogs/"
timezone:
    The time zone for the logs is configurable with this option. 
	Allowed values are 'local' and 'universal'.
	With the first value, the local time, 
	as reported to Erlang by the operating system, will be used. 
	With the latter, GMT/UTC time will be used. 
	Default value: local
rotate_days: 
    Rotate logs every X days
    Put 'no' to disable this limit.
    Default value: 1
rotate_megs: 
    Rotate when the logfile size is higher than this, in megabytes.
    Put 'no' to disable this limit.
    Default value: 10
rotate_kpackets: 
    Rotate every *1000 XMPP packets logged
    Put 'no' to disable this limit.
    Default value: 10
check_rotate_kpackets: 
    Check rotation every *1000 packets
    Default value: 1


	EXAMPLE CONFIGURATION
	---------------------

  {mod_logxml, [
     {stanza, [message, other]},
     {direction, [external]},
     {orientation, [send, recv]},
     {logdir, "/var/jabber/logs/"},
     {timezone, universal}, 
     {rotate_days, 1}, 
     {rotate_megs, 100}, 
     {rotate_kpackets, no},
     {check_rotate_kpackets, 1}
  ]},


	CHANGELOG
	---------

0.2.3 - 2007-03-20
  * The file name respects the timezone option

0.2.2 - 2007-02-13
  * Added new option: timezone

0.2.1 - 2006-08-08
  * Fixed small bug on start/2 

0.2 - 2006-03-08
  * Changed some configuration options: 
      rotate_days, rotate_mages and rotate_kpackets can now be set independently
  * New format of XML logs: now XMPP packets are enclosed in <packet>, with attributes:
      or: orientation of the packet, either 'send' or 'recv'
      ljid: local JID of the sender or receiver, depending on the orientation
      ts: timestamp when the packet was logged

0.1 - 2005-11-11
  * Initial version

