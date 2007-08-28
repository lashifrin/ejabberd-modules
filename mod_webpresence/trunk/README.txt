
	mod_webpresence - Presence on the Web

	Author: Badlop
	Requires: ejabberd SVN (not possible with 1.1.x)
	http://ejabberd.jabber.ru/mod_webpresence


	DESCRIPTION
	-----------

This module allows any local user of the ejabberd server to publish his
presence information in the web.
This module is the succesor of Igor Goryachev's mod_presence.

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

4. Edit ejabberd.cfg and add the HTTP and module definitions:
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
    {pixmaps_path, "/path/to/pixmaps"}
  ]}
]}.

5. Restart ejabberd.
If problems appear, remember to always look first the ejabberd log files
ejabberd.log and sasl.log since they may provide some valuable information.


	CONFIGURABLE PARAMETERS
	-----------------------

host 
    Define the hostname of the service.
    You can use the keyword @HOST@.
    Default value: "webpresence.@HOST@"
access:
    Specify who can register in the webpresence service.
    Don't specify all because it will not work.
    Default value: local
pixmaps_path:
    Take special care with commas and dots: if this module does not seem to work
    correctly, the problem may be that the configuration file has syntax errors.
    Remember to put the correct path to the pixmaps directory,
    and make sure the user than runs ejabberd has read access to that directory.
    Default value: "./pixmaps"
port:
    This port value is used to send a message to the user.
    If you set a different port in the 'listen' section, set this option.
    Default value: 5280
path:
    This path value is used to send a message to the user.
    If you set a different path in the 'listen' section, set this option.
    Default value: "presence"


	EXAMPLE CONFIGURATION
	---------------------

	Example 1
	---------

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
    {pixmaps_path, "/path/to/pixmaps"}
  ]}
]}.


	Example 2
	---------

{listen, [
  ...
  {80, ejabberd_http, [
    ...
    {request_handlers, [
      ...
      {["status"], mod_webpresence}
    ]}
  ]}
]}.

{modules, [
  ...
  {mod_webpresence, [
    {host, "webstatus.@HOST@"},
    {access, local},
    {pixmaps_path, "/path/to/pixmaps"},
    {port, 80},
    {path, "status"}
  ]}
]}.


	USAGE
	-----

The web-presence feature by default is switched off for every user. If
user wants to use it, he should register on service webpresence.example.org,
which is accessible from Service Discovery. 
There are several switches for web-presence:
 * Jabber ID: publish the presence in URIs that use the user's Jabber ID.
 * Random ID: publish the presence in URIs that use a Random ID.
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

If you want to show the image or text outputs of a specific resource, add /res/<resource>
to the URI:
  http://example.org:5280/presence/jid/<user>/<server>/text/res/<resource>
  http://example.org:5280/presence/jid/<user>/<server>/image/res/<resource>
  http://example.org:5280/presence/jid/<user>/<server>/image/<theme>/res/<resource>

If you don't want to reveal your Jabber ID, you can enable Random ID URI.
After the registration the user gets a message with his a pseudo-random ID.
The URI can be formed this way:
  http://example.org:5280/presence/rid/<rid>/image/
If the user forgets his Random ID, he can get another message by just registering again,
there is no need to change the values.
If the user wants to get a new Random ID, he must disable Random ID in the registration form,
and later enable Random ID again. A new Random ID will be generated for him.


	EXAMPLE PHP CODE
	----------------

Tobias Markmann wrote this PHP script that generates HTML code.
This example assumes that the URI of the presence is
  http://example.org:5280/presence/jid/tom/example.org

<?php
	$doc = new DOMDocument();
	$doc->load('http://example.org:5280/presence/jid/tom/example.org/xml');
	$presences = $doc->getElementsByTagName("presence");
	foreach ($presences as $presence) {
		echo "<p style='bottom-margin: 1px;'>";
		echo "<img src='http://example.org:5280/presence/jid/tom/example.org/image' />";
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
