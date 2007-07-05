
	mod_statsdx
	===========

	Calculates and gathers statistics actively


	CONFIGURE
	---------

Add to ejabberd.cfg, 'modules' section the basic configuration:
  {mod_statsdx,     []},

Configurable options:
  hooks: Set to 'false' to remove hooks and related statistics if you don't need them (default: true)


	EXAMPLE CONFIGURATION
	---------------------

{mod_statsdx, [{hooks, false}]},


	FEATURE REQUESTS
	----------------

 - fix the problem with plain/ssl/tlsusers, it crashes ejabberd
 - traffic: send bytes per second, received bps
 - connections to a transport
 - traffic: send presence per second, received mps
 - Number of SASL c2s connections
 - improve to work in distributed server



	ejabberd_web_admin
	==================

	Adds additional statistics provided by mod_statsdx to the Web Interface
	
This patched version of the Wb Interface
is only compatible with ejabberd 1.1.2 and 1.1.3.
So, it does not work with newer versions of ejabberd.


	CONFIGURE
	---------

This patch requires mod_statsdx. 
Several new statistics are available on the web interface.
No specific configuration is required.

Screenshots: http://ejabberd.jabber.ru/mod_statsdx




	mod_stats2file
	==============

	Generates files with all kind of statistics

This module writes a file with all kind of statistics every few minutes. 
Available output formats are html (example), 
text file with descriptions and raw text file (for MRTG, RRDTool...).


	CONFIGURE
	---------

This module requires mod_statsdx. 

Add to ejabberd.cfg, 'modules' section the basic configuration:
  {mod_stats2file,     []},

Configurable options:
  interval: Time between updates, in minutes (default: 5)
  type: Type of output. Allowed values: html, txt, dat (default: html)
  basefilename: Base filename, including absolute path (default: "/tmp/ejasta")
  split: If split the statistics in several files (default: false)
  hosts: List of virtual hosts that will be checked. By default all


	EXAMPLE CONFIGURATION
	---------------------

{mod_stats2file, [{interval, 60}, {type, txt}, {split, true},
  {basefilename, "/var/www/stats"}, {hosts, ["localhost", "server3.com"]}
]},
