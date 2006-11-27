To run mod_presence:

1. Compile the module with:
erl -make

2. Copy ebin/*.beam to your ejabberd ebin directory.

3. Copy the directory data/pixmaps somewhere and set the EJABBERD_PIXMAPS_PATH environment variable to point to this directory before launching ejabberd:
export EJABBERD_PIXMAPS_PATH=/path/to/pixmaps