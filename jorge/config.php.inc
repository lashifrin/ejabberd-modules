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
$lang_def = "eng"; // eng for English, pol for Polish

// Configuration for database access (ejabberd's postgresql server):
$db_ejabberd[user] = ""; // username
$db_ejabberd[pass] = ""; // password
$db_ejabberd[name] = ""; // db name
$db_ejabberd[host] = ""; // host ip

// MySQL database where mod_logdb is running on:
$mod_logdb[user] = ""; // username
$mod_logdb[pass] = ""; // password
$mod_logdb[name] = ""; // db name
$mod_logdb[host] = ""; // host ip

// admin name (only name - without domain name):
$admin_name = "";

// jabber server host name. Replace dots with underline (f.e: jabber_example_com)
$xmpp_host = "";

// secret key for scrambling URLs. We use AES encryption for urls so put here some random data
$url_key = "";

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
$copy = "jabster.pl &copy; 2007";

// custom logo
$brand_logo = "logo_jabster.png";



?>
