

	mod_multicast - Extended Stanza Addressing (XEP-0033) support

	Homepage: http://ejabberd.jabber.ru/mod_multicast
	Author: Badlop
	Module for ejabberd 1.1.3


	DESCRIPTION
	-----------

This module implements Extended Stanza Addressing (XEP-0033).

The development of this module is included on a Google Summer of Code 2007 project.


	INSTALL
	-------

1. Compile the module.
2. Copy the binary file to ejabberd ebin directory.
3. Edit ejabberd.cfg and add the module to the list of modules:
  {mod_multicast, []},
4. Start ejabberd.


	CONFIGURABLE PARAMETERS
	-----------------------

host 
    Define the hostname of the service.
    Default value: "multicast.SERVER"
access:
    Specify who can send packets to the multicast service.
    Default value: all
allow_relay:
    Allow relay support
    Default value: false
max_receivers:
    Base filename, including absolute path
    Default value: 50


	EXAMPLE CONFIGURATION
	---------------------

% Only admins can send packets to multicast service
{access, multicast, [{allow, admin}, {deny, all}]}.

{modules, [
  ...
  {mod_multicast, [
     {host, "multicast.example.org"},
     {access, multicast},
     {allow_relay, false},
     {max_receivers, 50}
  ]},
  ...
]}.


	TO DO
	-----

Tasks to do:
 - Verify the current access+acl checking works for local users, remote users, remote servers
 - Maybe some errors should abort the execution
 - Document on the guide and ejabberd.cfg.example
 - Consider anti-spam requirements

Feature requests:
 - Allow to define "multicast.SERVER" on ejabberd.cfg, and SERVER will be replaced with the hostname
 - Provide time and last
 - GUI with FORMS to allow users of non-capable clients to write XEP-33 packets easily

Could use mod_multicast somehow:
 - when client sends presence stanza
 - mod_muc
 - mod_pubsub/mod_pep
 - mod_irc


	CHANGELOG
	---------

0.1 - 2007-06-08
  * Initial version
