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

$query = "select b.id_event, b.event as event,c.level as level, c.id_level, a.log_time,a.extra from jorge_logger a,jorge_logger_dict b,jorge_logger_level_dict c where a.id_log_detail=b.id_event and c.id_level=a.id_log_level and  id_user='$user_id' order by log_time desc";
print '<center>';
print '<table id="maincontent" class="ff" align="center" border="0" colspan="0" cellspacing="0" >'."\n";
print '<tr class="maint"><td style="padding-left: 5px; padding-right: 0px;">'.$logger_f1[$lang].'</td><td style="padding-left: 0px; padding-right: 10px;">'.$logger_f2[$lang].'</td><td style="padding-left: 0px; padding-right: 10px;">'.$logger_f3[$lang].'</td><td style="padding-left: 0px; padding-right: 10px;">'.$logger_f4[$lang].'</td></tr>'."\n";
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
#	print '<tr height="1px"><td colspan="4"></td></tr>';




}




print '<tr class="spacer"><td colspan="4"></td></tr>'."\n";
print '<tr class="maint" height="10px"><td colspan="4"></td></tr>'."\n";
print '</tbody>';
print '</table>'."\n";
print '</center>';







include("footer.php");
?>
