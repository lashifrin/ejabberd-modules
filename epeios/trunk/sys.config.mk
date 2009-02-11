[
 %% Epeios container configuration:
 {epeios,[{epeios_name, "muc.localhost"},
	  {epeios_server_host, "localhost"},
          {epeios_server_port, 8888},
          {epeios_secret, "secret"},
          {epeios_db_path, "database"},
          %% Depending of your machine, change this path to the
          %% directory of expat_erl.so ...
          {epeios_lib_path, "lib/linux-x86"},

          %% Example configuration for mod_muc
          {epeios_module, "mod_muc"},
          {epeios_host_config,
	   [
            %% ACL does not work in Epeios
            %% Access works in Epeios, but is rather useless without ACL
	    {{access, muc_admin, global}, [{deny, all}]},
	    {{access, muc, global}, [{allow, all}]}
	   ]},
          {epeios_module_config,
	   [
	    {access, muc},
	    {access_create, muc},
	    {access_persistent, muc},
	    {access_admin, muc_admin}
	   ]}

	  %% Example configuration for mod_pubsub
	  %%{epeios_module, "mod_pubsub"},
	  %%{epeios_host_config, []},
	  %%{epeios_module_config,
	  %% [
	  %%  {plugins, ["default"]}
	  %% ]}

	 ]},

 %% Logging configuration:
 {kernel,[{error_logger, {file, "logs/epeios_app.log"}},
	  {start_ddll, true},
          {start_disk_log, false},
          {start_os, true},
          {start_pg2, true},
          {start_timer, true}]},
 {sasl, [{sasl_error_logger, {file, "logs/epeios_sasl.log"}}]}
].


%%% Local Variables:
%%% mode: erlang
%%% End:
%%% vim: set filetype=erlang tabstop=8:
