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


// well if we dont know in what language to talk, we cant show anything, so bye bye...
if ($lang!="pol" && $lang!="eng") { 

	header("Location: index.php?act=logout"); 
	exit; 
}

// control check - if global archivization is enabled...
if ($sess->get('enabled') == "f") { 

	header ("Location: not_enabled.php"); 
	
}

$link_sw = $_GET['a'];

// number of my links saved...
$db->get_mylinks_count();
$my_links_count = $db->result->cnt;

// number of items in trash
$db->get_trash_count();
$tr_n = $db->result->cnt;

// get preferences for saving
$pref_id=$_GET['set_pref'];
$pref_value=$_GET['v'];

// save preferences
if ($_GET['set_pref']) {

	//validate
	if (!ctype_digit($pref_id)) { unset($pref_id); }
	if (!ctype_digit($pref_value)) { unset($pref_value); }
	// what to set
	// view and language preferences are stored for now.
	if ($pref_id==="1" OR $pref_id==="2") 
		{ 
			if($pref_value==="1" OR $pref_value==="2") 
				{ 
					save_pref($user_id,$pref_id,$pref_value);
					if ($pref_id==="1") {
						$sess->set('view_type',$pref_value);
						}
					if ($pref_id==="2") {
						if ($pref_value=="1") { $s_lang="pol"; } else { $s_lang="eng"; }
						$sess->set('language',$s_lang);
						}
				} 
		}

}

// get preferences, if not set, fallback to standard view.
$view_type=$sess->get('view_type');
if ($view_type=="1") { 

		$view_type="main.php"; 
	} 
	elseif($view_type=="2") { 
	
		$view_type="calendar_view.php"; 
		
}

// this is menu. not nice but works ;)
if (preg_match("/search_v2.php/i",$location)) 

	{ 
		$menu_main='<a class="mmenu" href="'.$view_type.'">'.$menu_item_browser[$lang].'</a>';
		$menu_map='<a class="mmenu" href="chat_map.php">'.$menu_item_map[$lang].'</a>';
		$menu_search='<b>'.$menu_item_search[$lang].'</b>';
		$menu_mylinks='<a class="mmenu" href="my_links.php">'.$menu_item_links[$lang].' ('.$my_links_count.')</a>';
		$menu_favorites='<a class="mmenu" href="favorites.php">'.$menu_item_fav[$lang].'</a>';
		$menu_contacts='<a class="mmenu" href="contacts.php">'.$menu_item_contacts[$lang].'</a>';
		$menu_logger='<a class="mmenu" href="logger.php">'.$menu_item_logs[$lang].'</a>';
		$menu_trash='<a class="mmenu" href="trash.php">'.$menu_item_trash[$lang].'('.$tr_n.')</a>';
		$search_loc=1;
		if (TOKEN==ADMIN_NAME) { $menu_stats=' | <a class="mmenu" href="stats.php"> Stats</a>'; }
	}
	elseif(preg_match("/main.php/i",$location))
	{
		$menu_main='<b>'.$menu_item_browser[$lang].'</b>';
		$menu_map='<a class="mmenu" href="chat_map.php">'.$menu_item_map[$lang].'</a>';
		$menu_search='<a class="mmenu" href="search_v2.php">'.$menu_item_search[$lang].'</a>';
		$menu_mylinks='<a class="mmenu" href="my_links.php">'.$menu_item_links[$lang].' ('.$my_links_count.')</a>';
		$menu_favorites='<a class="mmenu" href="favorites.php">'.$menu_item_fav[$lang].'</a>';
		$menu_contacts='<a class="mmenu" href="contacts.php">'.$menu_item_contacts[$lang].'</a>';
		$menu_logger='<a class="mmenu" href="logger.php">'.$menu_item_logs[$lang].'</a>';
		$menu_trash='<a class="mmenu" href="trash.php">'.$menu_item_trash[$lang].'('.$tr_n.')</a>';
		if (TOKEN==ADMIN_NAME) { $menu_stats=' | <a class="mmenu" href="stats.php"> Stats</a>'; }

	}
	elseif(preg_match("/my_links.php/i",$location))
	{
		$menu_main='<a class="mmenu" href="'.$view_type.'">'.$menu_item_browser[$lang].'</a>';
		$menu_map='<a class="mmenu" href="chat_map.php">'.$menu_item_map[$lang].'</a>';
		$menu_search='<a class="mmenu" href="search_v2.php">'.$menu_item_search[$lang].'</a>';
		$menu_mylinks='<b>'.$menu_item_links[$lang].' ('.$my_links_count.') </b>';
		$menu_favorites='<a class="mmenu" href="favorites.php">'.$menu_item_fav[$lang].'</a>';
		$menu_contacts='<a class="mmenu" href="contacts.php">'.$menu_item_contacts[$lang].'</a>';
		$menu_logger='<a class="mmenu" href="logger.php">'.$menu_item_logs[$lang].'</a>';
		$menu_trash='<a class="mmenu" href="trash.php">'.$menu_item_trash[$lang].'('.$tr_n.')</a>';
		if (TOKEN==ADMIN_NAME) { $menu_stats=' | <a class="mmenu" href="stats.php"> Stats</a>'; }


	}
	elseif(preg_match("/help.php/i",$location))
	{
		$menu_main='<a class="mmenu" href="'.$view_type.'">'.$menu_item_browser[$lang].'</a>';
		$menu_map='<a class="mmenu" href="chat_map.php">'.$menu_item_map[$lang].'</a>';
		$menu_search='<a class="mmenu" href="search_v2.php">'.$menu_item_search[$lang].'</a>';
		$menu_mylinks='<a class="mmenu" href="my_links.php">'.$menu_item_links[$lang].' ('.$my_links_count.')</a>';
		$menu_favorites='<a class="mmenu" href="favorites.php">'.$menu_item_fav[$lang].'</a>';
		$menu_contacts='<a class="mmenu" href="contacts.php">'.$menu_item_contacts[$lang].'</a>';
		$menu_logger='<a class="mmenu" href="logger.php">'.$menu_item_logs[$lang].'</a>';
		$menu_trash='<a class="mmenu" href="trash.php">'.$menu_item_trash[$lang].'('.$tr_n.')</a>';
		if (TOKEN==ADMIN_NAME) { $menu_stats=' | <a class="mmenu" href="stats.php"> Stats</a>'; }

	}
	elseif(preg_match("/contacts.php/i", $location))
	{
		$menu_main='<a class="mmenu" href="'.$view_type.'">'.$menu_item_browser[$lang].'</a>';
		$menu_map='<a class="mmenu" href="chat_map.php">'.$menu_item_map[$lang].'</a>';
		$menu_search='<a class="mmenu" href="search_v2.php">'.$menu_item_search[$lang].'</a>';
		$menu_mylinks='<a class="mmenu" href="my_links.php">'.$menu_item_links[$lang].' ('.$my_links_count.')</a>';
		$menu_favorites='<a class="mmenu" href="favorites.php">'.$menu_item_fav[$lang].'</a>';
		$menu_contacts='<b>'.$menu_item_contacts[$lang].'</b>';
		$menu_logger='<a class="mmenu" href="logger.php">'.$menu_item_logs[$lang].'</a>';
		$menu_trash='<a class="mmenu" href="trash.php">'.$menu_item_trash[$lang].'('.$tr_n.')</a>';
		if (TOKEN==ADMIN_NAME) { $menu_stats=' | <a class="mmenu" href="stats.php">Stats</a>'; }

	}
	elseif(preg_match("/stats.php/i", $location))
	{
		$menu_main='<a class="mmenu" href="'.$view_type.'">'.$menu_item_browser[$lang].'</a>';
		$menu_map='<a class="mmenu" href="chat_map.php">'.$menu_item_map[$lang].'</a>';
		$menu_search='<a class="mmenu" href="search_v2.php">'.$menu_item_search[$lang].'</a>';
		$menu_mylinks='<a class="mmenu" href="my_links.php">'.$menu_item_links[$lang].' ('.$my_links_count.')</a>';
		$menu_favorites='<a class="mmenu" href="favorites.php">'.$menu_item_fav[$lang].'</a>';
		$menu_contacts='<a class="mmenu" href="contacts.php">'.$menu_item_contacts[$lang].'</a>';
		$menu_logger='<a class="mmenu" href="logger.php">'.$menu_item_logs[$lang].'</a>';
		$menu_trash='<a class="mmenu" href="trash.php">'.$menu_item_trash[$lang].'('.$tr_n.')</a>';
		if (TOKEN==ADMIN_NAME) { $menu_stats=' | <b>Stats</b></a>'; }

		
	}
	elseif(preg_match("/logger.php/i", $location))
	{
		$menu_main='<a class="mmenu" href="'.$view_type.'">'.$menu_item_browser[$lang].'</a>';
		$menu_map='<a class="mmenu" href="chat_map.php">'.$menu_item_map[$lang].'</a>';
		$menu_search='<a class="mmenu" href="search_v2.php">'.$menu_item_search[$lang].'</a>';
		$menu_mylinks='<a class="mmenu" href="my_links.php">'.$menu_item_links[$lang].' ('.$my_links_count.')</a>';
		$menu_favorites='<a class="mmenu" href="favorites.php">'.$menu_item_fav[$lang].'</a>';
		$menu_contacts='<a class="mmenu" href="contacts.php">'.$menu_item_contacts[$lang].'</a>';
		$menu_logger='<b>'.$menu_item_logs[$lang].'</b>';
		$menu_trash='<a class="mmenu" href="trash.php">'.$menu_item_trash[$lang].'('.$tr_n.')</a>';
		if (TOKEN==ADMIN_NAME) { $menu_stats=' | <a class="mmenu" href="stats.php"> Stats</a>'; }

		
	}
	elseif(preg_match("/trash.php/i", $location))
	{
		$menu_main='<a class="mmenu" href="'.$view_type.'">'.$menu_item_browser[$lang].'</a>';
		$menu_map='<a class="mmenu" href="chat_map.php">'.$menu_item_map[$lang].'</a>';
		$menu_search='<a class="mmenu" href="search_v2.php">'.$menu_item_search[$lang].'</a>';
		$menu_mylinks='<a class="mmenu" href="my_links.php">'.$menu_item_links[$lang].' ('.$my_links_count.')</a>';
		$menu_favorites='<a class="mmenu" href="favorites.php">'.$menu_item_fav[$lang].'</a>';
		$menu_contacts='<a class="mmenu" href="contacts.php">'.$menu_item_contacts[$lang].'</a>';
		$menu_logger='<a class="mmenu" href="logger.php">'.$menu_item_logs[$lang].'</a>';
		$menu_trash='<b>'.$menu_item_trash[$lang].'('.$tr_n.')</b>';
		if (TOKEN==ADMIN_NAME) { $menu_stats=' | <a class="mmenu" href="stats.php"> Stats</a>'; }

		
	}
	elseif(preg_match("/calendar_view.php/i", $location))
	{
		$menu_main='<b>'.$menu_item_browser[$lang].'</b>';
		$menu_map='<a class="mmenu" href="chat_map.php">'.$menu_item_map[$lang].'</a>';
		$menu_search='<a class="mmenu" href="search_v2.php">'.$menu_item_search[$lang].'</a>';
		$menu_mylinks='<a class="mmenu" href="my_links.php">'.$menu_item_links[$lang].' ('.$my_links_count.')</a>';
		$menu_favorites='<a class="mmenu" href="favorites.php">'.$menu_item_fav[$lang].'</a>';
		$menu_contacts='<a class="mmenu" href="contacts.php">'.$menu_item_contacts[$lang].'</a>';
		$menu_logger='<a class="mmenu" href="logger.php">'.$menu_item_logs[$lang].'</a>';
		$menu_trash='<a class="mmenu" href="trash.php">'.$menu_item_trash[$lang].'('.$tr_n.')</a>';
		if (TOKEN==ADMIN_NAME) { $menu_stats=' | <a class="mmenu" href="stats.php"> Stats</a>'; }

		
	}
	elseif(preg_match("/chat_map.php/i", $location))
	{
		$menu_main='<a class="mmenu" href="'.$view_type.'">'.$menu_item_browser[$lang].'</a>';
		$menu_map='<b>'.$menu_item_map[$lang].'</b>';
		$menu_search='<a class="mmenu" href="search_v2.php">'.$menu_item_search[$lang].'</a>';
		$menu_mylinks='<a class="mmenu" href="my_links.php">'.$menu_item_links[$lang].' ('.$my_links_count.')</a>';
		$menu_favorites='<a class="mmenu" href="favorites.php">'.$menu_item_fav[$lang].'</a>';
		$menu_contacts='<a class="mmenu" href="contacts.php">'.$menu_item_contacts[$lang].'</a>';
		$menu_logger='<a class="mmenu" href="logger.php">'.$menu_item_logs[$lang].'</a>';
		$menu_trash='<a class="mmenu" href="trash.php">'.$menu_item_trash[$lang].'('.$tr_n.')</a>';
		if (TOKEN==ADMIN_NAME) { $menu_stats=' | <a class="mmenu" href="stats.php"> Stats</a>'; }

		
	}
	elseif(preg_match("/settings.php/i", $location))
	{
		$menu_main='<a class="mmenu" href="'.$view_type.'">'.$menu_item_browser[$lang].'</a>';
		$menu_map='<a class="mmenu" href="chat_map.php">'.$menu_item_map[$lang].'</a>';
		$menu_search='<a class="mmenu" href="search_v2.php">'.$menu_item_search[$lang].'</a>';
		$menu_mylinks='<a class="mmenu" href="my_links.php">'.$menu_item_links[$lang].' ('.$my_links_count.')</a>';
		$menu_favorites='<a class="mmenu" href="favorites.php">'.$menu_item_fav[$lang].'</a>';
		$menu_contacts='<a class="mmenu" href="contacts.php">'.$menu_item_contacts[$lang].'</a>';
		$menu_logger='<a class="mmenu" href="logger.php">'.$menu_item_logs[$lang].'</a>';
		$menu_trash='<a class="mmenu" href="trash.php">'.$menu_item_trash[$lang].'('.$tr_n.')</a>';
		if (TOKEN==ADMIN_NAME) { $menu_stats=' | <a class="mmenu" href="stats.php"> Stats</a>'; }
	}
	elseif(preg_match("/favorites.php/i", $location))
	{
		$menu_main='<a class="mmenu" href="'.$view_type.'">'.$menu_item_browser[$lang].'</a>';
		$menu_map='<a class="mmenu" href="chat_map.php">'.$menu_item_map[$lang].'</a>';
		$menu_search='<a class="mmenu" href="search_v2.php">'.$menu_item_search[$lang].'</a>';
		$menu_mylinks='<a class="mmenu" href="my_links.php">'.$menu_item_links[$lang].' ('.$my_links_count.')</a>';
		$menu_favorites='<b>'.$menu_item_fav[$lang].'</b>';
		$menu_contacts='<a class="mmenu" href="contacts.php">'.$menu_item_contacts[$lang].'</a>';
		$menu_logger='<a class="mmenu" href="logger.php">'.$menu_item_logs[$lang].'</a>';
		$menu_trash='<a class="mmenu" href="trash.php">'.$menu_item_trash[$lang].'('.$tr_n.')</a>';
		if (TOKEN==ADMIN_NAME) { $menu_stats=' | <a class="mmenu" href="stats.php"> Stats</a>'; }
	}

// check if archivization is currently enabled...
if ($sess->get('log_status') == "0") { 

		$html->system_message('<center><div class="message">'.$status_msg1[$lang].'</div></center>');
	
}

if ($start) { 

	$cur_loc="&start=$start"; 

}

$html->menu('
	<a name="top"></a>
	<table border="0" cellspacing="0" class="ff" width="100%">
	<tr>
		<td colspan="2" height="29" style="text-align: right;">
		<b>'.TOKEN.'@'.$xmpp_host_dotted.'</b>&nbsp; | &nbsp;
		<a href="settings.php">'.$menu_item_panel[$lang].'</a>&nbsp; | &nbsp;
		<a href="#" onClick="smackzk();">'.$sel_client[$lang].'</a>&nbsp; | &nbsp;
		<a href="help.php" target="_blank">'.$help_but[$lang].'</a>&nbsp; | &nbsp;<a href="index.php?act=logout">'.$log_out_b[$lang].'</a><hr size="1" noshade="" color="#c9d7f1"/></td>
	</tr>
	<tr><td height="57"><a href="'.$view_type.'"><img src="img/'.$brand_logo.'" alt="logo" border="0" /></a></td></tr>
	<tr><td valign="top" height="35"><form action="search_v2.php" method="post">
	<input id="t_search" type="text" name="query" class="cc" value="'.$search_phase.'">
	');

if ($search_loc==1) {

	if (isset($_GET[c])) {
		
		$enc->decrypt_url($_GET['c']);
		$time2_start = $enc->time_start;
		$time2_end = $enc->time_end;
	
	}

	else{

		$time2_start=$_POST[time2_start];
		$time2_end=$_POST[time2_end];
		if (validate_date($time2_start=="f")) { unset($time2_start); }
		if (validate_date($time2_start=="f")) { unset($time2_end); }
	
	}
		
	if ($time2_start AND $time2_end) { 
	
			if (strtotime("$time2_start") > strtotime("$time2_end")) { 
			
					$alert = $time_range_w[$lang]; unset ($search_phase); 
					
			} 
	}

	$db->get_uniq_chat_dates();
	$result = $db->result;
	foreach ($result as $row) {

		$r++;
		$to_tble[$r] = $row[at];

	}

	$html->menu('<select class="cc" name="time2_start" style="text-align: center;"><option value="">'.$time_range_from[$lang].'</option>');

	for ($t=1;$t<=$r;$t++) {

		$html->menu('<option value="'.$to_tble[$t].'"');

		if ($time2_start==$to_tble[$t]) {

			$html->menu('selected="selected"');
			
		}

		$html->menu('>'.$to_tble[$t].'</option>');
	
	}

	$pass_t=$t;
	
	$html->menu('</select>&nbsp;<select class="cc" name="time2_end" style="text-align: center;"><option value="">'.$time_range_to[$lang].'</option>');

	for ($t=$r;$t>=1;$t--) {

		$html->menu('<option value="'.$to_tble[$t].'"');

		if ($time2_end==$to_tble[$t]) {

			$html->menu('selected="selected"');
		
		}
		
		$html->menu('>'.$to_tble[$t].'</option>');
	
	}

	$html->menu('</select>');

	if ($time2_start AND !$time2_end) { 
		
		$time2_end = $to_tble[$pass_t-1]; 
	
	}
	
	if (!$time2_start AND $time2_end) { 
	
		$time2_start = $to_tble[($t+1)-$t]; 
		
	}

}

$html->menu('<input class="red" type="submit" value="'.$search_box[$lang].'">
		</form></td>
		</tr>
		<tr style="background-image: url(img/bell-bak.png); height: 24;">
		<td colspan="11" width="100%" style="text-align: left; padding-left: 30px; color: white;">
			'.$menu_main.' | '
			.$menu_map.' | '
			.$menu_favorites.' | '
			.$menu_mylinks.' | '
			.$menu_search.' | '
			.$menu_contacts.' | '
			.$menu_logger.$menu_stats.' | ' 
			.$menu_trash. 
			' | <a class="mmenu" href="" onClick="window.location.reload()">'.$refresh[$lang].'</td>
		</tr>
		</table>
		<p align="center"><b>'.$alert.'</b></p>
	');

// Get user roster.
$rpc_roster = $ejabberd_rpc->get_roster();

// creater roster object and rewrite it to portable multidimentional array
$ejabberd_roster = new roster();

foreach ($rpc_roster as $roster_record) {

	if ($roster_record[group]=="") { 

		$roster_record[group] = $con_no_g[$lang]; 
	
	}

	// avoid contacts without nick
	if ($roster_record[nick]!="") {

		$ejabberd_roster->add_item($roster_record[jid],$roster_record[nick],$roster_record[group]);
	
	}
}

### TESTING ###
$html->commit_render();


?>
