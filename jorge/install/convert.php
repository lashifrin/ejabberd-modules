 <?php
 // converts InnoDB to MyISAM and add FullTEXT index to body field

 $link = mysql_connect("-db-host-","-db-username-","-password-");
 if(!$link){
   echo "Could not connect to database"; die();
 }
 mysql_select_db("ejabberd_logdb", $link);
 $result = mysql_query("show tables");
 $tablearr = array();
 while($row = mysql_fetch_row($result)){
   $tablearr[] = $row[0];
 }
 foreach($tablearr as $key => $table)
 {
   if (preg_match("/messages_/i",$table)) {

   print "Altering table: $table\n";
   mysql_query("alter table `$table` engine=myisam") or die ("1");
   mysql_query("alter table `$table` add fulltext(body)") or die ("2");
   mysql_query("analyze table `$table`") or die ("3");
   print "...ok\n";
   }
 }
 ?>
