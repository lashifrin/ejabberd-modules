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

// well if we dont know in what language to talk, we cant show anything, so bye bye...
if ($lang!="pol" && $lang!="eng") { header("Location: index.php?act=logout"); exit; }

// control check - if global archivization is enabled...
if ($sess->get('enabled') == "f") { header ("Location: not_enabled.php"); }

// lets check where we are...
$location=$_SERVER['PHP_SELF'];

$link_sw=mysql_escape_string($_GET['a']);

// number of my links saved...
$my_links_count=get_my_links_count(get_user_id($token,$xmpp_host));


// this is menu. not nice but works ;)
if (preg_match("/search_v2.php/i",$location)) 

	{ 
		$loc1='<a href="main.php">'.$menu_item1[$lang].'</a>';
		$loc2='<b>'.$menu_item2[$lang].'</b>';
		$loc3='<a href="my_links.php">'.$menu_item3[$lang].' ('.$my_links_count.')</a>';
		$loc4='<a href="settings.php">'.$menu_item4[$lang].'</a>';
		$loc5='<a href="contacts.php">'.$menu_item5[$lang].'</a>';
		$search_loc=1;
		if ($token==$admin_name) { $loc6=' | <a href="stats.php"> Stats</a>'; }
	}
	elseif(preg_match("/main.php/i",$location))
	{
		$loc1='<b>'.$menu_item1[$lang].'</b>';
		$loc2='<a href="search_v2.php">'.$menu_item2[$lang].'</a>';
		$loc3='<a href="my_links.php">'.$menu_item3[$lang].' ('.$my_links_count.')</a>';
		$loc4='<a href="settings.php">'.$menu_item4[$lang].'</a>';
		$loc5='<a href="contacts.php">'.$menu_item5[$lang].'</a>';
		if ($token==$admin_name) { $loc6=' | <a href="stats.php"> Stats</a>'; }

	}
	elseif(preg_match("/my_links.php/i",$location))
	{
		$loc1='<a href="main.php">'.$menu_item1[$lang].'</a>';
		$loc2='<a href="search_v2.php">'.$menu_item2[$lang].'</a>';
		$loc3='<b>'.$menu_item3[$lang].' ('.$my_links_count.') </b>';
		$loc4='<a href="settings.php">'.$menu_item4[$lang].'</a>';
		$loc5='<a href="contacts.php">'.$menu_item5[$lang].'</a>';
		if ($token==$admin_name) { $loc6=' | <a href="stats.php"> Stats</a>'; }


	}
	elseif(preg_match("/settings.php/i",$location))
	{
		$loc1='<a href="main.php">'.$menu_item1[$lang].'</a>';
		$loc2='<a href="search_v2.php">'.$menu_item2[$lang].'</a>';
		$loc3='<a href="my_links.php">'.$menu_item3[$lang].' ('.$my_links_count.')</a>';
		$loc4='<b>'.$menu_item4[$lang].'</b>';
		$loc5='<a href="contacts.php">'.$menu_item5[$lang].'</a>';
		if ($token==$admin_name) { $loc6=' | <a href="stats.php"> Stats</a>'; }


	}
	elseif(preg_match("/help.php/i",$location))
	{
		$loc1='<a href="main.php">'.$menu_item1[$lang].'</a>';
		$loc2='<a href="search_v2.php">'.$menu_item2[$lang].'</a>';
		$loc3='<a href="my_links.php">'.$menu_item3[$lang].' ('.$my_links_count.')</a>';
		$loc4='<a href="settings.php">'.$menu_item4[$lang].'</a>';
		$loc5='<a href="contacts.php">'.$menu_item5[$lang].'</a>';
		if ($token==$admin_name) { $loc6=' | <a href="stats.php"> Stats</a>'; }

	}
	elseif(preg_match("/contacts.php/i", $location))
	{
		$loc1='<a href="main.php">'.$menu_item1[$lang].'</a>';
		$loc2='<a href="search_v2.php">'.$menu_item2[$lang].'</a>';
		$loc3='<a href="my_links.php">'.$menu_item3[$lang].' ('.$my_links_count.')</a>';
		$loc4='<a href="settings.php">'.$menu_item4[$lang].'</a>';
		$loc5='<b>'.$menu_item5[$lang].'</b>';
		if ($token==$admin_name) { $loc6=' | <a href="stats.php">Stats</a>'; }

	}
	elseif(preg_match("/stats.php/i", $location))
	{
		$loc1='<a href="main.php">'.$menu_item1[$lang].'</a>';
		$loc2='<a href="search_v2.php">'.$menu_item2[$lang].'</a>';
		$loc3='<a href="my_links.php">'.$menu_item3[$lang].' ('.$my_links_count.')</a>';
		$loc4='<a href="settings.php">'.$menu_item4[$lang].'</a>';
		$loc5='<a href="contacts.php">'.$menu_item5[$lang].'</a>';
		if ($token==$admin_name) { $loc6=' | <b>Stats</b></a>'; }

		
	}

// check if archivization is currently enabled...
if ($sess->get('log_status') == "0") { print '<p style="background-color: yellow; text-align: center;">'.$status_msg1[$lang].'</p>'; }
if ($start) { $cur_loc="&start=$start"; }

// check number of offline messages - this feature is pushed into later betas...
$spool = spool_count($bazaj,$token);

print '<table border="0" cellspacing="0" class="ff" width="100%">'."\n";
print '<tr>'."\n";
print '<td style="text-align: left;">'.$loc1.' | '.$loc2.' | '.$loc3.' | '.$loc5.' | '.$loc4.$loc6.'</td>'."\n";
print '<td style="text-align: right;">'."\n";
print '<b>'.$token.'@'.$xmpp_host_dotted.'</b>&nbsp; | &nbsp;';
print $ch_lan[$lang];
print ' <a href="'.$location.'?a='.$link_sw.'&sw_lang=t'.$cur_loc.'">'.$lang_sw[$lang].'</a>&nbsp; | &nbsp;';
print '<a href="help.php" target="_blank">'.$help_but[$lang].'</a>&nbsp; | &nbsp;<a href="index.php?act=logout">'.$log_out_b[$lang].'</a></td>';
print '</tr>'."\n";
print '<tr><td></td></tr>'."\n";
print '<tr><td width="450" colspan="9">'."\n";
print '<form action="search_v2.php" method="post">'."\n";
print '<input type="text" name="query" class="cc" value="'.$search_phase.'">'."\n";

if ($search_loc==1) {
	
	$time2_start=$_POST[time2_start];
	$time2_end=$_POST[time2_end];
	if ($time2_start OR $time2_end) {
		if (validate_date($time2_start=="f")) { unset($time2_start); }
		if (validate_date($time2_start=="f")) { unset($time2_end); }
		if (strtotime("$time2_start") > strtotime("$time2_end")) { $alert = $time_range_w[$lang]; unset ($search_phase); }
		}

	$result=db_q($user_id,$server,$tslice_table,$talker,$search_p,1,$offset_arch,$xmpp_host);
	while ($results=mysql_fetch_array($result)) {

		$r++;
		$to_tble[$r] = $results[at];

	}

	print '<select class="cc" name="time2_start" style="text-align: center;">'."\n";
	print '<option value="">'.$time_range_from[$lang].'</option>'."\n";
	for ($t=1;$t<$r;$t++) {

		print '<option value="'.$to_tble[$t].'"';
			if ($time2_start==$to_tble[$t]) {
				print 'selected="selected"'; 
			}
		print '>'.$to_tble[$t].'</option>'."\n";
	
	}

	print '</select>'."\n";
	print '&nbsp;';
	print '<select class="cc" name="time2_end" style="text-align: center;">'."\n";
	print '<option value="">'.$time_range_to[$lang].'</option>'."\n";

	for ($t=1;$t<$r;$t++) {

		print '<option value="'.$to_tble[$t].'"';
			if ($time2_end==$to_tble[$t]) {
				print 'selected="selected"'; 
			}
		print '>'.$to_tble[$t].'</option>'."\n";
	
	}

	print '</select>'."\n";

}

print '<input class="red" type="submit" value="'.$search_box[$lang].'">'."\n";
print '</form></td>'."\n";
print '</tr>'."\n";
print '<tr height="12" class="maint"><td colspan="11" width="100%"></td></tr>'."\n";
print '<tr height="3" class="spacer"><td colspan="11" width="100%"></td></tr>'."\n";
print '</table>'."\n";

print '<p align="center"><b>'.$alert.'</b></p>';


?>
