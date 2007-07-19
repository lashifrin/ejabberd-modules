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

// all we need is header.php file - be sure to include it in all Jorge files! as it containg authentication futures.
require ("headers.php");

$inpLogin=$_POST[inpLogin];
$inpPass=$_POST[inpPass];
$wo_sess=$_POST[word];
$lng_sw=$_GET['lng_sw'];

$inpLogin=pg_escape_string($inpLogin);
$inpPass=pg_escape_string($inpPass);
$inpLogin = strtolower($inpLogin);

// language selection
if ($lng_sw=="pol") {
		$sess->set('language','pol'); } 
	elseif($lng_sw=="eng") 
		{ $sess->set('language','eng'); }


// defaults to english
if (!$sess->get('language')) { $sess->set('language',$lang_def); }
$lang=$sess->get('language');

if ($wo_sess || $$inpLogin || $inpPass) {

	if ($wo_sess!=$sess->get('image_w')) { 

			unset($inpPass);
			}


}

if ($_GET['act']=='logout') {
	$sess->finish();
	header("Location: index.php");
	} else {
	if ($inpLogin!="" || $inpPass!="") {
	if(auth($bazaj,$inpLogin,$inpPass)=="t") {

	          $sess->set('login',$inpLogin);
		  $sess->set('uid_l',$inpLogin);
		  $sess->set('uid_p',$inpPass);
		  $ret_v=is_log_enabled(get_user_id($sess->get('uid_l'),$xmpp_host),$xmpp_host);
		  if (($ret_v[0]) == "t") {
		  $sess->set('enabled','t');
		  $sess->set('log_status',$ret_v[1]);
		  $sess->set('image_w','');
		  header("Location: main.php");
		  }
		  	else {
				
				$sess->set('enabled','f');
				$sess->set('log_status',$ret_v[1]);
				$sess->set('image_w','');
				header("Location: not_enabled.php"); }

		}

	$error_m="<br /><span class=\"hlt\"><b>$wrong_data[$lang]</b></span>";

	}
 
}


?>

<script language="javascript">
<!--
function new_freecap()
{
	if(document.getElementById)
	{
		thesrc = document.getElementById("freecap").src;
		thesrc = thesrc.substring(0,thesrc.lastIndexOf(".")+4);
		document.getElementById("freecap").src = thesrc+"?"+Math.round(Math.random()*10000);
	} else {
		alert("Ups...");
	}
}
//-->
</script>
<?

if ($lang=="eng") { $lang_o="pol"; } elseif($lang=="pol") { $lang_o="eng"; }
print '<table class="ff" cellspacing="0" width="100%">';
print '<tr>';
print '<td style="text-align: left;">'.$welcome_1[$lang].'</td><td style="text-align: right;">';
print '<a href="index.php?lng_sw='.$lang_o.'">'.$ch_lan2[$lang].$lang_sw2[$lang].'</a></td>';
print '<tr height="12" class="maint"><td colspan="2" width="100%"></td></tr>'."\n";
print '<tr height="3" class="spacer"><td colspan="2" width="100%"></td></tr>'."\n";
print '</tr></table>';

    echo '<center>'."\n";
    echo '<form action="index.php" method="post">'."\n";
    echo '<br /><br /><table class="ff" border="0" cellspacing="0" cellpadding="0">'."\n";
    echo '<tr><td align="right">'.$login_w[$lang].'&nbsp;</td><td><input name="inpLogin" value="'.$_POST[inpLogin].'" class="log" ></td><td>@'.$xmpp_host_dotted.'</td></tr>'."\n";
    echo '<tr height="3" ><td></td></tr>';
    echo '<tr><td align="right">'.$passwd_w[$lang].'&nbsp;</td><td><input name="inpPass" type="password" class="log"></td></tr>'."\n";
    echo '<tr height="10"><td></td></tr>';
	echo '<tr><td></td><td colspan="2"><img src="freecap.php" id="freecap" name="pic"></td></tr>';
	echo '<tr height="3" ><td></td></tr>';
	echo '<tr><td></td><td colspan="2" style="text-align: center;"><a href="#" onClick="new_freecap();return false;"><small>'.$cap_cant[$lang].'</small></a></td></tr>';
	echo '<tr height="3" ><td></td></tr>';
	echo '<tr><td align="right">'.$cap_w[$lang].'&nbsp;</td><td><input name="word" type="text" class="log" ></td>'."\n";
	echo '<tr height="15" ><td></td></tr>';
    echo '<tr><td colspan="2" align="right"><input class="red" type="submit" name="sublogin" value="'.$login_act[$lang].'"></td></tr>'."\n";
    echo '</table>'."\n";
    echo '</form>'."\n";
    print $error_m;
    echo '</center>'."\n";
include("footer.php");
?>
