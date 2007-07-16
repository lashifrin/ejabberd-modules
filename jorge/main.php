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

// clear capch image
$sess->set('image_w','');

// fetch some date from encoded url...
$e_string=mysql_escape_string($_GET['a']);
$start=$_GET['start'];

// decompose link
if ($e_string) {
$variables = decode_url2($e_string,$token,$url_key);
$tslice = $variables[tslice];
$talker = $variables[talker];
$server = $variables[server];
$action = $variables[action];
$lnk = $variables[lnk];
}

// validation
$talker=mysql_escape_string($talker);
$server=mysql_escape_string($server);
if (validate_date($tslice) == "f") { unset ($tslice); unset($e_string); unset($talker); }


// chat deletion
if ($action=="del") {

	if (!ctype_digit($talker)) { print 'Ooops...(1)'; exit; }
	if (!ctype_digit($server)) { print 'Ooops...(2)'; exit; }

	$query="delete from `messages_$xmpp_host"."_$tslice` where owner_id='$user_id' and peer_name_id='$talker' and peer_server_id='$server'";
	$result=mysql_query($query) or die ("Ooops...Error");
	// how many chats is there left?
	$query="select count(peer_name_id) from `messages_$xmpp_host"."_$tslice` where owner_id='$user_id'";
	$result=mysql_query($query);
	$row=mysql_fetch_row($result);
	// if there is nothing left, lets cleanu up stats, we dont want to have mess in db
	if ($row[0]=="0") {
			$query="delete from `messages-stats_$xmpp_host` where owner_id='$user_id' and at='$tslice' limit 1";
			$result=mysql_query($query) or die ("Ooops...Error");
			mysql_free_result($result);
			}
			else
			{
			// update stats if not delete
			$query="select count(body) from `messages_$xmpp_host"."_$tslice` where owner_id='$user_id'";
			$result=mysql_query($query) or die ("Ooops...Error1");
			$row=mysql_fetch_row($result);
			$new_stats=$row[0];
			mysql_free_result($result);
			$query="update `messages-stats_$xmpp_host` set count='$new_stats' where owner_id='$user_id' and at='$tslice'";
			$result=mysql_query($query) or die ("Ooops...Error2");
			mysql_free_result($result);
			}
	// also if there were some saved links - we clean them up from mylins as well. We are so nice...
	$query="delete from mylinks where owner_id ='$user_id' and peer_name_id='$talker' and link like '$lnk%'";
	$result=mysql_query($query) or die ("Ooops...Error");
	mysql_free_result($result);
	unset($talker);
	print '<center><p style="background-color: yellow; text-align: center; font-weight: bold;">'.$del_info[$lang].'</p></center>';
}

include("upper.php");

// some validation things...
if ($start) { if ((validate_start($start))!="t") { $start="0";  }  }


// main table
print '<table class="ff" border="0">'."\n";
print '<tr class="main_s"><td colspan="1" style="text-align:left;">'.$archives_t[$lang].'</td>';
if ($tslice) { print '<td>'.$talks[$lang].'</td>';}
if ($talker) { print '<td>'.$thread[$lang].'</td>';}

print '<tr>'."\n";

// list of available chats (general)
print '<td valign="top"><table border="0" class="ff">'."\n";
print '<tr>'."\n";
print '<td rowspan="3" valign="top">'."\n";
print '<ul id="treemenu2" class="treeview" style="padding: 0px;">'."\n";

$result=mysql_query("select substring(at,1,7) as at, at as verb from `messages-stats_$xmpp_host` where owner_id='$user_id' group by at order by at desc");

while ($entry=mysql_fetch_array($result)) {

	$cl_entry = pl_znaczki(verbose_mo($entry[verb],$lang));

if ($entry[at]==substr($tslice,0,7)) { $rel="open"; $bop="<b>"; $bcl="</b>"; } else { $rel=""; $bop=""; $bcl=""; } // ugly hack...

print '<li>'.$bop.$cl_entry.$bcl.''."\n"; // folder - begin

  print '<ul rel="'.$rel.'">'."\n"; // folder content
	
	$query="select at from `messages-stats_$xmpp_host` where owner_id = '$user_id' and substring(at,1,7) = '$entry[at]' order by str_to_date(at,'%Y-%m-%d') desc";
	$result2=mysql_query($query);
	while ($ent=mysql_fetch_array($result2)) {

		$to_base = "$ent[at]@";
		$to_base = encode_url($to_base,$token,$url_key);
		$st=get_stats($user_id,$ent["at"],$xmpp_host);
		if ($tslice==$ent["at"]) { $bold_b = "<b>"; $bold_e="</b>"; } else { $bold_b=""; $bold_e=""; }
		print '<li><a href="?a='.$to_base.'">'.$bold_b.pl_znaczki(verbose_date($ent["at"],$lang,"m")).$bold_e.' - <small>'.$st.'</small></a></li>'."\n"; // days..

	}

  print '</ul>'."\n"; // end folder content

print '</li>'."\n"; // folder - end


} // end - arch


?>

</ul>

<script type="text/javascript">
ddtreemenu.createTree("treemenu2", true, 1)
</script>

<?

print '</td></tr></table>';

// lets generate table name...
$tslice_table='messages_'.$xmpp_host.'_'.$tslice;

// Chats in selected days:
if ($tslice) {
	$result=db_q($user_id,$server,$tslice_table,$talker,$search_p,"2");
	if ($result=="f") { header ("Location: main.php");  }
	print '<td valign="top">'."\n";
	print '<table class="ff">'."\n";
	while ($entry = mysql_fetch_array($result))
	{
		$user_name = get_user_name($entry["todaytalk"],$xmpp_host);
		$server_name = get_server_name($entry[server],$xmpp_host);
		if ($talker==$entry["todaytalk"] AND $server==$entry[server]) { $bold_b="<b>"; $bold_e="</b>"; } else { $bold_b=""; $bold_e=""; }
			$nickname = query_nick_name($bazaj,$token,$user_name,$server_name);
			if ($nickname=="f") { $nickname=$not_in_r[$lang]; }
			$to_base2 = "$tslice@$entry[todaytalk]@$entry[server]@";
			$to_base2 = encode_url($to_base2,$token,$url_key);
			print '<tr>'."\n";
			print '<td><a id="pretty" href="?a='.$to_base2.'" title="JabberID:;'.htmlspecialchars($user_name).'@'.htmlspecialchars($server_name).'">'.$bold_b.htmlspecialchars($nickname).$bold_e.'</a></td>'."\n";
			print '</tr>'."\n";
	}
	print '</table>'."\n";
	print '</td>'."\n";

mysql_free_result ($result);
}

// Chat thread:
if ($talker) {

	print '<td valign="top"><table border="0" class="ff"><tr>'."\n"; 
	if (!$start) { $start="0"; } // are we in the first page?
	$nume=get_num_lines($tslice_table,$user_id,$talker,$server); // number of chat lines
	if ($start>$nume) { $start=$nume-$num_lines_bro; } // checking start variable
	$result=db_q($user_id,$server,$tslice_table,$talker,$search_p,"3",$start,$xmpp_host,$num_lines_bro);
	if ($result=="f") { header ("Location: main.php");  }
	$talker_name = get_user_name($talker,$xmpp_host);
	$server_name = get_server_name($server,$xmpp_host);
	$nickname = query_nick_name($bazaj,$token,$talker_name,$server_name);
	// dynamicly calculate row size depending on users name
	$nick_size=strlen($nickname);
	$token_size=strlen($token);
	if ($nick_size>$token_size)
		{
		if ($nick_size>30) {
				$row_size="30";
				}
				else{
				$row_size=$nick_size;
				}
		}
		elseif($nick_size<$token_size)
		{
		if ($token_size>30) {
				$row_size="30";
				}
				else {
				$row_size=$token_size;
				}
		}

	if ($nickname=="f") { $nickname=$not_in_r[$lang]; }
	print '<table id="maincontent" border="0" cellspacing="0" class="ff">'."\n";
	print '<tr class="maint">'."\n";
	print '<td><b> '.$time_t[$lang].' </b></td><td><b> '.$user_t[$lang].' </b></td><td><b> '.$thread[$lang].'</b></td>'."\n";
	$server_id=get_server_id($server_name,$xmpp_host);
	$loc_link = $e_string;
	$action_link = "$tslice@$talker@$server_id@0@null@$loc_link@del@";
	$action_link = encode_url($action_link,$token,$url_key);
	print '<td align="right">['.$print_t[$lang].'&nbsp;|&nbsp;'.$export_t[$lang].'&nbsp;|&nbsp;<a class="delq" href="main.php?a='.$action_link.'" onClick="if (!confirm(\''.$del_conf[$lang].'\')) return false;">'.$del_t[$lang].'</a>]</td></tr>'."\n";
	print '<tr class="spacer"><td colspan="4"></td></tr>';
	print '<tbody id="searchfield">'."\n";
	while ($entry = mysql_fetch_array($result))
		{

		$licz++;	
		if ($entry["direction"] == 0) { $col="main_row_a"; } else { $col="main_row_b"; }

		$ts=strstr($entry["ts"], ' ');
		// time calc
		$pass_to_next = $entry["ts"];
		$new_d = $entry["ts"];
		$time_diff = abs((strtotime("$old_d") - strtotime(date("$new_d"))));
		$old_d = $pass_to_next;
		// end time calc
		if ($time_diff>$split_line AND $licz>1) { 
				$in_minutes = round(($time_diff/60),0);
				print '<tr class="splitl">';
				print '<td colspan="5" style="font-size: 10px;"><i>'.verbose_split_line($in_minutes,$lang,$verb_h,$in_min).'</i><hr size="1" noshade="" color="#cccccc"/></td></tr>';

			} // splitting line - defaults to 900s = 15min

		print '<tr class="'.$col.'">'."\n";
		print '<td class="time_chat" style="padding-left: 10px; padding-right: 10px;";>'.$ts.'</td>'."\n";

		if ($entry["direction"] == 1) 
			{ 
				$out=$nickname;
				$tt=$tt+1;
				$aa=0;
			} 
			else 
			{ 
				$out = $token;
				$aa=$aa+1;
				$tt=0;
			}



		if ($aa<2 AND $tt<2) { 
		print '<td width="'.$row_size.'" style="padding-left: 5px; padding-right: 10px;"><pre>'.htmlspecialchars($out).'</pre><a name="'.$licz.'"></a></td>'."\n"; $here="1"; } else { print '<td style="text-align: right; padding-right: 5px">-</td>'."\n"; $here="0"; }

		$new_s=htmlspecialchars($entry["body"]);
		$to_r = array("\n");
		$t_ro = array("<br>");
		$new_s=str_replace($to_r,$t_ro,$new_s);
		#$new_s=parse_urls($new_s); // temp disabled
		$new_s=wordwrap($new_s,107,"<br>",true);
		print '<td width="800" colspan="2">'.$new_s.'</td>'."\n";
		$lnk=encode_url("$tslice@$entry[peer_name_id]@$entry[peer_server_id]@",$ee,$url_key);
		$to_base2 = "$tslice@$entry[peer_name_id]@$entry[peer_server_id]@1@$licz@$lnk@NULL@$start@";
		$to_base2 = encode_url($to_base2,$token,$url_key);
		if ($here=="1") { print '<td colspan="2" style="padding-left: 2px; font-size: 9px;"><a href="my_links.php?a='.$to_base2.'">'.$my_links_save[$lang].'</a></td>'."\n"; } else { print '<td></td>'."\n"; }
		if ($t=2) { $c=1; $t=0; }
		print '</tr>'."\n";
		}
	print '</tbody>'."\n";


// limiting code
print '<tr class="spacer" height="1px"><td colspan="5"></td></tr>';
print '<tr class="maint"><td style="text-align: center;" colspan="9">';
for($i=0;$i < $nume;$i=$i+$num_lines_bro){

	if ($i!=$start) {
            print '<a href="?a='.$e_string.'&start='.$i.'"> <b>['.$i.']</b> </font></a>';
	    }
	    else { print ' -'.$i.'- '; }

    }
print '</td></tr>';
// limiting code - end

	print '</table>'."\n";

	print '</tr></table></td>'."\n";
}
print '</td></tr>'."\n";
print '</table>'."\n";
include("footer.php");
?>
