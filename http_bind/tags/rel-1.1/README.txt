
INTRODUCTION
============

This module implements XMPP over Bosh (formerly known as HTTP Binding)
as outlined by XEP-0206[1].
It extends ejabberd's built in HTTP service with a configurable
resource at which this service will be hosted.

[1]http://www.xmpp.org/extensions/xep-0206.html

INSTALLATION
============

1. Compile the module with:

buils.sh on Un*x 
build.bat on Windows

2. Copy ebin/*.beam to your ejabberd ebin directory.

3. Edit ejabberd.cfg by adding lines like these:

{listen, 
 [...
  {5280, ejabberd_http, [http_poll, web_admin, {request_handlers, [{["http-bind"], mod_http_bind}]}]},
  ...]}.

{modules,
 [...
  {mod_http_bind, []},
 ...]}.
 




