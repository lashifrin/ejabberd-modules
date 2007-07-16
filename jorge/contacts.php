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

include ("upper.php");
print '<h2>'.$con_head[$lang].'</h2>';
print '<small>'.$con_notice[$lang].'</small>';

$res = pg_query($bazaj, "select a.nick, a.jid, b.grp from rosterusers a left outer join rostergroups b on (a.jid=b.jid and a.username=b.username) where a.username='$token' and a.nick !='' order by b.grp,a.nick");
if (!$res) {
	print "Ooops...";
	pg_close($jmon);
	exit;
}

print '<center>';
print '<table id="maincontent" border="0" class="ff" cellspacing="0">'."\n";
print '<tr class="maint"><td>'.$con_tab2[$lang].'</td><td>'.$con_tab3[$lang].'</td><td>'.$con_tab6[$lang].'</td><td>'.$con_tab4[$lang].'</td></tr>'."\n";
print '<tr class="spacer"><td colspan="4"></td></tr>';
print '<tbody id="searchfield">';

for ($lt = 0; $lt < pg_numrows($res); $lt++) {
	$nick = pg_result($res, $lt, 0);
	$jid = pg_result($res,$lt,1);
	$grp = pg_result($res,$lt,2);
	if ($grp=="") { $grp=$con_no_g[$lang]; }
	if ($col=="e0e9f7") { $col="e8eef7"; } else { $col="e0e9f7"; }
	$predefined="from:$jid";
	$predefined=encode_url($predefined,$token,$url_key);
	print '<tr title="'.$con_title[$lang].'" style="cursor: pointer;" bgcolor="'.$col.'" onclick="window.open(\'search_v2.php?b='.$predefined.'\');" onMouseOver="this.bgColor=\'c3d9ff\';" onMouseOut="this.bgColor=\'#'.$col.'\';">';
	print '<td style="padding-left:7px"><b>'.cut_nick(htmlspecialchars($nick)).'</b></td>'."\n";
	print '<td>(<i>'.htmlspecialchars($jid).'</i>)</td>'."\n";
	print '<td style="text-align: center;">'.cut_nick(htmlspecialchars($grp)).'</td>';
	print '<td style="text-align: center;"><input type="checkbox" disabled="disabled"></td>'."\n";
	print '</tr>'."\n";

}
print '</tbody>'."\n";
print '</table>'."\n";
print '</center>'."\n";

include ("footer.php");
?>
