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

require ("headers.php");
require ("upper.php");

print '<h2>'.$logger_overview[$lang].'</h2>';

if ($_GET[a]) {
	$offset_start=$_GET[a];
	// we want only digits here,silently drop any invalid data and fallback to zero
	if (!ctype_digit($offset_start)) { unset($offset_start); }
	// and for sure, lets escape some, it is not nessesery as we validate this var abowe, but who knows if ctype have some bugs?
	$offset_start=mysql_escape_string($offset_start);
	}

// Filter
if (isset($_POST['e']) AND isset($_POST['l'])) {
		$event_id=$_POST['e'];
		$level_id=$_POST['l'];
	}
	else{
		$event_id=$_GET['e'];
		$level_id=$_GET['l'];
	}

// validate
if (!ctype_digit($event_id) AND !ctype_digit($level_id)) { unset($level_id); unset($event_id); }

if ($event_id=="1") {
		$event="and id_log_detail='1'";
	}
	elseif($event_id=="2") {
		$event="and id_log_detail='2'";
	}
	elseif($event_id=="3") {
		$event="and id_log_detail='3'";
	}
	elseif($event_id=="4") {
		$event="and id_log_detail='4'";
	}
	elseif($event_id=="5") {
		$event="and id_log_detail='5'";
	}
	elseif($event_id=="6") {
		$event="and id_log_detail='6'";
	}
	elseif($event_id=="7") {
		$event="and id_log_detail='7'";
	}
	elseif($event_id=="8") {
		$event="and id_log_detail='8'";
	}
	else{
		$event="";
	}

if ($level_id=="1"){
		$level="and id_log_level='1'";
	}
	elseif($level_id=="2"){
		$level="and id_log_level='2'";
	}
	elseif($level_id=="3"){
		$level="and id_log_level='3'";
	}
	else{
		$level="";
	}

print '<div align="center">';
print '<form method="post" action="logger.php">';
print '<select name="e" class="cc3">';
print '<option value="none">--- select event ---';
print '<option value="1"'; if ($event_id=="1") { print ' "selected"'; } print '>Login';
print '<option value="2"'; if ($event_id=="2") { print ' "selected"'; } print ' >Logout';
print '<option value="3"'; if ($event_id=="3") { print ' "selected"'; } print ' >Login failed';
print '<option value="4"'; if ($event_id=="4") { print ' "selected"'; } print ' >Chat deletion';
print '<option value="5"'; if ($event_id=="5") { print ' "selected"'; } print ' >Entire archive deletion';
print '<option value="6"'; if ($event_id=="6") { print ' "selected"'; } print ' >Turn off archivization';
print '<option value="7"'; if ($event_id=="7") { print ' "selected"'; } print ' >Turn on archivization';
print '<option value="8"'; if ($event_id=="8") { print ' "selected"'; } print ' >Chat exports';
print '</select>&nbsp;';
print '<select name="l" class="cc3">';
print '<option value="none">--- select level ---';
print '<option value="1"'; if ($level_id=="1") { print ' "selected"'; } print '>normal';
print '<option value="2"'; if ($level_id=="2") { print ' "selected"'; } print '>warning';
print '<option value="3"'; if ($level_id=="3") { print ' "selected"'; } print '>alert';
print '</select>';
print '<input type="submit" name="filter_commit" value="Filter">';
print '</form>';
print '</div>';

if (!$offset_start) { $offset_start=0; }

$row=mysql_fetch_row(mysql_query("select count(id_user) from jorge_logger where id_user='$user_id' $event $level"));
$nume=$row[0];

//lets make code full-proff...discard userimput grater then his max events...
if ($offset_start>$nume) { $offset_start=0; } 

$query = "SELECT b.id_event, b.event AS event,c.level AS level, c.id_level, a.log_time,a.extra 
		FROM jorge_logger a,jorge_logger_dict b,jorge_logger_level_dict c 
		WHERE a.id_log_detail=b.id_event AND c.id_level=a.id_log_level AND id_user='$user_id' $event $level
		ORDER BY log_time DESC LIMIT $offset_start,300";

print '<center>';
print '<table id="maincontent" class="ff" align="center" border="0" colspan="0" cellspacing="0" >'."\n";
print '<tr class="header"><td style="padding-left: 5px; padding-right: 0px;">'.$logger_f1[$lang].'</td><td style="padding-left: 0px; padding-right: 10px;">'.$logger_f2[$lang].'</td><td style="padding-left: 0px; padding-right: 10px;">'.$logger_f3[$lang].'</td><td style="padding-left: 0px; padding-right: 10px;">'.$logger_f4[$lang].'</td></tr>'."\n";
print '<tr class="spacer"><td colspan="4"></td></tr>'."\n";
print '<tbody id="searchfield">';

$result=mysql_query($query);
while ($results=mysql_fetch_array($result)) {


	if ($results[id_event]=="1" OR $results[id_event]=="3") { $ip_desc=$logger_f_ip[$lang]; } else { $ip_desc=""; }
	if ($results[id_level] == "3") { $col="main_row_b"; $f_color="style=\"color: red;\""; } else { $col="main_row_a"; $f_color=""; }
	print '<tr class="'.$col.'" '.$f_color.'><td style="padding-left: 0px; padding-right: 10px;">'.$results[event].'</td>'."\n";
	print '<td>'.$results[log_time].'</td>'."\n";
	print '<td style="text-align: center;">'.$results[level].'</td>'."\n";
	print '<td style="padding-left: 5px;">'.htmlspecialchars($ip_desc.$results[extra]).'</td></tr>'."\n";

}

print '</tbody>';

// pagination
print '<tr class="spacer" height="1px"><td colspan="4"></td></tr>';
print '<tr class="foot"><td style="text-align: center;" colspan="4">';
for($i=0;$i < $nume;$i=$i+300){

	if ($i!=$offset_start) {
		if (isset($event_id)){
				$e="&e=$event_id";
			}
		if (isset($level_id)){
				$l="&l=$level_id";
			}
		print '<a href="?a='.$i.$e.$l.'"> <b>['.$i.']</b> </font></a>';
	
	}
	    
	    else { 
	    	print ' -'.$i.'- '; 
	}

    }
print '</td></tr>';


print '</table>'."\n";
print '</center>';

include("footer.php");
?>
