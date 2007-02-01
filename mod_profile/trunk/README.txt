This module supports storing and retrieving a profile according to
XEP-0154.  It does no validation of the data, but simply stores
whatever XML the user sends in a Mnesia table.  The PEP parts of
XEP-0154 are out of scope for this module.

To use this module, follow the general build instructions, and add the
following to your configuration, among the other modules:

{mod_profile, []}

This module is written by Magnus Henoch.
mailto:henoch@dtek.chalmers.se
xmpp:legoscia@jabber.cd.chalmers.se
