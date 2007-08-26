
	mod_webpresence - Allow user to show presence in the web

	Author: Igor Goryachev
	Requires: ejabberd SVN (not possible with 1.1.x)
	http://ejabberd.jabber.ru/mod_webpresence


	DESCRIPTION
	-----------

This module provides web-presence/status of the user on the web, like
 * ICQ (http://www.icq.com/features/web/indicator.html) 
 * Edgar (http://edgar.netflint.net/).

Allowed output methods are
 * icons (various themes available): http://www.goryachev.org/jabber-status/image/
 * raw XML: http://www.goryachev.org/jabber-status/xml/

No web server or additinal libraries or programs are required.


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
user wants to use it, he should register on service presence.yourhost,
which is accessible from disco. 
There are two switches for web-presence: xml and icon exports. 

Login to an account on your ejabberd server using a powerful Jabber client.
Open the Service Discovery on your Jabber client, and you should see
a new service called "presence.yourhost".
Try to register on it. A formulary appears allowing the user to 
allow image publishing, and XML publishing.

Once you enabled some of those options, 
on a web browser open the corresponding URI:
 * for XML output:
	http://yourhost:5280/presence/<user>/<server>/xml/ 
 * for image output:
	http://yourhost:5280/presence/<user>/<server>/image/
 * for image output with theme:
	http://yourhost:5280/presence/<user>/<server>/image/<theme>/


	EXAMPLE PHP CODE
	----------------

Tobias Markmann wrote this PHP script that generates HTML code.
This example assumes that the URL of the presence is
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
