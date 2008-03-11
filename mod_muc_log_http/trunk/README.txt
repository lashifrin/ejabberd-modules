

	mod_muc_log_http - Serve MUC logs on the web

	Homepage: http://ejabberd.jabber.ru/mod_muc_log_http
	Author: Badlop
	Requirement: ejabberd 2.0.0 or newer


	DESCRIPTION
	===========

This module serves the directory containing MUC logs already
configured on mod_muc_log.  So, there's no need to setup a web server
to allow your users to view the MUC logs.  It is a small modification
of mod_http_fileserver, customized for log serving.


	CONFIGURATION
	=============

Sample ejabberd.cfg options. The directory to serve is already defined
on mod_muc_log.

{listen,
 ...
 {5280, ejabberd_http, [http_poll, web_admin,
                        {request_handlers, [
                          {["pub", "muclogs"], mod_muc_log_http}
                         ]
                        }
                       ]
 }
 ...
]}.

{modules,
 [
  ...
  {mod_muc_log_http, []},
  ...
]}.


	USAGE
	=====

With the example options, open your web browser at:
http://server:5280/pub/muclogs/
