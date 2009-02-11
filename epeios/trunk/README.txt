

This version of Epeios includes:
* mod_muc from ejabberd 2.0.3
* mod_pubsub from ejabberd 1.1.3

This version of Epeios is based in ejabberd 2.0.3 and Erlang/OTP R12B-5.
To run Epeios you must use that version of Erlang.
If you compile ejabberd modules to run in Epeios, to ensure compatibility
it is preferable to use that same version of ejabberd and Erlang.


    How to run

. Extract the archive content. Keep the root directory name
(epeios-1.0.0), as it is used by the build tool.

. Set your environment variable:
export EPEIOS_ROOT=/opt/epeios-1.0.0/

. Compile
(cd $EPEIOS_ROOT; build.sh)

. Configure
vim $EPEIOS_ROOT/priv/sys.config

. Configure and start your Jabber server

. Launch
(cd $EPEIOS_ROOT; priv/epeios.start)
