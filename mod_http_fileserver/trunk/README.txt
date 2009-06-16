
IMPORTANT: This module is included in ejabberd SVN since version ejabberd 2.1.0,
so you don't need to get it from here.

WARNING:
This trunk version requires ejabberd trunk SVN 1561 or newer (ejabberd 2.1.x).
If you are using some ejabberd 2.0.x, please use instead
the code in mod_http_fileserver/branches/ejabberd-2.0.x


If you want to compile this module with Erlang/OTP R11B-3 or older,
edit Emakefile and remove this:
   {d, 'SSL39'},


	CONFIGURATION
	=============

Sample ejabberd.cfg options, assuming that files are to be accessed
under "http://server:5280/pub/archive/" and that the filesystem
directory to export is "/var/www":

  {listen,
   ...
   {5280, ejabberd_http,    [http_poll, web_admin,
                            {request_handlers, [{["pub", "archive"], mod_http_fileserver}]}]}
   ...
   ]}


  {modules,
   [
    ...
    {mod_http_fileserver, [{docroot, "/var/www"}, {accesslog, "/var/log/ejabberd/access.log"}]},
    ...
   ]}

   accesslog is an optional parameter to specify an apache access log
   file like. No log will be recorded if missing.

	USAGE
	=====



	CHANGELOG
	=========
