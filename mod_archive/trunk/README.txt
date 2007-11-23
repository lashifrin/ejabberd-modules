
	mod_archive - Message Archiving (XEP-0136)

There are three different modules, the main difference between them is the storage method:
	- mod_archive uses Mnesia
	- mod_archive_sql uses PostgreSQL
	- mod_archive_odbc uses MySQL or SQLite3



	MOD_ARCHIVE
	===========

Author: Olivier Goffart <ogoffart at kde.org>

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



	MOD_ARCHIVE_SQL
	===============

Author: Alexey Shchepin
Based in mod_archive, author: Olivier Goffart <ogoffart at kde.org>



	MOD_ARCHIVE_ODBC
	================

Author: Alexander Tsvyashchenko
Based in mod_archive, author: Olivier Goffart <ogoffart at kde.org>
Based in mod_archive_sql, author: Alexey Shchepin

For a detailed documentation about this module, please refer to
http://www.ndl.kiev.ua/typo/articles/2007/11/14/mod_archive_odbc-release
