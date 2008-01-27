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

if ($admin_name!=$token) { print 'no access'; exit; }

$today = date("Y-n-j");

$top_ten_talkers_today="select at, owner_id, peer_name_id, peer_server_id, count from `logdb_stats_$xmpp_host` where at = '$today' order by count desc limit 10";
$top_ten_talkers_yesterday="select at, owner_id, peer_name_id, peer_server_id, count from `logdb_stats_$xmpp_host` where at = (select date_format((date_sub(curdate(),interval 1 day)), \"%Y-%c-%e\")) order by count desc limit 10";
$month_stats="select count(distinct(owner_id)) users_total, at, sum(count) as messages from `logdb_stats_$xmpp_host` group by at order by str_to_date(at,'%Y-%m-%d') desc limit 30";
$result=mysql_query($month_stats);
if (mysql_num_rows($result)<30) { $mark1="1"; } else { $mark1="0"; }

while ($entry=mysql_fetch_array($result)) {
	$i++;
	$d[$i] = $entry[messages];
	$e[$i] = $entry[users_total];
	
}

// Hourly stats (long running query!)
for ($ds=0;$ds<24;$ds++) {
	$tm++;
	$de=$ds+1;
	if ($de==24) {$de=0;}
	$hourly_t="select count(owner_id) from `logdb_messages_$today"."_"."$xmpp_host` where timestamp > unix_timestamp('$today $ds:00:00') and timestamp < unix_timestamp('$today $de:00:00')";
	$result=mysql_query($hourly_t);
	$row=mysql_fetch_row($result);
	$hs[$tm] = $row[0];
	}

// yesterday
$tm=0;$de=0;
$yesttd = date("Y-n-d", strtotime ("-1 day"));
for ($ds=0;$ds<24;$ds++) {
	$tm++;
	$de=$ds+1;
	if ($de==24) {$de=0;}
	$hourly_t="select count(owner_id) from `logdb_messages_$yesttd"."_"."$xmpp_host` where timestamp > unix_timestamp('$yesttd $ds:00:00') and timestamp < unix_timestamp('$yesttd $de:00:00')";
	$result=mysql_query($hourly_t);
	$row=mysql_fetch_row($result);
	$hy[$tm] = $row[0];
	}


$maximum_a = max($e);
$maximum_b = max($d);

print "<h2><u>Stats for: ".$xmpp_host_dotted."</u></h2>";
print "<p style=\"padding-left: 10px;\">Total <b>".number_format(total_messages($xmpp_host))."</b> messages logged by the server in <b>".number_format(total_chats($xmpp_host))."</b> conversations. Current database size is: <b>".db_size()."</b> MB</p>";
print '<hr size="1" noshade="" color="#cccccc"/>'."\n";
print '<table class="ff">'."\n";
print '<tr><td style="padding-left: 10px">'."\n";
if ($mark1=="1") { print '<h1>Not enough data collected for graphs</h1><h2>minimum required: 30 days</h2>';}
print '<div id="no_users" style="width:1000px;height:250px;"></div>'."\n";
print "<br>";
print '<div id="no_messages" style="width:1000px;height:250px;"></div>'."\n";
print "<br>";
print '<div id="hourly_today" style="width:1000px;height:250px;"></div>'."\n";
print "<br>";
print '<div id="hourly_yesterday" style="width:1000px;height:250px;"></div>'."\n";
print '</td>';
print '<td style="padding-left: 30px">'."\n";
print '<div><b>Top 10 talkers today:</b><br><br>'."\n";
$result=mysql_query($top_ten_talkers_today);
$i=0;
while ($entry=mysql_fetch_array($result)) {
	
	$i++;
	print "<b>".$i.".</b> ".htmlspecialchars(get_user_name($entry[owner_id],$xmpp_host))."@".$xmpp_host_dotted."<b> <--> </b>".htmlspecialchars(get_user_name($entry[peer_name_id],$xmpp_host))."@".htmlspecialchars(get_server_name($entry[peer_server_id],$xmpp_host))." (<i><b>$entry[count]</b></i>)<br>"."\n";

}
print '</div>'."\n";
print '<br><hr size="1" noshade="" color="#cccccc"/><br>'."\n";
$i=0;
print '<div><b>Top 10 talkers yesterday:</b><br><br>'."\n";
$result=mysql_query($top_ten_talkers_yesterday);
while ($entry=mysql_fetch_array($result)) {

	$i++;
	print "<b>".$i.".</b> ".htmlspecialchars(get_user_name($entry[owner_id],$xmpp_host))."@".$xmpp_host_dotted."<b> <--> </b>".htmlspecialchars(get_user_name($entry[peer_name_id],$xmpp_host))."@".htmlspecialchars(get_server_name($entry[peer_server_id],$xmpp_host))." (<i><b>$entry[count]</b></i>)<br>"."\n";
	
}

print '</td>'."\n";
print '</tr></table>'."\n";

if ($mark1=="0") { 

?>

<script id="source" language="javascript" type="text/javascript">
$(function () {

    var d1 = [
<?
	$cn=31;
	for ($z=1;$z<31;$z++) {
		$cn--;
		print "[$z,$e[$cn]],";
	}
?>


	];

    var d2 = [

<?
	$cn=31;
	for ($z=1; $z<31; $z++) {
		$cn--;
		print "[$z,$d[$cn]],";
	}
?>


	];

     var d3 = [
<?
	$cn=0;
	for ($z=0;$z<24;$z++) {
		$cn++;
		print "[$z,$hs[$cn]],";
	}
?>

	];

     var d4 = [
<?
	$cn=0;
	for ($z=0;$z<24;$z++) {
		$cn++;
		print "[$z,$hy[$cn]],";
	}
?>

	];
    
    $.plot($("#no_users"), [

		{
		color: "#ff0000",
		label: "Users who enabled message archivization - last 30 days", shadowSize: 10, data: d1,
		lines: { show: true },
		points: { show: true, fill: true, radius: 4}
		}



	]);
    $.plot($("#no_messages"), [

		{
		color: "#3480ff",
		label: "Messages logged by server - last 30 days", shadowSize: 10, data: d2,
		lines: { show: true },
		points: { show: true, fill: true, radius: 4}
		}



	]);
    $.plot($("#hourly_today"), [

		{
		color: "#ff0000",
		label: "Hourly Statistics - Today", shadowSize: 10, data: d3,
		bars: { show: true }
		}



	]);
    $.plot($("#hourly_yesterday"), [

		{
		color: "#3480ff",
		label: "Hourly Statistics - Yesterday", shadowSize: 10, data: d4,
		bars: { show: true }
		}
	]);

});

</script>


<?

}

include ("footer.php");
?>
