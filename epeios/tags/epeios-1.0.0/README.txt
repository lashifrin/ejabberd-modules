. epeios has been tested with Erlang R11B-2. We recommend to use
this version as precompiled module are provided for Erlang R11B-2.

. extract the archive content. Please keep the root directory name
(epeios-1.0.0), as it is used by the build tool.

. Set your environment variable:
export EPEIOS_ROOT=/opt/epeios-1.0.0/

. Compile
(cd $EPEIOS_ROOT; build.sh)

. Configure
vim $EPEIOS_ROOT/priv/sys.config

. Launch
(cd $EPEIOS_ROOT; priv/epeios.start)
