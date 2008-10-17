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

// global user stats and total messages - last 30 days
$db->get_monthly_stats();
$result = $db->result;

if (count($result)<30) { 

		$mark1="1"; 
		
	} 
	else { 
	
		$mark1="0"; 
	
}

foreach ($result as $entry) {

	$i++;
	$f[$i] = $entry[time_unix];
	$d[$i] = $entry[messages];
	$e[$i] = $entry[users_total];
	
}

// hourly stats
$db->get_hourly_stats($yesterday);
$result = $db->result;
foreach ($result as $entry) {

	$hs[$entry[hour]] = $entry[value];
}

// weekly stats
$db->get_weekly_stats($last_week,$yesterday);
$result = $db->result;
foreach ($result as $entry) {
	
	$idx++;
	$hy[$idx] = $entry[value];

}

$db->total_messages();
$total_messages = $db->result->total_messages;
$db->total_chats();
$total_chats = $db->result->total_chats;

$html->set_overview('<h2><u>Stats for: '.XMPP_HOST.'</u></h2><p style="padding-left: 10px;">
		Total <b>'.number_format($total_messages).'</b> messages logged by the server in <b>'.number_format($total_chats).'</b> conversations.</b></p>
		<hr size="1" noshade="noshade" style="color: #cccccc;">
		<table class="ff">');

if ($mark1=="0") {
		$html->set_body('<tr>
			<td style="padding-left: 10px">
			<div id="no_users" style="width:1000px;height:250px;"></div><br>
			<div id="no_messages" style="width:1000px;height:250px;"></div><br>
			<div id="hourly_yesterday" style="width:1000px;height:250px;"></div><br>
			<div id="hourly_week" style="width:1000px;height:250px;"></div></td>
			<td style="padding-left: 30px; vertical-align: top;">
			<div><b>Top 10 talkers today:</b><br><br>
			');

	}
	else{

		$html->status_message('Not enough data collected for graphs (<i>minimum required: 30 days</i>).');
		$html->set_body('<tr><td><div><b>Top 10 talkers today:</b><br><br>');
		
	
}


$i=0;
$db->get_top_ten($today);
$result = $db->result;
foreach ($result as $entry) {
	
	$i++;
	$db->get_user_name($entry[owner_id]);
	$local_user = $db->result->username;
	$db->get_user_name($entry[peer_name_id]);
	$peer_name = $db->result->username;
	$db->get_server_name($entry[peer_server_id]);
	$peer_server = $db->result->server_name;
	$html->set_body('<b>'.$i.'.</b> '.htmlspecialchars($local_user).'@'.XMPP_HOST.'<b> --> </b>'.htmlspecialchars($peer_name).'@'.htmlspecialchars($peer_server).' (<i><b>'.$entry[count].'</b></i>)<br>');

}

$html->set_body('</div><br><hr size="1" noshade="noshade" style="color: #cccccc;"><br>');

$html->set_body('<div><b>Top 10 talkers yesterday:</b><br><br>');
$i=0;
$db->get_top_ten($yesterday);
$result = $db->result;
foreach ($result as $entry) {

	$i++;
	$db->get_user_name($entry[owner_id]);
	$local_user = $db->result->username;
	$db->get_user_name($entry[peer_name_id]);
	$peer_name = $db->result->username;
	$db->get_server_name($entry[peer_server_id]);
	$peer_server = $db->result->server_name;
	$html->set_body('<b>'.$i.'.</b> '.htmlspecialchars($local_user).'@'.XMPP_HOST.'<b> --> </b>'.htmlspecialchars($peer_name).'@'.htmlspecialchars($peer_server).' (<i><b>'.$entry[count].'</b></i>)<br>');
	
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
