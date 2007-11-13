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
print '<h2>'.$cal_head[$lang].'</a></small></h2>';
print '<small>'.$cal_notice[$lang].'. <a href="main.php"><u>'.$change_view[$lang].'</u></a></small><br><br>';

$query="select substring(at,1,7) as at_m from `logdb_stats_$xmpp_host` where owner_id='$user_id' group by at_m order by str_to_date(at_m,'%Y-%m-%d') asc";
$result=mysql_query($query);

print '<div class="contain"><div class="spacer_div">&nbsp;</div>';

while($row=mysql_fetch_array($result)) {

	$query_days="select substring(at,8,9) as days from `logdb_stats_$xmpp_host` where owner_id = '$user_id' and substring(at,1,7) = '$row[at_m]' order by str_to_date(at,'%Y-%m-%d') asc";
	$result_for_days=mysql_query($query_days);

	$i=0;
	while ($row_d=mysql_fetch_array($result_for_days)) {

		$i++;
		$days[$i] = str_replace("-","",$row_d[days]); // hack for bad parsing

	}

	list($y,$m) = split("-", $row[at_m]);
	echo pl_znaczki(calendar($y,$m,$days,$token,$url_key,$months_name_eng));
	echo '</div></div>';
	unset($days);

}

print '<div class="spacer_div">&nbsp;</div>';
print '</div>';
            
include ("footer.php");


?> 
