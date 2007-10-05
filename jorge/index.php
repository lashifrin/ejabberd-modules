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
	$ui = get_user_id($sess->get('uid_l'),$xmpp_host);
	mysql_query("insert into jorge_logger (id_user,id_log_detail,id_log_level,log_time) values ('$ui',2,1,NOW())");
	if (($sess->get('uid_l'))!="") {
		// purge deletion table upon exit
		$result=mysql_query("select peer_name_id,date from pending_del where owner_id='$ui'");
		// prevent code execution if there is nothing to delete
		if (mysql_num_rows($result)>0) {
			while($row = mysql_fetch_array($result)) {
      				$talker = $row["peer_name_id"];
				$tslice = $row["date"];
				mysql_query("delete from `logdb_messages_$tslice"."_$xmpp_host` where owner_id='$ui' and peer_name_id='$talker' and ext = '1'");
  			}
			mysql_query("delete from jorge_mylinks where owner_id='$ui' and ext='1'");
			mysql_query("delete from pending_del where owner_id='$ui'");
		}
 	}


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
		  $ui = get_user_id($sess->get('uid_l'),$xmpp_host);
		  $query="insert into jorge_logger (id_user,id_log_detail,id_log_level,log_time,extra) values ('$ui',1,1,NOW(),'$rem_adre')";
		  mysql_query($query) or die;

		// purge deletion table upon startup
		$result=mysql_query("select peer_name_id,date from pending_del where owner_id='$ui'");
		// prevent code execution if there is nothing to delete
		if (mysql_num_rows($result)>0) {
			while($row = mysql_fetch_array($result)) {
      				$talker = $row["peer_name_id"];
				$tslice = $row["date"];
				mysql_query("delete from `logdb_messages_$tslice"."_$xmpp_host` where owner_id='$ui' and peer_name_id='$talker' and ext = '1'");
  			}
			mysql_query("delete from jorge_mylinks where owner_id='$ui' and ext='1'");
			mysql_query("delete from pending_del where owner_id='$ui'");
		}

		// move to main
		  header("Location: main.php");
		  exit; // lets break script at this point...
		  }
		  	else {
				
				$sess->set('enabled','f');
				$sess->set('log_status',$ret_v[1]);
				$sess->set('image_w','');
				header("Location: not_enabled.php"); }

		}

	$error_m='<div style="background-color: #fad163; text-align: center; font-weight: bold; width: 300pt;">'.$wrong_data[$lang].'</div>';
	$ui_fail=get_user_id($inpLogin,$xmpp_host);
	$query = "select count(id_user) as log_number from jorge_logger where id_user = '$ui_fail' and log_time > date_sub(now(),interval 1 minute)";
	$result = mysql_query($query);
	$row=mysql_fetch_row($result);
	if ($row[0]>"3") { $log_level="3"; } else { $log_level="2";} // bump log_level if more then 3 log attempts in one minute
	$query="insert into jorge_logger (id_user,id_log_detail,id_log_level,log_time,extra) values ('$ui_fail',3,'$log_level',NOW(),'$rem_adre')";
	mysql_query($query) or die;

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
print '<br><div align="center" style="height: 110;"><br><a href="index.php"><img border="0" alt="Branding logo" src="img/'.$brand_logo.'"></a></div>'."\n";
print '<table class="ff" cellspacing="0" width="100%">'."\n";
print '<tr style="background-image: url(img/bell-bak.png); height: 24;">';
print '<td style="text-align: left; padding-left: 10px; color: white;">'.$welcome_1[$lang].'</td><td style="text-align: right;">';
print '<a class="mmenu" href="index.php?lng_sw='.$lang_o.'">'.$ch_lan2[$lang].$lang_sw[$lang].'</a></td>';
print '</tr></table>'."\n";
    echo '<center>'."\n";
    echo '<form action="index.php" method="post">'."\n";
    echo '<br><br><table class="ff" border="0" cellspacing="0" cellpadding="0">'."\n";
    echo '<tr><td align="right">'.$login_w[$lang].'&nbsp;</td><td><input name="inpLogin" value="'.$_POST[inpLogin].'" class="log" ></td><td>@'.$xmpp_host_dotted.'</td></tr>'."\n";
    echo '<tr height="3" ><td></td></tr>'."\n";
    echo '<tr><td align="right">'.$passwd_w[$lang].'&nbsp;</td><td><input name="inpPass" type="password" class="log"></td></tr>'."\n";
    echo '<tr height="10"><td></td></tr>'."\n";
	echo '<tr><td></td><td colspan="2"><img src="freecap.php" id="freecap" name="pic"></td></tr>'."\n";
	echo '<tr height="3" ><td></td></tr>'."\n";
	echo '<tr><td></td><td colspan="2" style="text-align: center;"><a href="#" onClick="new_freecap();return false;"><small>'.$cap_cant[$lang].'</small></a></td></tr>'."\n";
	echo '<tr height="3" ><td></td></tr>'."\n";
	echo '<tr><td align="right">'.$cap_w[$lang].'&nbsp;</td><td><input name="word" type="text" class="log" ></td>'."\n";
	echo '<tr height="15" ><td></td></tr>'."\n";
    echo '<tr><td colspan="2" align="right"><input class="red" type="submit" name="sublogin" value="'.$login_act[$lang].'"></td></tr>'."\n";
    echo '</table>'."\n";
    echo '</form>'."\n";
    print $error_m;
    echo '</center>'."\n";
include("footer.php");
?>
