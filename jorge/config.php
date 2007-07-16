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

// Default language (currently Polish and English translations are available):

$lang_def = "pol"; // eng for English, pol for Polish

// Configuration for database access (ejabberd's postgresql server):

$db_ejabberd[user] = "ejabberd";
$db_ejabberd[pass] = "";
$db_ejabberd[name] = "ejabberd";
$db_ejabberd[host] = "213.134.161.52";


// MySQL database where mod_logdb is running on:

$mod_logdb[user] = "logdb";
$mod_logdb[pass] = "12345";
$mod_logdb[name] = "ejabberd_logdb";
$mod_logdb[host] = "213.134.161.52";

// admin name (only name - without domain name):

$admin_name = "kolargol";

// jabber server host name (f.e: example.com):

$xmpp_host = "jabber_autocom_pl";


// secret key for scrambling URLs. We use AES encryption for urls so put here some random data

$url_key = "jhrgw%^&7&^%ahsdgf87153<>.;+=";

// number of chat lines in browser (default: 300)
$num_lines_bro = "300";

// number of search results (default: 100)
$num_search_results = "100";

// splitting line. Value in seconds. Default 900s = 15 minutes
$split_line="900";



?>
