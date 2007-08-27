
	mod_webpresence - Allow user to show presence in the web

	Author: Igor Goryachev
	Requires: ejabberd SVN (not possible with 1.1.x)
	http://ejabberd.jabber.ru/mod_webpresence


	DESCRIPTION
	-----------

This module allows any local user of the ejabberd server to publish his
presence information in the web.

This service is similar to other web-presence/status like
 * ICQ: http://www.icq.com/features/web/indicator.html
 * Edgar: http://edgar.netflint.net/

Allowed output methods are
 * Icons (various themes available): http://www.goryachev.org/jabber-status/image/
 * Raw XML: http://www.goryachev.org/jabber-status/xml/
 * Avatar, stored in the user's vCard

No web server, database, additional libraries or programs are required.


	INSTALL
	-------

1. Compile the module
 * On Windows: build.bat
 * On other systems: ./build.sh

2. Copy ebin/mod_webpresence.beam to your ejabberd ebin directory.

3. Copy the directory data/pixmaps to a directory you prefer.

4. To configure ejabberd, edit ejabberd.cfg and put something like this.
Take special care with commas and dots: if this module does not seem to work
correctly, the problem may be that the configuration file has syntax errors.
Remember to put the correct path to the pixmaps directory,
and make sure the user than runs ejabberd has read access to that directory.

{listen, [
  ...
  {5280, ejabberd_http, [
    ...
    {request_handlers, [
      ...
      {["presence"], mod_webpresence}
    ]}
  ]}
]}.

{modules, [
  ...
  {mod_webpresence, [
    {access, local}, 
    {pixmaps_path, "/path/to/pixmaps"}
  ]}
]}.


5. Restart ejabberd.
If problems appear, remember to always look first the ejabberd log files
ejabberd.log and sasl.log since they may provide some valuable information.


	USAGE
	-----

The web-presence feature by default is switched off for every user. If
user wants to use it, he should register on service webpresence.example.org,
which is accessible from Service Discovery. 
There are several switches for web-presence:
 * JID: allow URI using JID.
 * Hash: allow URI using Hash.
 * XML: allow XML output.
 * Icon: allow icon output.
 * Avatar: allow Avatar output.

Login to an account on your ejabberd server using a powerful Jabber client.
Open the Service Discovery on your Jabber client, and you should see
a new service called "webpresence.example.org".
Try to register on it. A formulary appears allowing the user to 
allow image publishing, and XML publishing.

Once you enabled some of those options, 
on a web browser open the corresponding URI:
 * for XML output:
	http://example.org:5280/presence/jid/<user>/<server>/xml/ 
 * for image output:
	http://example.org:5280/presence/jid/<user>/<server>/image/
 * for image output with theme:
	http://example.org:5280/presence/jid/<user>/<server>/image/<theme>/
 * for avatar output:
	http://example.org:5280/presence/jid/<user>/<server>/avatar/ 

If you want to show the image output of a specific resource, use those URIs:
 * for image output:
	http://example.org:5280/presence/jid/<user>/<server>/image/res/<resource>
 * for image output with theme:
	http://example.org:5280/presence/jid/<user>/<server>/image/<theme>/res/<resource>

If you don't want to reveal your Jabber ID, you can enable Hash URI.
After the registration the user gets a message with his a pseudo-random Hash.
The URI can be formed this way:
  http://example.org:5280/presence/hash/<hash>/image/
If the user forgets his Hash, he can get another message by just registering again,
there is no need to change the values.
If the user wants to get a new Hash, he must disable Hash in the registration form,
and later enable Hash again. A new hash will be generated for him.


	EXAMPLE PHP CODE
	----------------

Tobias Markmann wrote this PHP script that generates HTML code.
This example assumes that the URI of the presence is
  http://example.org:5280/presence/tom/example.org

<?php
	$doc = new DOMDocument();
	$doc->load('http://example.org:5280/presence/tom/example.org/xml');
	$presences = $doc->getElementsByTagName("presence");
	foreach ($presences as $presence) {
		echo "<p style='bottom-margin: 1px;'>";
		echo "<img src='http://example.org:5280/presence/tom/example.org/image' />";
		echo "<a href='xmpp:".$presence->getAttribute('user').'@'.$presence->getAttribute('server')."/";
		$resources = $presence->getElementsByTagName("resource");
		foreach ($resources as $resource) {
			echo $resource->getAttribute('name')."'>";
			echo "Tobias Markmann</a> ( ";
			echo $resource->nodeValue;
		}
		echo " )</p>";
	}
?> 
