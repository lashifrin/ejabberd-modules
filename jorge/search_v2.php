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

$search_phase=mysql_escape_string($_POST['query']); // for normal search

$next_link = $_GET['a']; // for pagination
$predefined = $_GET['b']; // for predefined

if ($predefined) { $search_phase = decode_predefined($predefined,$token,$url_key);  }  // for predefined

if ($next_link) { 
	$s_variables=decode_search_url($next_link,$token,$url_key);
	$tslice_next = validate_date($s_variables[tslice]);
	$search_phase = $s_variables[search_phase];
	$offset_arch = $s_variables[offset_arch];
	$offset_day = $s_variables[offset_day];
	$tag_count = $s_variables[tag_count];
	}

if ($tag_count=="t") { $start_from=$offset_day; }

$plain_phase=$search_phase; // fix me

// we dont want any % here...
if (preg_match("/%/i",$search_phase)) { $search_phase="";}

include ("upper.php");

// we need to rewrite this part internaly...
if (!$search_phase) { 

	print '<br><br><center><b>'.$search1[$lang].'</b></center><br><br><br><br>'; 
	
	} 
	else
	{

// check if we are using parametrized search or not
$qquery = is_query_from($search_phase);

// parametric search
if ($qquery[from] == "t") {

	$user_chat_search = "1"; // temp hack
	unset($search_phase);
	list($user_name, $server) = split("@", $qquery[talker]);
	$user_name=get_user_id(mysql_escape_string($user_name),$xmpp_host);
	$server=get_server_id(mysql_escape_string($server),$xmpp_host);
	$search_phase=$qquery[query];

}


if ($search_phase) {
// create table for sorting results. This is must as long as data in mod_logdb is splited into different tables:
// every day is different table, so we need fetch all matches and put it into temp table for future analisis...
mysql_query("create temporary table results_table ( 

	ts varchar(30),
	time_slice varchar(20),
	peer_name_id integer, 
	peer_server_id integer,
	direction integer,
	body text,
	score float

	) ") or die;

	$score="score";
}


//main table
print '<br>'."\n";
print '<h2>'.$search_res[$lang].'</h2>'."\n";
print '<table align="center" border="0" cellspacing="0" class="ff">'."\n";
print '<tr class="maint"><td>'.$time_t[$lang].'</td><td>'.$talks[$lang].'</td><td>'.$thread[$lang].'</td><td>'.$score.'</td></tr>'."\n";
print '<tr class="spacer"><td colspan="4"></td></tr>';
if ($offset_arch) { $type_p="6"; } else { $type_p="1"; }

$result=db_q($user_id,$server,$tslice_table,$talker,$search_p,$type_p,$offset_arch,$xmpp_host,$nn,$time2_start,$time2_end);

$arch_table=mysql_num_rows($result);
$external=0;
if ($result=="f") { header ("Location: search_v2.php");  }

$internal=$offset_day;

while ($entry = mysql_fetch_array($result)) {

	$external++;
	$time_slice = $entry["at"];
	// sub query

		if ($search_phase) {

		$type="4";

		}

		if ($user_chat_search) {

			if ($qquery['words']=="t") { $type="5"; } elseif($qquery['words'] == "f") { $type="7"; }

		}
		$a++;
		$search_result=db_q($user_id,$server,$time_slice,$user_name,$search_phase,$type,$start_from,$xmpp_host);
		if ($search_result=="f") { header ("Location: search_v2.php");  }
		
		$num_rows=mysql_num_rows($search_result);
		$day_mark=0;
		if ($num_rows!="0") {
			while ($results = mysql_fetch_array($search_result)) {


			// if there is no "from:" clausule perform normal search
			if ($type!="7") {
			
				$body_safe=base64_encode($results[body]); // ensure that we will preserve right message format...

				mysql_query("insert into results_table (ts,time_slice,peer_name_id,peer_server_id,direction,body,score) values (
					'$results[ts]',
					'$time_slice',
					'$results[peer_name_id]',
					'$results[peer_server_id]',
					'$results[direction]',
					'$body_safe',
					'$results[score]'
					)") or die("Internal Error");

			} else {
			
				
				$internal++;
				$day_mark++;

				// we like colors dont we?
				if ($results["direction"] == 0) { $col="e0e9f7"; } else { $col="e8eef7";  }

				$to_user = $results["peer_name_id"];
				$to_server=$results["peer_server_id"]; 
				
				// let's make a link
				$to_base = "$time_slice@$to_user@$to_server@";
				$to_base = encode_url($to_base,$user_id,$url_key);

				// time calc
				$pass_to_next = $results["ts"];
				$new_d = $results["ts"];
				$time_diff = abs((strtotime("$old_d") - strtotime(date("$new_d"))));
				$old_d = $pass_to_next;
				if ($time_diff>$split_line AND $day_mark>1 AND $type!="4") { 
					$in_minutes = round(($time_diff/60),0);
					print '<tr class="splitl">';
					print '<td colspan="5" style="font-size: 10px;">'.verbose_split_line($in_minutes,$lang,$verb_h,$in_min).'<hr size="1" noshade="" color="#cccccc"/></td></tr>';
					} // splitting line 900s = 15min.
				// end 

				// talker and server names
				$talk = get_user_name($results["peer_name_id"],$xmpp_host);
				$sname = get_server_name($results["peer_server_id"],$xmpp_host);

				// cleaning username
				$jid = htmlspecialchars($talk);

				
				print '<tr id="pretty" title="'.$jid.'@'.htmlspecialchars($sname).'" style="cursor: pointer;" bgcolor="'.$col.'" onclick="window.open(\'main.php?a='.$to_base.'\');" onMouseOver="this.bgColor=\'c3d9ff\';" onMouseOut="this.bgColor=\'#'.$col.'\';">'."\n";

				print '<td width="120">'.$results["ts"].'</td>'."\n";

				// username from user roster
				$talk = htmlspecialchars(query_nick_name($bazaj,$token,$talk,$sname)); // remove if there are performance issues

				// if there is no user in roster - advise that
				if ($talk=="f") { $talk=$not_in_r[$lang]; }

				// threaded view
					if ($results["direction"] == 1) 
					{ 
						$out=$talk;
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

						print '<td style="text-align: left;">&nbsp;'.$out.'&nbsp;&nbsp;</td>'."\n";

					}
						else 
						{
							print '<td style="text-align: right;"> -</td>'."\n";

						}


				// end threaded view

				// message body
				$body_message=wordwrap(str_replace("\n","<br>",htmlspecialchars($results["body"])),107,"<br>",true);
				print '<td width="700">'.$body_message.'</td>'."\n";

				// run pagination code only if search contains from: clausule
				/*
				The pagination code havent been changed after upgrade to search_engine_v2 - it work well so if one want to improve it
				f.e. by adding "back" button be my guest...
				*/
				$r=$r+1;
				#print "all: $r, num_r: $num_rows, internal: $internal <br>"; // debug 
				if ($r==$num_search_results) { 

					if ($num_rows>$internal) { 
						#print '-->more results in this day...'.$entry["at"].' offset:'.$internal.'<br>'; // debug
						$tag_count="t";
						}
					$next_r=$external+$offset_arch;
					#print "before cutdown: $next_r<br>"; // debug
					if ($tag_count=="t") { $next_r=$next_r-1; } // back to one day and continue with offset
					#print "after cutdown: $next_r<br>"; // debug
					#print "Internal: $internal, offset: $offset_day, is_tag: $s_variables[tag_count]<br>"; // debug
					if ($internal==$offset_day AND $s_variables[tag_count] == "t") 
						{ 
							$internal=$internal+$offset_day; 
							#print 'Increasing offset...<br>';  // debug
							
							} // if the same day - we increase offset

					if ($qquery[from] == "t") { $plain_phase=str_replace("@","//",$plain_phase);  } // hack
					$lnk_n="$entry[at]@$next_r@$internal@$plain_phase@$zz@$tag_count@";
					#print "Constructed link: $lnk_n <br>"; // debug
					print '<tr class="spacer"><td colspan="4"></td></tr>';
					print '<tr class="maint">';
					print '<td colspan="2" style="text-align: left;">';
					print '<a href="search_v2.php?a='.$lnk_p.'"></a></td>'; // fix me
					print '<td colspan="2" style="text-align: right;">';
					print '<a href="search_v2.php?a='.encode_url($lnk_n,$token,$url_key).'">'.$search_next[$lang].'</a></td></tr>';
					break 2;
					
					}

			

			} // end if ($type!="7") 


		} // end of day-loop

	}else 
	// if we haven't found anything increase counter by one...
	{
		$b++;
	}


	$start_from=""; // reset...
	$internal=0;
	$day_mark=1;
	if ($num_rows!=0 AND $type=="7") { 
		if ($arch_table == $external) {
			print '<tr height="6" class="spacerb"><td colspan="3" style="text-align: center;"><small>'.$no_more[$lang].'</small></td></tr>'."\n";
			}
			elseif($type=="7") {
		print '<tr height="6" class="spacer"><td colspan="3" style="text-align: center;"><small>'.$nx_dy[$lang].'</small></td></tr>'."\n"; 
		// initialize thread
		$aa="0";
		$tt="0";
		}
	}

} // end of main loop






// if normal search:
if ($type!="7") {

	$temp_query = "select * from results_table order by score desc limit 100";
	$result = mysql_query($temp_query);
	$num_results = mysql_num_rows($result);
	print '<tr class="maint"><td colspan="4" style="text-align: center; font-weight: normal;">'.$search_tip[$lang].' <b>'.$num_results.'</b>'.$search_why[$lang].'</td></tr>';
	print '<tr class="spacerb"><td colspan="5"></td></tr>';
	while ($dat = mysql_fetch_array($result)) {


	//building link:
	$to_base = "$dat[time_slice]@$dat[peer_name_id]@$dat[peer_server_id]@";
	$to_base = encode_url($to_base,$user_id,$url_key);

	// get the name of user that we was talking to
	$talk = get_user_name($dat["peer_name_id"],$xmpp_host);

	// get it's server name
	$sname = get_server_name($dat["peer_server_id"],$xmpp_host);

	// cleanup jid
	$jid = htmlspecialchars($talk);

	// color every second line...
	if ($col=="e0e9f7") { $col="e8eef7"; } else { $col="e0e9f7"; }

	// get username from user roster:
	$talk = htmlspecialchars(query_nick_name($bazaj,$token,$talk,$sname)); // remove if there are performance issues

	// if user is not in list, advise about that
	if ($talk=="f") { $talk=$not_in_r[$lang]; }

	// now we want to know who was talking to who...
	if ($dat["direction"] == 0) { $fr=$to_u[$lang]; } else { $fr=$from_u[$lang]; }

	// ... and what was talking, and format that ...
	$body_talk = wordwrap(str_replace("\n","<br>",htmlspecialchars(base64_decode($dat["body"]))),107,"<br>",true);

	// opening line
	print '<tr id="pretty" title="'.$jid.'@'.htmlspecialchars($sname).'" style="cursor: pointer;" bgcolor="'.$col.'" onclick="window.open(\'main.php?a='.$to_base.'\');" onMouseOver="this.bgColor=\'c3d9ff\';" onMouseOut="this.bgColor=\'#'.$col.'\';">'."\n";
	
	// time field:
	print '<td width="120">'.$dat["ts"].'</td>'."\n";
	// direction and talker
	print '<td style="text-align: left;">'.$fr.'&nbsp;&nbsp;'.cut_nick($talk).'&nbsp;&nbsp;</td>'."\n";
	// and content:
	print '<td width="700">'.$body_talk.'</td>'."\n";
	// score for info
	print '<td>'.round($dat[score],2).'</td>';

	// closing line
	print '</tr>';

	}

	print '<tr class="spacer" height="1px"><td colspan="5"></td></tr>'."\n";
	print '<tr class="maint"  height="15px"><td colspan="5"></td></tr>'."\n";
	mysql_free_result ($result);
	mysql_free_result ($results);
	mysql_close();

}


if($a==$b) { print '<tr><td colspan="4" style="text-align: center;"><b>'.$no_result[$lang].'</b></td></tr>'; }
print '</table>'."\n";


}


if ($search_phase!="") {

?>

<!-- 
<script type="text/javascript">
	highlightSearchTerms('<? print $search_phase; ?>', true);
</script>
-->

<?

}

include("footer.php");

?>
