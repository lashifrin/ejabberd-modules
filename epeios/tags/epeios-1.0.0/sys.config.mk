[
%% Please, use an absolute lib path matching your actual configuration
%% Epeios container configuration:
{epeios, [{epeios_name, "pubsub.localhost"},
          {epeios_server_host, "localhost"},
          {epeios_server_port, 8888},
          {epeios_secret, "secret"},
          {epeios_module, "mod_pubsub"},
          {epeios_host_config, []},
          {epeios_db_path, "database"},
          {epeios_lib_path, "/Users/mremond/epeios-1.0.0/lib/darwin-x86"}]},

%% Logging configuration:
{kernel, [{error_logger, {file, "logs/epeios_app.log"}},
          {start_ddll, true},
          {start_disk_log, false},
          {start_os, true},
          {start_pg2, true},
          {start_timer, true}]},
{sasl, [{sasl_error_logger, {file, "logs/epeios_sasl_log"}}]}
].
