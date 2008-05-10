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

if (__FILE__==$_SERVER['SCRIPT_FILENAME']) {

	header("Location: index.php?act=logout");
	exit;

}

// turn on buffering
ob_start();

// error reporting to off
error_reporting(E_NONE);

include("func.php");
include("sessions.php"); // sessions handling
include("config.php"); // read configuration

// get client addr
$rem_adre = $_SERVER['REMOTE_ADDR'];

// get location
$location=$_SERVER['PHP_SELF'];

// make dotted domaniname
$xmpp_host_dotted=str_replace("_",".",$xmpp_host);

// init session
$sess = new session;

// db connection:
$bazaj=db_e_connect($db_ejabberd);
db_connect($mod_logdb);

// user name - we hold it in session, lets fetch it...
$token=$sess->get('uid_l');

// authentication checks. Ensure if session data is not altered... (only when we are inside Jorge)
if (!preg_match("/index.php/i",$location)) {

	if (check_registered_user($bazaj,$sess) != "t") { header("Location: index.php?act=logout"); exit; }

	// we need user_id but only if we are not in not_enabled mode:
	if(!preg_match("/not_enabled.php/i",$_SERVER['PHP_SELF'])) {
		$user_id=get_user_id($token,$xmpp_host);
		if (!ctype_digit($user_id)) { print 'Ooops...error(0.1)'; exit; }
	}

	// domain check. prevent floating auth between jorge instalations on multiple domains
	if ($sess->get('host')!=$xmpp_host OR !$sess->get('host')) { header("Location: index.php?act=logout"); exit; }
}

$time_start=getmicrotime(); // debuging info _start_
// charset - by default we work under utf-8. If you need other type of charset see pl_znaczki() in func.php and adjust encoding to your needs
header("content-type: text/html; charset=utf-8");

// language file
include("lang.php");

$sw_lang_t=$_GET[sw_lang];
if ($sw_lang_t=="t") 
	{ 
	if ($sess->get('language') == "pol") { $sess->set('language', 'eng'); } elseif($sess->get('language') == "eng") { $sess->set('language','pol'); } }

$lang=$sess->get('language');


?>
<!DOCTYPE html PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN">
<html>
<head>
	<meta http-equiv="cache-control" content="no-cache" />
	<meta http-equiv="pragma" content="no-cache" />
	<meta name="Author" content="Zbyszek Zolkiewski at jabster.pl" />
	<meta name="Keywords" content="jorge message archiving ejabberd mod_logdb erlang" />
	<meta name="Description" content="Jorge" />
	<link rel="shortcut icon" href="favicon.ico" /> 
	<link rel="stylesheet" href="style.css" type="text/css" />
	<link rel="stylesheet" href="jquery.autocomplete.css" type="text/css" />
<?
// do not load libs if not nessesary
if (preg_match("/main.php/i",$location)) {
?>
	<link rel="stylesheet" href="simpletree.css" type="text/css" />
	<script type="text/javascript" src="lib/simpletreemenu.js">
		/***********************************************
		* Simple Tree Menu - Dynamic Drive DHTML code library (www.dynamicdrive.com)
		* This notice MUST stay intact for legal use
		* Visit Dynamic Drive at http://www.dynamicdrive.com/ for full source code
		***********************************************/	
	</script>
<?
}
?>
        <script type="text/javascript" src="lib/jquery-1.2.1.pack.js"></script>
	<script type="text/javascript" src="lib/jquery.bgiframe.min.js"></script>
	<script type="text/javascript" src="lib/jquery.form.pack.js"></script>
	<script type='text/javascript' src="lib/dimensions.js"></script>
	<script type="text/javascript" src="lib/jquery.tooltip.js"></script>
	<script type="text/javascript" src="lib/jquery.quicksearch.js"></script>
	<script type="text/javascript" src="lib/jquery.autocomplete.pack.js"></script>
<?
// prevent loading includes as long as user is not admin.
if ($token==$admin_name) {
?>
	<script language="javascript" type="text/javascript" src="lib/jquery.flot-0.1.pack.js"></script>
<?
}
?>
	<title><? print $xmpp_host_dotted; ?> :: Jorge Beta</title>
        <script type="text/javascript">
            $(function() {
		$('table#maincontent tbody#searchfield tr').quicksearch({
			stripeRowClass: ['odd', 'even'],
			position: 'before',
			attached: '#maincontent',
			labelText: 'QuickFilter:',
			delay: 30
		});

		$('img').Tooltip();

		$('a, tr, td').Tooltip({
			extraClass: "fancy",
			showBody: ";",
			showURL: false,
			track: true,
			fixPNG: true
		});


            });
	</script>
</head>
<body style="background-image: url(img/bak2b.png); background-repeat:repeat-x; background-color: #edf5fa;">

<noscript>
	<? 
	print '<center><div style="background-color: #fad163; text-align: center; font-weight: bold; width: 500pt;">'.$no_script[$lang].'</div></center><br>';
	?>
</noscript>

<script language="JavaScript1.2">

function smackzk()  {

	window.open('https://gps.autocom.pl/ZKJab/','',
		'location=no,toolbar=no,menubar=no,scrollbars=no,resizable, height=375,width=715');

		}
</script>


<?
