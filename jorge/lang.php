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

// Language file: Site work in UTF-8 encoding. If you want to use your custom charset f.e. Kanja or Russian charset,
// modify function pl_znaczki() in func.php by adding right encoding conversion string to iconv. Default is Polish.

if (__FILE__==$_SERVER['SCRIPT_FILENAME']) {

	header("Location: index.php?act=logout");
	exit;

}

$no_script[pol] = pl_znaczki("Twoja przegl�darka ma wy��czon� obs�ug� JavaScript. Jorge wymaga aby obs�uga Javascript-u by�a w��czona!");
$no_script[eng] = "Your browser dont support Javascript. Jorge require to have Javascript enabled!";

$act_su[pol] = pl_znaczki("Zapisywanie rozm�w na serwerze zosta�o w��czone!");
$act_su[eng] = "Message archiving activated succesfuly!";

$wrong_data[pol] = pl_znaczki("Wprowadzono b��dne dane. Spr�buj jeszcze raz...");
$wrong_data[eng] = "Invalid data provided. Please try again...";

$act_su2[pol] = pl_znaczki("Aby przegl�da� archiwa musisz zalogowa� si� ponownie do systemu");
$act_su2[eng] = "You must relogin to system";

$act_info[pol] = pl_znaczki("Us�uga archiwizowania rozm�w nie zosta�a aktywowana dla u�ytkownika: ");
$act_info[eng] = "Message archiving is not activated for user: ";

$warning1[pol] = pl_znaczki("System jest w trakcie test�w co oznacza �e mo�e nie dzia�ac w og�le, dzia�a� wadliwie lub nawet narazi� Ci� na utrat� danych. Zastan�w si� zanim klikniesz \"aktywuj\"");
$warning1[eng] = "System is in stage \"alpha test\" - that mean it may not work at all or work wrong or even lead to datalost. Use it at your own risk!";

$warning2[pol] = pl_znaczki("UWAGA!");
$warning2[eng] = "WARNING";

$welcome_1[pol] = pl_znaczki("Jorge - archiwa rozm�w. Zaloguj si� do systemu");
$welcome_1[eng] = "Welcome to Jorge - message archives. Please login";

$login_w[pol] = pl_znaczki("Login");
$login_w[eng] = "Login";

$passwd_w[pol] = pl_znaczki("Has�o");
$passwd_w[eng] = "Password";

$cap_w[pol] = pl_znaczki("S�owo z obrazka:");
$cap_w[eng] = "Word from picture:";

$cap_cant[pol] = pl_znaczki("Nie mo�esz przeczyta� kliknij tutaj...");
$cap_cant[eng] = "Can't read? click here...";

$login_act[pol] = pl_znaczki("Zaloguj");
$login_act[eng] = "Login";

$devel_info[pol] = pl_znaczki("Wersja developerska");
$devel_info[eng] = "Development version";

$activate_m[pol] = pl_znaczki("AKTYWUJ");
$activate_m[eng] = "Enable message archiving";

$ch_lan[pol] = pl_znaczki("Zmie� j�zyk na:");
$ch_lan[eng] = "Change language to:";

$ch_lan2[eng] = pl_znaczki("Zmie� j�zyk na ");
$ch_lan2[pol] = "Change language to ";

$lang_sw[pol] = pl_znaczki("English");
$lang_sw[eng] = "Polski";

$lang_sw2[eng] = pl_znaczki("Angielski");
$lang_sw2[pol] = "English";

$header_l[pol] = pl_znaczki("Archiwa rozm�w serwera");
$header_l[eng] = "Message archives of server";

$menu_item1[pol] = pl_znaczki("Przegl�darka");
$menu_item1[eng] = "Browser";

$menu_item1a[pol] = pl_znaczki("MapaRozm�w");
$menu_item1a[eng] = "ChatMap";

$menu_item2[pol] = pl_znaczki("Wyszukiwarka");
$menu_item2[eng] = "Search";

$menu_item3[pol] = pl_znaczki("MyLinks");
$menu_item3[eng] = "MyLinks";

$menu_item4[pol] = pl_znaczki("Ustawienia");
$menu_item4[eng] = "Settings";

$menu_item5[pol] = pl_znaczki("Kontakty");
$menu_item5[eng] = "Contacts";

$menu_item6[pol] = pl_znaczki("Logi");
$menu_item6[eng] = "Logs";

$menu_item7[pol] = pl_znaczki("Kosz");
$menu_item7[eng] = "Trash";

$search_box[pol] = pl_znaczki("Szukaj w archiwach");
$search_box[eng] = "Search in archives";

$search_tip[pol] = pl_znaczki("Wy�wietlam");
$search_tip[eng] = "Displaying";

$search_why[pol] = pl_znaczki(" wynik�w (<i>nie wi�cej ni� 100</i>). <a href=\"help.php#22\" target=\"_blank\"><u>Dowiedz si� dlaczego</u></a>");
$search_why[eng] = " search results (<i>not more then 100</i>). <a href=\"help.php#22\" target=\"_blank\"><u>Find out why</u></a>";

$search_warn[pol] = pl_znaczki("Uwaga: Wyszukuje tylko w podanym przedziale czasu");
$search_warn[eng] = "Warning: Showing results only from selected time range";

$all_for_u[pol] = pl_znaczki("Poka� wszystkie rozmowy u�ywaj�c: ");
$all_for_u[eng] = "Show all chats using: ";

$all_for_u_m[pol] = pl_znaczki("strumienia");
$all_for_u_m[eng] = "stream";
$all_for_u_m_d[pol] = pl_znaczki("Pokazuje rozmow� jako strumie� wiadomo�ci");
$all_for_u_m_d[eng] = "Show chat as chat stream";

$all_for_u_m2[pol] = pl_znaczki("mapy");
$all_for_u_m2[eng] = "map";
$all_for_u_m2_d[pol] = pl_znaczki("Pokazuje rozmow� jako map� rozm�w");
$all_for_u_m2_d[eng] = "Show chat as chat map";

$all_for_u_t[pol] = pl_znaczki("Poka� wszystkie rozmowy z tym u�ytkownikiem");
$all_for_u_t[eng] = "Show all chats from this user";

$arch_on[pol] = pl_znaczki("W��cz archiwizacje");
$arch_on[eng] = "Turn on archivization";

$arch_off[pol] = pl_znaczki("Wy��cz archiwizacje");
$arch_off[eng] = "Turn off archivization";

$log_out_b[pol] = pl_znaczki("Wyloguj");
$log_out_b[eng] = "Logout";


$archives_t[pol] = pl_znaczki("Przegl�darka archiwum");
$archives_t[eng] = "Archive browser";

$main_date[pol] = pl_znaczki("Data:");
$main_date[eng] = "Date:";

$talks[pol] = pl_znaczki("Lista rozm�w:");
$talks[eng] = "Chat list:";

$thread[pol] = pl_znaczki("Tre��:");
$thread[eng] = "Content:";

$time_t[pol] = pl_znaczki("Czas:");
$time_t[eng] = "Time:";

$user_t[pol] = pl_znaczki("U�ytkownik:");
$user_t[eng] = "User:";

$my_links_save[pol] = pl_znaczki("MyLinks");
$my_links_save[eng] = "MyLinks";

$my_links_desc_m[pol] = pl_znaczki("Zapisane linki z archiwum");
$my_links_desc_m[eng] = "Saved links from archive";

$settings_desc[pol] = pl_znaczki("Ustawienia archiwum");
$settings_desc[eng] = "Archive settings";

$print_t[pol] = pl_znaczki("drukuj");
$print_t[eng] = "print";

$del_t[pol] = pl_znaczki("usu�");
$del_t[eng] = "delete";

$resource_only[pol] = pl_znaczki("Poka� rozmow� tylko z tym zasobem");
$resource_only[eng] = "Show chat only with this resource";

$resource_warn[pol] = pl_znaczki("Pokazuj� rozmow� z zasobem: ");
$resource_warn[eng] = "Showing chat only with resource: ";

$resource_discard[pol] = pl_znaczki("Poka� ");
$resource_discard[eng] = "Show ";

$resource_discard2[pol] = pl_znaczki("ca�� rozmow�.");
$resource_discard2[eng] = "entire chat thread.";

$del_all_conf[pol] = pl_znaczki("Czy napewno chcesz usun�� *CA�E* swoje archiwum wiadomo�ci?\\nUWAGA: Nie b�dzie mo�liwo�ci przywr�cenia archiwum!");
$del_all_conf[eng] = "You are about to delete all your message archives. Are you *really* sure?\\nWARNING: It would be impossible to recover your archives!";

$deleted_all[pol] = pl_znaczki("Ca�e Twoje archiwum zosta�o usuni�te");
$deleted_all[eng] = "All your message archive has been deleted";

$delete_nothing[pol] = pl_znaczki("Twoje archiwum jest puste. Nic nie usuni�to");
$delete_nothing[eng] = "Your message archive is empty. Nothing was deleted";

$search_w1[pol] = pl_znaczki("Wyszukiwany ci�g nie mo�e by� kr�tszy ni� 3 i d�u�szy ni� 70 znak�w...");
$search_w1[eng] = "Search string cannot be shorter than 3 and longer than 70 characters...";

$search_res[pol] = pl_znaczki("Wyniki wyszukiwania: ");
$search_res[eng] = "Search results: ";

$my_links_save_d[pol] = pl_znaczki("Zapisuje link. Wprowad� dane");
$my_links_save_d[eng] = "Saving link. Fill the form below";

$my_links_optional[pol] = pl_znaczki("Opis (opcjonalne, max 120 znakow)");
$my_links_optional[eng] = "Description (optional, max 120 characters)";

$my_links_chat[pol] = pl_znaczki("Rozmowa z:");
$my_links_chat[eng] = "Chat with:";

$my_links_commit[pol] = pl_znaczki("zapisz");
$my_links_commit[eng] = "save";

$my_links_cancel[pol] = pl_znaczki("anuluj");
$my_links_cancel[eng] = "cancel";

$my_links_link[pol] = pl_znaczki("Link z dnia:");
$my_links_link[eng] = "Link from day:";

$my_links_desc[pol] = pl_znaczki("Opis:");
$my_links_desc[eng] = "Description:";

$my_links_added[pol] = pl_znaczki("Link zosta� zapisany!");
$my_links_added[eng] = "Link succesfuly added!";

$my_links_back[pol] = pl_znaczki("Wr�� do rozmowy");
$my_links_back[eng] = "Back to chat";

$my_links_removed[pol] = pl_znaczki("Link zosta� usuni�ty z bazy danych");
$my_links_removed[eng] = "Link succesfuly deleted";

$my_links_none[pol] = pl_znaczki("Brak opisu");
$my_links_none[eng] = "No decsription";

$status_msg1[pol] = pl_znaczki("Archiwizacja rozm�w jest aktualnie wy��czona");
$status_msg1[eng] = "Message archiving is disabled by user";

$status_msg2[pol] = pl_znaczki("Archiwizacja zosta�a w��czona. (zmiany w profilu widoczne s� po 10 sekundach)");
$status_msg2[eng] = pl_znaczki("Message archiving have beed enabled. Changes may take 10s");

$status_msg3[pol] = pl_znaczki("Archiwizacja zosta�a wy��czona. (zmiany w profilu widoczne s� po 10 sekundach)");
$status_msg3[eng] = pl_znaczki("Message archiving have beed disabled. Changes may take 10s");

$my_links_no_links[pol] = pl_znaczki("Nie masz aktualnie zapisanych link�w...");
$my_links_no_links[eng] = "You don't have any MyLinks saved...";

$quest1[pol] = pl_znaczki("Znalaz�e� b��d? Napisz!");
$quest1[eng] = "Found error? Write to us!";

$search1[pol] = pl_znaczki("Szukaj...");
$search1[eng] = "Search...";

$no_result[pol] = pl_znaczki("Brak rezultat�w wyszukiwania");
$no_result[eng] = "No search results";

$settings_del[pol] = pl_znaczki("Usu� ca�e archiwum");
$settings_del[eng] = "Delete entire archive";

$del_conf[pol] = pl_znaczki("Czy na pewno usun�� t� rozmow�?");
$del_conf[eng] = "Do you really want to delete this chat?";

$del_conf_my_link[pol] = pl_znaczki("Czy na pewno usun�� ten link?");
$del_conf_my_link[eng] = "Do you really want to remove that link?";

$not_in_r[pol] = pl_znaczki("Poza list� kontakt�w");
$not_in_r[eng] = "Not in roster";

$del_moved[pol] = pl_znaczki("Rozmowa zosta�a przeniesiona do kosza.");
$del_moved[eng] = "Chat have been moved to trash.";

$del_info[pol] = pl_znaczki("Rozmowa zosta�a usuni�ta");
$del_info[eng] = "Chat have been deleted";

$undo_info[pol] = pl_znaczki("Rozmowa zosta�a przywr�cona");
$undo_info[eng] = "Chat restored succesfuly";

$del_my_link[pol] = pl_znaczki("usu�");
$del_my_link[eng] = "delete";

$help_but[pol] = pl_znaczki("Pomoc");
$help_but[eng] = "Help";

$tip_delete[pol] = pl_znaczki("Usu� histori� rozmowy z tego dnia");
$tip_delete[eng] = "Delete chat from this day";

$tip_export[pol] = pl_znaczki("Eksportuj rozmow� do pliku tekstowego");
$tip_export[eng] = "Export this chat into text file";

$customize1[pol] = pl_znaczki("Dostosuj logowanie");
$customize1[eng] = "Customize logging";

$from_u[pol] = pl_znaczki("Od: ");
$from_u[eng] = "From: ";

$to_u[pol] = pl_znaczki("Do: ");
$to_u[eng] = "To: ";

$search_next[pol] = pl_znaczki("Nast�pne wyniki...");
$search_next[eng] = "Next results...";

$search_prev[pol] = pl_znaczki("Poprzednie wyniki...");
$search_prev[eng] = "Previous results...";

$change_pass[pol] = pl_znaczki("Zmie� has�o");
$change_pass[eng] = "Change password";

$no_contacts[pol] = pl_znaczki("Brak kontakt�w na li�cie");
$no_contacts[eng] = "Your contacts list is currently empty";

$no_archives[pol] = pl_znaczki("W tej chwili nie masz zapisanych �adnych rozm�w");
$no_archives[eng] = "Currently you dont have any chats saved";

$con_tab1[pol] = pl_znaczki("Lp.");
$con_tab1[eng] = "No.";

$con_tab2[pol] = pl_znaczki("Nazwa kontaktu");
$con_tab2[eng] = "Contact name";

$con_tab3[pol] = pl_znaczki("JabberID");
$con_tab3[eng] = "JabberID";

$con_tab4[pol] = pl_znaczki("W��czy� archiwizacje");
$con_tab4[eng] = "Enable archiving";

$con_tab_act_y[pol] = pl_znaczki("Tak");
$con_tab_act_y[eng] = "Yes";

$con_tab_act_n[pol] = pl_znaczki("Nie");
$con_tab_act_n[eng] = "No";

$con_tab_submit[pol] = pl_znaczki("Zapisz zmiany");
$con_tab_submit[eng] = "Save changes";

$con_tab6[pol] = pl_znaczki("Grupa");
$con_tab6[eng] = "Group";

$con_no_g[pol] = pl_znaczki("Og�lne (brak grupy)");
$con_no_g[eng] = "General (no group)";

$map_no_g[pol] = pl_znaczki("brak grupy");
$map_no_g[eng] = "no group";

$con_head[pol] = pl_znaczki("Zarz�dzanie kontaktami");
$con_head[eng] = "Contacts managment";

$con_notice[pol] = pl_znaczki("Uwaga: wy�wietlane s� tylko kontakty z przypisan� nazw� kontaktu.");
$con_notice[eng] = "Notice: displaying only contacts with assigned nicknames.";

$con_title[pol] = pl_znaczki("Kliknij na kontakcie aby zobaczy� archiwum rozm�w");
$con_title[eng] = "Click on contact name to see chat history";

$con_saved[pol] = pl_znaczki("Zmiany zosta�y zapisane");
$con_saved[eng] = "Changes have beed saved";

$help_notice[pol] = pl_znaczki("G��wne zagadnienia");
$help_notice[eng] = "Main topics";

$nx_dy[pol] = pl_znaczki("Kolejny dzie�");
$nx_dy[eng] = "Next day";

$no_more[pol] = pl_znaczki("Brak wi�kszej ilo�ci wynik�w");
$no_more[eng] = "No more search results";

$in_min[pol] = pl_znaczki("minut");
$in_min[eng] = "minutes";

$verb_h[pol] = pl_znaczki("przerwa w rozmowie trwaj�ca ponad godzin�");
$verb_h[eng] = "chat break more than one hour";

$time_range_w[pol] = pl_znaczki("Pole \"Od\" nie mo�e by� wi�ksze od pola \"Do\"");
$time_range_w[eng] = "Field \"From\" cannot be greater than field \"To\"";

$time_range_from[pol] = pl_znaczki("od");
$time_range_from[eng] = "from";

$time_range_to[pol] = pl_znaczki("do");
$time_range_to[eng] = "to";

$export_link[pol] = pl_znaczki("eksportuj");
$export_link[eng] = "export";

$export_head1[pol] = pl_znaczki("Historia rozmowy mi�dzy Tob� a ");
$export_head1[eng] = "Exported chat between you and ";

$export_head2[pol] = pl_znaczki("przeprowadzona w dniu");
$export_head2[eng] = "performed on";


$help_search_tips[pol] = pl_znaczki("
<br/><br/>
<li>Wyszukiwarka: Podpowiedzi.</li>
<ul>Przeszukuj�c archiwa mo�na zadawa� kilka rodzaj�w zapyta� na przyk�ad:<br />
	�eby znale�� wszystkie rozmowy z danym u�ytkownikiem wpisujemy w oknie wyszukiwania:<br />
	<b>from:jid@przyk�ad.pl</b> - gdzie <i>jid</i> to nazwa u�ytkownika, a <i>przyk�ad.pl</i> to serwer na kt�rym wyszukiwana osoba ma konto.<br >
	aby wyszuka� dan� fraz� w rozmowie z u�ytkownikiem mo�emy wykona� nast�puj�ce zapytanie:<br />
	<b>from:jid@przyk�ad.pl:co to jest jabber</b> - takie zapytanie przeszuka wszystkie rozmowy z u�ytkownikem <i>jid</i> z serwera <i>przyk�ad.pl</i> w poszukiwaniu frazy: <i>co to jest jabber</i><br />
	Wyszukiwarka obs�uguje oczywi�cie zwyk�e wyszukiwanie - we wszystkich przeprowadzonych przez nas rozmowach:<br />
	<b>co to jest jabber</b> - wyszuka we wszystkich rozmowach frazy \"co to jest jabber\" jak r�wnie� wy�wietli wszystkie linie rozmowy zawieraj�ce s�owa kluczowe<br />
	Je�li nie znamy pe�nej nazwy kt�rej poszukijemy mo�emy dan�/dane litery zast�pi� znakiem: * (gwiazdka) np.:<br />
	<b>jak*</b> - znajdzie wszystkie s�owa zaczynaj�ce si� na <i>jak</i> czyli np. <i>jaki, jaka</i>


</ul>

");

$help_search_tips[eng] ="
<br/><br/>
<li>Search Tips</li>
<ul>When searching you can do some more complex queries like:<br />
	if you want to find all chats from particular user you can type:<br />
	<b>from:jid@example.com</b> - where <i>jid</i> is user name of the server: <i>example.com</i><br />
	or if you want to find phase in chats with that user, you can type:<br />
	<b>from:jid@example.com:what is jabber</b> - witch will query for phase <i>what is jabber</i> in all chats with user <i>jid@example.com</i><br />
	Search engine also of course supports normal search that search all archives:<br />
	<b>what is jabber</b> - will search in all our chats phase \"what is jabber\" as well as all keywords like: \"what\", \"is\", \"jabber\"<br />
	If we don't know full name that we are searching we can put instead character: * (wildcard):<br />
	<b>wor*</b> - will find all words that begin with wor* like: word, work, world...
</ul>
";

$help_my_links_note[pol] = pl_znaczki("
<br/><br/>
<li>MyLinks: informacje og�lne.</li>
<ul>MyLinks s�u�y do przechowywania(zapami�tywania) ulubionych fragment�w rozm�w. Dzieki opcji MyLinks mo�na w �atwy i szybki spos�b odnale�� poszukiwan� rozmow�.<br />
Aby doda� dan� rozmow� do MyLinks nale�y klikn�� po prawej stronie okna z wyszukiwan� rozmow� na opcji \"zapisz w mylinks\". Po wprowadzeniu opisu, link zostanie<br />
zapisany w zak�adce MyLinks.
</ul>

");

$help_my_links_note[eng] = "
<br/><br/>
<li>MyLinks: overview.</li>
<ul>MyLinks let you store your favorited links. Thanks to MyLinks option you can easly and fast find your favorited talk.<br />
To add chat to MyLinks just click on the right side of the chat window onto option called \"save in mylinks\". Then fill the form with description and save link into database.
</ul>




";


$help_advanced_tips[pol] = pl_znaczki("
<br/><br/>
<li>Jak szuka� dok�adnie?</li>
<ul>Wyszukiwarga <b>Jorge</b> obs�uguje zaawansowane tryby wyszukiwania tzw. <i>Boolean mode</i>, co oznacza �e znacznie mo�na poprawi� rezultaty wyszukiwania.<br/>
	Wyszukiwarka przeszukuje wszystkie Twoje archiwa w poszukiwaniu danej frazy, nast�pnie ocenia tzw. <i>\"score\"</i>, sortuje dane i wy�wietla najlepiej pasuj�ce 100 wynik�w<br/>
	Aby u�atwi� wyszukiwanie mo�esz u�y� nast�puj�cych modyfikator�w:<br>
	<b>+</b> - oznacza �e dane s�owo musi znale�� si� w wynikach wyszukiwania np. (+abc +def - odszuka wszystkie rozmowy zawieraj�ce w danej lini abc oraz def)<br>
	<b>-</b> - oznacza �e dane s�owo ma nie wyst�powa� w wynikach wyszukiwania<br/>
	<b>></b> oraz <b><</b> - nadaje dodatkowe punkty wyszukiwanemu s�owu w frazie. Np. poszukuj�c linka wiemy �e zawieta http i np. s�owo planeta. Aby zwi�kszy� trafno�� wynik�w zapytanie powinno wygl�da� tak: \"http &lt;planeta\"</br>
	<b>( )</b> - oznacza wykonanie pod-zapytania</br>
	<b>~</b> - dodaje negatywne punkty do danego s�owa - ale go nie wyklucza z wynik�w</br>
	<b>*</b> - zast�puje ci�g znak�w</br>
	<b>\"</b> - oznacza wyszukiwanie dok�adnie pasuj�cej frazy np: \"jak to\" znajdzie tylko rozmowy z dok�adnie t� fraz�

</ul>

");


$help_advanced_tips[eng] = "
<br/><br/>
<li>How to search right</li>
<ul>Search engine of <b>Jorge</b> supports advanced mode called <i>Boolean mode</i>, that means that you can improve your search results.</br>
	Search engine search all your archives next it sort it and evaluates score and then displays only 100 most relevant matches.<br/>
	To let you make it easy to adjust search results engine supports following arguments:<br/>
	<b>+</b> - means that particular word must be in the results, so: +abc +def means that both words must be there<br/>
	<b>-</b> - it excludes word from search results<br/>
	<b>></b> and <b><</b> - increasese or decreases score for particular word</br>
	<b>( )</b> - make it possible to execute sub-query</br>
	<b>~</b> - adds negative score to particular word</br>
	<b>*</b> - replaces unknown word</br>
	<b>\"</b> - perform exact match search</br>
</ul>


";

$admin_site_gen[pol] = pl_znaczki("Strona zosta�a wygenerowana w: ");
$admin_site_gen[eng] = "Site generated in:";

$logger_from_day[pol] = pl_znaczki(" z dnia: ");
$logger_from_day[eng] = " from day: ";

$logger_overview[pol] = pl_znaczki("Logi aktywno�ci w Jorge");
$logger_overview[eng] = "Activity logs on Jorge";

$logger_f1[pol] = pl_znaczki("Zdarzenie:");
$logger_f1[eng] = "Event:";

$logger_f2[pol] = pl_znaczki("Data zdarzenia:");
$logger_f2[eng] = "Event date:";

$logger_f3[pol] = pl_znaczki("Poziom zdarzenia:");
$logger_f3[eng] = "Event level:";

$logger_f4[pol] = pl_znaczki("Dodatkowe informacje:");
$logger_f4[eng] = "Additional info:";

$logger_f_ip[pol] = pl_znaczki("z adresu IP: ");
$logger_f_ip[eng] = "from IP address: ";

$refresh[pol] = pl_znaczki("Od�wie�");
$refresh[eng] = "Refresh";

$back_t[pol] = pl_znaczki("Wr�� na g�re strony");
$back_t[eng] = "Back to top of the page";

$trash_desc[pol] = pl_znaczki("Lista rozm�w usuni�tych. Wiadomo�ci kt�re przebywaj� w koszu d�u�ej ni� 30 dni s� automatycznie usuwane");
$trash_desc[eng] = "List of trashed chats. Chats that are left in trash are automaticly deleted after 30 days.";

$trash_undel[pol] = pl_znaczki("Przywr��");
$trash_undel[eng] = "Restore";

$trash_vit[pol] = pl_znaczki("Zobacz przywr�con� rozmow�");
$trash_vit[eng] = "View restored chat";

$trash_del[pol] = pl_znaczki("Usu�");
$trash_del[eng] = "Delete";

$trash_link[pol] = pl_znaczki("Akcja");
$trash_link[eng] = "Action";

$trash_empty[pol] = pl_znaczki("Kosz jest pusty");
$trash_empty[eng] = "Trash is empty";

$trash_recovered[pol] = pl_znaczki("Rozmowa zosta�a przeniesiona do archiwum");
$trash_recovered[eng] = "Chat have been moved to archive";

$cal_head[pol] = pl_znaczki("Kalendarz rozm�w.");
$cal_head[eng] = "Chat calendar";

$cal_notice[pol] = pl_znaczki("Kliknij na danym dniu aby zobaczy� rozmowy");
$cal_notice[eng] = "Click on days to see chats";

$change_view[pol] = pl_znaczki("Zmie� na widok drzewa");
$change_view[eng] = "Switch to tree view";

$change_view_cal[pol] = pl_znaczki("Przegl�daj archiwum za pomoc� widoku kalendarza.");
$change_view_cal[eng] = "Browse archives using calendar view.";

$months_name_pol = array("Stycze�","Luty","Marzec","Kwiecie�","Maj","Czerwiec","Lipiec",
                             "Sierpie�","Wrzesie�","Pa�dziernik","Listopad","Grudzie�");

$months_name_eng = array("January","February","March","April","May","June","July",
                             "August","September","October","November","December");

$jump_to_l[pol] = pl_znaczki("Przejd� do miesi�ca");
$jump_to_l[eng] = "Jump to month";

$chat_list_l[pol] = pl_znaczki("Lista rozm�w w wybranym dniu:");
$chat_list_l[eng] = "Chat list for selected day:";

$select_view[pol] = pl_znaczki("Wybierz rodzaj widoku przegl�darki:");
$select_view[eng] = "Select prefered view for browser:";

$view_calendar[pol] = pl_znaczki("Widok kalendarza");
$view_calendar[eng] = "Calendar view";

$view_standard[pol] = pl_znaczki("Widok drzewa");
$view_standard[eng] = "Tree view";

$setting_d1[pol] = pl_znaczki("Zmie� globaln� opcj� archiwizacji:");
$setting_d1[eng] = "Change global archivization policy:";

$setting_d2[pol] = pl_znaczki("Usu� ca�e archiwum wiadomo�ci (<i>nie mo�na wycofa�</i>):");
$setting_d2[eng] = "Delete entire message archive (<i>cannot undo</i>):";

$chat_map[pol] = pl_znaczki("Mapa rozm�w");
$chat_map[eng] = "Chat map";

$chat_select[pol] = pl_znaczki("Wybierz kontakt aby zobaczy� list� rozm�w");
$chat_select[eng] = "Select contact to see chats";

$chat_m_select[pol] = pl_znaczki("Wybierz kontakt:");
$chat_m_select[eng] = "Pick a contact:";

$chat_c_list[pol] = pl_znaczki("Lista kontakt�w");
$chat_c_list[eng] = "Contacts list";

$chat_no_chats[pol] = pl_znaczki("Brak rozm�w z wybranym kontaktem");
$chat_no_chats[eng] = "There are no chats with selected contact";

$chat_map_back[pol] = pl_znaczki("<<< Wr�� do MapyRozm�w");
$chat_map_back[eng] = "<<< Back to ChatMap";

$sel_language[pol] = pl_znaczki("Wybierz preferowany j�zyk");
$sel_language[eng] = "Select prefered language";

$sel_client[pol] = pl_znaczki("Uruchom Slimster");
$sel_client[eng] = "Launch Slimster";

$sel_yes[pol] = pl_znaczki("Tak");
$sel_no[eng] = "Yes";

$sel_no[pol] = pl_znaczki("Nie");
$sel_no[eng] = "No";

$jump_to_next[pol] = pl_znaczki("Przejd� do nast�pnego dnia rozmowy");
$jump_to_next[eng] = "Jump to next day of chat";

$jump_to_prev[pol] = pl_znaczki("Przejd� do poprzedniego dnia rozmowy");
$jump_to_prev[eng] = "Jump to previous day of chat";

$show_chats[pol] = pl_znaczki("Poka� rozmow� jako");
$show_chats[eng] = "Show chat as";

$show_chat_stream[pol] = pl_znaczki("strumie�");
$show_chat_stream[eng] = "stream";

$show_chat_as_map[pol] = pl_znaczki("map�");
$show_chat_as_map[eng] = "map";

$labels_add[pol] = pl_znaczki("Dodaj etykiete");
$labels_add[eng] = "Add label";

$labels_menu[pol] = pl_znaczki("Etykiety");
$labels_menu[eng] = "Labels";

$labels_desc[pol] = pl_znaczki("Twoje rozmowy z etykiet�:");
$labels_desc[eng] = "Your labeled chats:";

$tip_next_m[pol] = pl_znaczki("Przejd� do nast�pnego miesi�ca");
$tip_next_m[eng] = "Go to next month";

$tip_prev_m[pol] = pl_znaczki("Przejd� do poprzedniego miesi�ca");
$tip_prev_m[eng] = "Go to previous month";

// do not convert this via pl_znaczki() as calendar function is filtered via it in later progress
$cal_days[pol]['1'] = "Pon";
$cal_days[pol]['2'] = "Wto";
$cal_days[pol]['3'] = "�ro";
$cal_days[pol]['4'] = "Czw";
$cal_days[pol]['5'] = "Pi�";
$cal_days[pol]['6'] = "Sob";
$cal_days[pol]['7'] = "Nie";

$cal_days[eng]['1'] = "Mon";
$cal_days[eng]['2'] = "Tue";
$cal_days[eng]['3'] = "Wed";
$cal_days[eng]['4'] = "Thu";
$cal_days[eng]['5'] = "Fri";
$cal_days[eng]['6'] = "Sat";
$cal_days[eng]['7'] = "Sun";

$chat_lines[pol] = pl_znaczki("Ilo�� wiadomo�ci: ");
$chat_lines[eng] = "Messages count: ";



?>
