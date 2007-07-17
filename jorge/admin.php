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

$today="";

$today = date("Y-n-d");

$top_ten_talkers_today="select at, owner_id, count from `messages-stats_$xmpp_host` where at = '$today' order by count desc limit 10";
$top_ten_talkers_yesterday="select at, owner_id, count from `messages-stats_$xmpp_host` where at = (select date_format((date_sub(curdate(),interval 1 day)), \"%Y-%c-%d\")) order by count desc limit 10";

$month_stats="select count(owner_id) users_total, at, sum(count) as messages from `messages-stats_$xmpp_host` group by at order by str_to_date(at,'%Y-%m-%d') desc limit 30";
$result=mysql_query($month_stats);
while ($entry=mysql_fetch_array($result)) {
	$i++;
	$d[$i] = $entry[messages];
	$e[$i] = $entry[users_total];
	
}

$maximum_a = max($e);
$maximum_b = max($d);

print '<table class="ff">'."\n";
print '<tr><td>'."\n";
print '<p><b>Number of user using message archiving:</b></p>'."\n";
print '<div id="chart" class="chart" style="width: 1000px; height: 200px;"></div>'."\n";
print '<p><b>Number of messages logged by server:</b></p>';
print '<div id="messages" class="chart" style="width: 1000px; height: 200px;"></div>'."\n";
print '</td>';
print '<td style="padding-left: 30px">'."\n";
print '<div><b>Top ten talkers today:</b><br><br>'."\n";
$result=mysql_query($top_ten_talkers_today);
$i=0;
while ($entry=mysql_fetch_array($result)) {
	
	$i++;
	print "<b>".$i.".</b> ".get_user_name($entry[owner_id],$xmpp_host)."@".$xmpp_host." (<i>$entry[count]</i>)<br>"."\n";

}
print '</div>'."\n";
print '<br><hr size="1" noshade="" color="#cccccc"/><br>'."\n";
$i=0;
print '<div><b>Top ten talkers yesterday:</b><br><br>'."\n";
$result=mysql_query($top_ten_talkers_yesterday);
while ($entry=mysql_fetch_array($result)) {

	$i++;
	print "<b>".$i.".</b> ".get_user_name($entry[owner_id],$xmpp_host)."@".$xmpp_host." (<i>$entry[count]</i>)<br>"."\n";
	
}

print '</td>'."\n";
print '</tr></table>'."\n";

?>

<script type="text/javascript">
    	function draw() {
    		var b = new Chart(document.getElementById('chart'));
				b.setDefaultType(CHART_LINE);
				b.setGridDensity(32, 10);
				<? print "b.setVerticalRange(0, $maximum_a);"; ?>	
				b.setHorizontalLabels(['30','29','28','27','26','25','24','23','22','21','22','21','20','19','18','17','16','15','14','13','12','11','10','9','8','7','6', '5', '4', '3', '2', '1']);
				<? print "b.add ('Last 30 days', '#ff0000', ["; 
			
				for ($z=30; $z>0; $z--) {
						
						print "$e[$z],$e[$z],";
					
					}
				print "]);\n";


?>
				b.draw();
    	
	
	var b = new Chart(document.getElementById('messages'));
				b.setDefaultType(CHART_LINE);
				b.setGridDensity(32, 10);
				<? print "b.setVerticalRange(0, $maximum_a);"; ?>	
				b.setHorizontalLabels(['30','29','28','27','26','25','24','23','22','21','22','21','20','19','18','17','16','15','14','13','12','11','10','9','8','7','6', '5', '4', '3', '2', '1']);
				<? print "b.add ('Last 30 days', '#3480ff', ["; 
			
				for ($z=30; $z>0; $z--) {
						
						print "$d[$z],$d[$z],";
					
					}
				print "]);\n";


?>
				b.draw();
    	

	
	}
    	
    	window.onload = function() {
    		draw();
    	};

</script>



<?

include ("footer.php");
?>
