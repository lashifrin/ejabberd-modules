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

$location=$_SERVER['PHP_SELF'];


if ($location=="footer.php") {
	header('Location: index.php?act=logout');
	exit;
}

if (!preg_match("/index.php/i",$location)) {

print '<div align="right" style="clear: left;"><a href="mailto:zzolkiewski@aster.com.pl">'.$quest1[$lang].'</a></div>';

}

?>
<br>
<div style="background-image: url(img/bell-down.png); height: 3px;"></div>
<div align="center"><? print $links; ?></div><br>
<div align="center" style="color: gray;"><? print $copy; ?></small></div>
<?

// footer for admins...
$time_end = getmicrotime();
$time = substr($time_end - $time_start, 0, 10);
if ($token==$admin_name) {print '<small>'.$admin_site_gen[$lang].$time.'s.</small>'; };

// execude following code only when user is logged in
if (!preg_match("/index.php/i",$location)) {

?>

<script type="text/javascript">
	$(document).ready(function() {
	$("#t_search").autocomplete(
		[

	<?
	// this is for local autocomplete, TODO: make it dynamic via AJAX
	$jquery_search="select jid from rosterusers where username='$token' order by jid";
	$res = pg_query($bazaj, $jquery_search);
	if (!$res) {
	        print "Ooops...";
		        pg_close($bazaj);
			        exit;
				}

	for ($lt = 0; $lt < pg_numrows($res); $lt++) {
		$jid = pg_result($res, $lt, 0);
		print '"from:'.$jid.'", ';
	}

	print "\" \"";

	?>
		],
		{
		minChars: 0,
		max: 10,
		cacheLength: 200,
		matchSubset: true,
		selectFirst: false,
		matchContains: true
		}

	);
});

</script>

<?

}

?>

</body>
</html>
<?
	ob_end_flush();
?>
