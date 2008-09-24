<?
/*
Jorge - frontend for mod_logdb - ejabberd server-side message archive module.

Copyright (C) 2008 Zbigniew Zolkiewski

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
require_once("headers.php");
require_once("upper.php");

if (ADMIN_NAME!==TOKEN) { 

	print 'no access'; 
	exit; 

}

// get dates
$today = date("Y-n-j");
$yesterday = date("Y-n-j", strtotime("-1 day"));
$last_week = date("Y-n-j", strtotime("-7 days"));

// user stats
$top_ten_talkers_today="select at, owner_id, peer_name_id, peer_server_id, count from `logdb_stats_$xmpp_host` where at = '$today' order by count desc limit 10";
$top_ten_talkers_yesterday="select at, owner_id, peer_name_id, peer_server_id, count from `logdb_stats_$xmpp_host` where at = (select date_format((date_sub(curdate(),interval 1 day)), \"%Y-%c-%e\")) order by count desc limit 10";

// global user stats and total messages - last 30 days
$month_stats="select count(distinct(owner_id)) users_total, unix_timestamp(at)*1000 as time_unix, sum(count) as messages from `logdb_stats_$xmpp_host` group by at order by str_to_date(at,'%Y-%m-%d') desc limit 30";
$result=mysql_query($month_stats) or die;
if (mysql_num_rows($result)<30) { $mark1="1"; } else { $mark1="0"; }

while ($entry=mysql_fetch_array($result)) {
	$i++;
	$f[$i] = $entry[time_unix];
	$d[$i] = $entry[messages];
	$e[$i] = $entry[users_total];
	
}
mysql_free_result();

// hourly stats
$h_resolution="select hour,value from jorge_stats where day='$yesterday' and vhost='".XMPP_HOST."' order by hour asc";
$result=mysql_query($h_resolution);
while ($entry=mysql_fetch_array($result)) {

	$hs[$entry[hour]] = $entry[value];
}
mysql_free_result();

// weekly/hours
$w_resolution="select hour,value from jorge_stats where day<='$yesterday' and day >= '$last_week' and vhost='".XMPP_HOST."' order by day,hour asc";
$result=mysql_query($w_resolution);
while ($entry=mysql_fetch_array($result)) {
	
	$idx++;
	$hy[$idx] = $entry[value];

}
mysql_free_result();


$html->set_body('<h2><u>Stats for: '.$xmpp_host_dotted.'</u></h2><p style="padding-left: 10px;">
		Total <b>'.number_format(total_messages($xmpp_host)).'</b> messages logged by the server in <b>'.number_format(total_chats($xmpp_host)).'</b> conversations. Current database size is: <b>'.db_size().'</b> MB</p>
		<hr size="1" noshade="noshade" style="color: #cccccc;"><table class="ff">
		<tr><td style="padding-left: 10px"><div id="no_users" style="width:1000px;height:250px;"></div><br>
		<div id="no_messages" style="width:1000px;height:250px;"></div><br>
		<div id="hourly_yesterday" style="width:1000px;height:250px;"></div><br>
		<div id="hourly_week" style="width:1000px;height:250px;"></div></td>
		<td style="padding-left: 30px; vertical-align: top;">
		<div><b>Top 10 talkers today:</b><br><br>
		');

if ($mark1=="1") { 

	$html->alert_message('Not enough data collected for graphs</h1><h2>minimum required: 30 days');
	
}


$result=mysql_query($top_ten_talkers_today);
$i=0;
while ($entry=mysql_fetch_array($result)) {
	
	$i++;
	$html->set_body('<b>'.$i.'.</b> '.htmlspecialchars(get_user_name($entry[owner_id],$xmpp_host)).'@'.$xmpp_host_dotted.'<b> --> </b>'.htmlspecialchars(get_user_name($entry[peer_name_id],$xmpp_host)).'@'.htmlspecialchars(get_server_name($entry[peer_server_id],$xmpp_host)).' (<i><b>'.$entry[count].'</b></i>)<br>');

}
$html->set_body('</div><br><hr size="1" noshade="noshade" style="color: #cccccc;"><br>');

$i=0;
$html->set_body('<div><b>Top 10 talkers yesterday:</b><br><br>');

$result=mysql_query($top_ten_talkers_yesterday);
while ($entry=mysql_fetch_array($result)) {

	$i++;
	$html->set_body('<b>'.$i.'.</b> '.htmlspecialchars(get_user_name($entry[owner_id],$xmpp_host)).'@'.$xmpp_host_dotted.'<b> --> </b>'.htmlspecialchars(get_user_name($entry[peer_name_id],$xmpp_host)).'@'.htmlspecialchars(get_server_name($entry[peer_server_id],$xmpp_host)).' (<i><b>'.$entry[count].'</b></i>)<br>');
	
}

$html->set_body('</td></tr></table>');

if ($mark1=="0") { 

$html->set_body('

<script id="source" language="javascript" type="text/javascript">
$(function () {

    var d1 = [

');

	$cn=31;
	for ($z=1;$z<31;$z++) {
		$cn--;
		$html->set_body("[$f[$cn],$e[$cn]],");
	}

$html->set_body('


	];

    var d2 = [

');
	$cn=31;
	for ($z=1; $z<31; $z++) {
		$cn--;
		$html->set_body("[$f[$cn],$d[$cn]],");
	}

$html->set_body('


	];

     var d3 = [

');
	for ($z=0;$z<24;$z++) {
		$html->set_body("[$z,$hs[$z]],");
	}

$html->set_body('

	];

     var d4 = [
');

	$idx=0;
	for ($z=0;$z<168;$z++) {
		$idx++;
		$html->set_body("[$z,$hy[$idx]],");
	}

$html->set_body('

	];
    
    $.plot($("#no_users"),
    			[d1], {
				xaxis: { mode: "time" },
				label: "Users who enabled message archivization - last 30 days",
				shadowSize: 10,
				lines: { show: true, fill: true },
				points: { show: true, fill: true, radius: 3}
			});

    $.plot($("#no_messages"), 
    			[d2],{ 
				xaxis: { mode: "time" },
				label: "Messages logged by server - last 30 days",
				shadowSize: 10,
				lines: { show: true, fill: true },
				points: { show: true, fill: true, radius: 3}
				
			});
    
    $.plot($("#hourly_yesterday"), [

		{
		color: "#ff0000",
		label: "Hourly Statistics - Yesterday ('.$yesterday.')", shadowSize: 10, data: d3,
		bars: { show: true }
		}



	]);
    $.plot($("#hourly_week"), [

		{
		color: "#3480ff",
		label: "Hourly Statistics - Weekly Raport ('.$last_week.' - '.$yesterday.')", shadowSize: 10, data: d4,
		bars: { show: true }
		}
	]);

});

</script>

');

}

require_once("footer.php");
?>
