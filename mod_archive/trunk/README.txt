mod_archive - Message Archiving (XEP-0136)

Olivier Goffart <ogoffart at kde.org>

This module does support almost all the XEP-0136 version 0.6 except otr (off-the-record).

Features
 - Automatic archiving
 - User may enable/disable automatic archiving for one contact or globally
 - Manual archiving
 - Retrieve or remove archive
 - XEP-0059

Not Supported
 - Off the record
 - Groupchats message

Options
 - save_default: true or false: whether or not messages should be saved by default
 - session_duration: The time in seconds before a session timeout (for a collection). The default value is 30 minutes.

Support of XEP-136 on Jabber clients
 - JWChat: Implemented, but does not work, since it implements an old version. An update on JWChat is expected in the mid-term.
 - Kopete: Planned for the mid-term.