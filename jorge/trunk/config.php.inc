<?
/*
Jorge - frontend for mod_logdb - ejabberd server-side message archive module.

Copyright (C) 2007 Zbigniew Zolkiewski

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

*/

// Print debuging information (true|false). Do NOT set as true on producion servers!
define("DEBUG", false);
define("SQL_DEBUG",false); // sql debug

// Default language (currently Polish and English translations are available):
$lang_def = "eng"; // eng for English, pol for Polish

// RPC Server settings (mod_xmlrpc)
// RPC port:
$rpc_port="4666";

// RPC servers. Jorge can be configured to take advantage of redundancy XML-RPC servers. Add servers below. There is no limit in number of RPC servers.
$rpc_arr[0] = "192.168.0.1"; // example
$rpc_arr[1] = "192.168.0.2"; // example

// MySQL database where mod_logdb is running on:
define("MYSQL_USER", ""); // username
define("MYSQL_PASS", ""); // password
define("MYSQL_NAME",""); // db name
define("MYSQL_HOST", ""); // host ip

// Optional Google Apps support
define("GAPPS", false);
define("GAPPS_ACCOUNT","");
define("GAPPS_PASSWORD","");
define("GAPPS_DOMAIN","");

// admin name (only name - without domain name):
define("ADMIN_NAME","");

// jabber server host name. Replace dots with underline (f.e: jabber_example_com)
$xmpp_host = "";

// do not touch this
$xmpp_host_dotted=str_replace("_",".",$xmpp_host);

// secret key for scrambling URLs. Put here some random data (32 chars):
define("ENC_KEY","PleaseChangeMe");

// number of chat lines in browser (default: 300)
$num_lines_bro = "300";

// number of search results (default: 100)
$num_search_results = "100";

// splitting line. Value in seconds. Default 900s = 15 minutes
$split_line="900";

// links
$links='<a class="foot" href="http://www.jabster.pl" target="_blank">jabster.pl</a>&nbsp;&nbsp;&nbsp;&nbsp;
	<a class="foot" href="http://poczta.jabster.pl" target="_blank">poczta</a>&nbsp;&nbsp;&nbsp;&nbsp;
	<a class="foot" href="http://kalendarz.jabster.pl" target="_blank">kalendarz</a>&nbsp;&nbsp;&nbsp;&nbsp;
	<a class="foot" href="http://docs.jabster.pl" target="_blank">dokumenty</a>
	'; 

// copyright
$copy = "jabster.pl &copy; 2008";

// custom logo
$brand_logo = "logo_jabster.png";

// ignore this ID in queries - this is ID of user without name. see your users table for ID of this user and define it here (it is must)
$ignore_id="";

?>
