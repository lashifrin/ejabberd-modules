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
$resource_id=mysql_escape_string($_GET['b']);

// validate resource_id
if (!ctype_digit($resource_id)) { unset($resource_id); }

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

include("upper.php");

// chat deletion
if ($action=="del") {

	if (!ctype_digit($talker) OR !ctype_digit($server)) { print 'Ooops...'; exit; }
	$query="delete from `logdb_messages_$tslice"."_$xmpp_host` where owner_id='$user_id' and peer_name_id='$talker' and peer_server_id='$server'";
	$result=mysql_query($query) or die ("Ooops...Error");
	$jid_date = ' '.get_user_name($talker,$xmpp_host).'@'.get_server_name($server,$xmpp_host).' ('.$tslice.')';
	$query="insert into jorge_logger (id_user,id_log_detail,id_log_level,log_time,extra) values ('$user_id',4,1,NOW(),'$jid_date')";
	mysql_query($query) or die;
	// how many chats is there left?
	$query="select count(peer_name_id) from `logdb_messages_$tslice"."_$xmpp_host` where owner_id='$user_id'";
	$result=mysql_query($query);
	$row=mysql_fetch_row($result);
	// if there is nothing left, lets cleanu up stats, we dont want to have mess in db
	if ($row[0]=="0") {
			$query="delete from `logdb_stats_$xmpp_host` where owner_id='$user_id' and at='$tslice' limit 1";
			$result=mysql_query($query) or die ("Ooops...Error");
			mysql_free_result($result);
			}
			else
			{
			// update stats if not delete
			$query="select count(body) from `logdb_messages_$tslice"."_$xmpp_host` where owner_id='$user_id'";
			$result=mysql_query($query) or die ("Ooops...Error1");
			$row=mysql_fetch_row($result);
			$new_stats=$row[0];
			mysql_free_result($result);
			$query="update `logdb_stats_$xmpp_host` set count='$new_stats' where owner_id='$user_id' and at='$tslice'";
			$result=mysql_query($query) or die ("Ooops...Error2");
			mysql_free_result($result);
			}
	// also if there were some saved links - we clean them up from mylins as well. We are so nice...
	$query="delete from jorge_mylinks where owner_id ='$user_id' and peer_name_id='$talker' and link like '$lnk%'";
	$result=mysql_query($query) or die ("Ooops...Error");
	mysql_free_result($result);
	unset($talker);
	print '<center><div style="background-color: #fad163; text-align: center; font-weight: bold; width: 200pt;">'.$del_info[$lang].'</div></center>';
}

// some validation things...
if ($start) { if ((validate_start($start))!="t") { $start="0";  }  }

$result=mysql_query("select substring(at,1,7) as at_m, at as verb from `logdb_stats_$xmpp_host` where owner_id='$user_id' group by at_m order by str_to_date(at,'%Y-%m-%d') desc");

if (mysql_num_rows($result) !=0) {

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

	while ($entry=mysql_fetch_array($result)) {

		$cl_entry = pl_znaczki(verbose_mo($entry[verb],$lang));
		if ($entry[at_m]==substr($tslice,0,7)) { $rel="open"; $bop="<b>"; $bcl="</b>"; } else { $rel=""; $bop=""; $bcl=""; } // ugly hack...
		print '<li>'.$bop.$cl_entry.$bcl.''."\n"; // folder - begin
  		print '<ul rel="'.$rel.'">'."\n"; // folder content
		$query="select at from `logdb_stats_$xmpp_host` where owner_id = '$user_id' and substring(at,1,7) = '$entry[at_m]' order by str_to_date(at,'%Y-%m-%d') desc";
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
		ddtreemenu.createTree("treemenu2", false, 1)
	</script>

	<?

	print '</td></tr></table>';

	}

	else 
	
	{

		print '<p align="center"><b>'.$no_archives[$lang].'</b></p>';


	}

// lets generate table name...
$tslice_table='logdb_messages_'.$tslice.'_'.$xmpp_host;

// Chats in selected days:
if ($tslice) {
	$result=db_q($user_id,$server,$tslice_table,$talker,$search_p,"2",$start,$xmpp_host);
	if ($result=="f") { header ("Location: main.php");  }
	print '<td valign="top" style="padding-top: 15px;">'."\n";
	print '<table class="ff">'."\n";
	while ($entry = mysql_fetch_array($result))
	{
		$user_name = $entry[username];
		$server_name = $entry[server_name];
		if ($talker==$entry["todaytalk"] AND $server==$entry[server]) { $bold_b="<b>"; $bold_e="</b>"; } else { $bold_b=""; $bold_e=""; }
			$nickname = query_nick_name($bazaj,$token,$user_name,$server_name);
			if ($nickname=="f") { $nickname=$not_in_r[$lang]; }
			$to_base2 = "$tslice@$entry[todaytalk]@$entry[server]@";
			$to_base2 = encode_url($to_base2,$token,$url_key);
			print '<tr>'."\n";
			print '<td><a id="pretty" href="?a='.$to_base2.'" title="JabberID:;'.htmlspecialchars($user_name).'@'.htmlspecialchars($server_name).'">'.$bold_b.cut_nick(htmlspecialchars($nickname)).$bold_e.'</a></td>'."\n";
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
	$result=db_q($user_id,$server,$tslice_table,$talker,$search_p,"3",$start,$xmpp_host,$num_lines_bro,$time_s="",$end_s="",$resource_id);
	if ($result=="f") { header ("Location: main.php");  }
	$talker_name = get_user_name($talker,$xmpp_host);
	$server_name = get_server_name($server,$xmpp_host);
	$nickname = query_nick_name($bazaj,$token,$talker_name,$server_name);
	if ($nickname=="f") { $nickname=$not_in_r[$lang]; }
	print '<table id="maincontent" border="0" cellspacing="0" class="ff">'."\n";
	if ($resource_id) {
	$res_display=get_resource_name($resource_id,$xmpp_host);
	print '<tr><td colspan="4"><div style="background-color: #fad163; text-align: center; font-weight: bold;">'.$resource_warn[$lang].cut_nick(htmlspecialchars($res_display)).'. ';
	print $resource_discard[$lang].'<a class="export" href="?a='.$e_string.'">'.$resource_discard2[$lang].'</a>';
	print '</div></td></tr>';
	}
	print '<tr class="maint">'."\n";
	print '<td><b> '.$time_t[$lang].' </b></td><td><b> '.$user_t[$lang].' </b></td><td><b> '.$thread[$lang].'</b></td>'."\n";
	$server_id=get_server_id($server_name,$xmpp_host);
	$loc_link = $e_string;
	$action_link = "$tslice@$talker@$server_id@0@null@$loc_link@del@";
	$action_link = encode_url($action_link,$token,$url_key);
	$predefined="from:$talker_name@$server_name";
	$predefined=encode_url($predefined,$token,$url_key);
	print '<td align="right" style="padding-right: 5px;">[ <a id="pretty" title="'.$tip_export[$lang].'" class="export" href="export.php?a='.$e_string.'">'.$export_link[$lang].'</a>&nbsp; | &nbsp;';
	print '<a id="pretty" title="'.$all_for_u_t[$lang].'" class="export" href="search_v2.php?b='.$predefined.'">'.$all_for_u[$lang].'</a>&nbsp; | &nbsp;';
	print '<a id="pretty" title="'.$tip_delete[$lang].'" class="delq" href="main.php?a='.$action_link.'" onClick="if (!confirm(\''.$del_conf[$lang].'\')) return false;">'.$del_t[$lang].'</a> ]</td></tr>';
	print '<tr class="spacer"><td colspan="5"></td></tr>';
	print '<tbody id="searchfield">'."\n";
	while ($entry = mysql_fetch_array($result))
		{

		$resource=get_resource_name($entry[peer_resource_id],$xmpp_host);
		$licz++;	
		if ($entry["direction"] == "to") { $col="main_row_a"; } else { $col="main_row_b"; }

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

		if ($entry["direction"] == "from") 
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
			
				print '<td style="padding-left: 5px; padding-right: 10px; nowrap="nowrap">'.cut_nick(htmlspecialchars($out));
				print '<a name="'.$licz.'"></a>';

				if ($out!=$token) {

				print '<br><div style="text-align: left; padding-left: 5px;"><a class="export" id="pretty" title="'.$resource_only[$lang].'" href="?a='.$e_string.'&b='.$entry[peer_resource_id].'">';
				print '<small><i>'.cut_nick(htmlspecialchars($resource)).'</i></small></a></div>';
					
				}
				
				print '</td>'."\n"; 
				
				$here="1"; 
			} 
			else 
			{ 
				print '<td style="text-align: right; padding-right: 5px">-</td>'."\n"; $here="0"; 
			}

		$new_s=htmlspecialchars($entry["body"]);
		$to_r = array("\n");
		$t_ro = array("<br>");
		$new_s=str_replace($to_r,$t_ro,$new_s);
		$new_s=wordwrap($new_s,107,"<br>",true);
		$new_s=new_parse_url($new_s);
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
		
	    if ($resource_id) { $add_res="&b=$resource_id"; } else { $add_res=""; }
            print '<a href="?a='.$e_string.$add_res.'&start='.$i.'"> <b>['.$i.']</b> </font></a>';
	    }
	    else { print ' -'.$i.'- '; }

    }
print '</td></tr>';
// limiting code - end

	if (($nume-$start)>40) { print '<tr><td colspan="5" style="text-align: right; padding-right: 5px;"><a href="#top"><small>'.$back_t[$lang].'</small></a></td></tr>'."\n"; }
	print '</table>'."\n";

	print '</tr></table></td>'."\n";
}

print '</td></tr>'."\n";
print '</table>'."\n";
include("footer.php");
?>
