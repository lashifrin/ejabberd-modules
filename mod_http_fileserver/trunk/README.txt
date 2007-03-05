mod_http_fileserver - Description


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
    {mod_http_fileserver, [{docroot, "/var/www"}]},
    ...
   ]}

	USAGE
	=====



	CHANGELOG
	=========

