This is an implementation of XEP-0163 (Personal Eventing via Pubsub,
PEP).  It should be considered experimental and unstable for now.

The functionality is implemented as a change to mod_pubsub, but small
changes are made to a number of important modules.

You need to add mod_caps to the modules section of your configuration
file, like this:

{modules,
 [
...
 {mod_caps, []},
...
 ]}.

If you have a cluster, you may want to replicate the Mnesia tables
pubsub_node and pep_node on the nodes.

Author: Magnus Henoch, xmpp:legoscia@jabber.cd.chalmers.se,
mailto:henoch@dtek.chalmers.se
