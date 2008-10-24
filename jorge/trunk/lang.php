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

// WARNING: File encoding is UTF-8 and should remain in this encoding!

if (__FILE__==$_SERVER['SCRIPT_FILENAME']) {

	header("Location: index.php?act=logout");
	exit;

}

$vhost_select[pol] = "Wybierz serwer";
$vhost_select[eng] = "Select server";

$vhost_not_selected[pol] = "Nie wybrano żadnego serwera!";
$vhost_not_selected[eng] = "No server have been selected!";

$no_script[pol] = "Twoja przeglądarka ma wyłączoną obsługę JavaScript. Jorge wymaga aby obsługa Javascript-u była włączona!";
$no_script[eng] = "Your browser dont support Javascript. Jorge require to have Javascript enabled!";

$act_su[pol] = "Zapisywanie rozmów na serwerze zostało włączone!";
$act_su[eng] = "Message archiving activated succesfuly!";

$wrong_data[pol] = "Nieprawidłowa nazwa użytkownika lub hasło!";
$wrong_data[eng] = "Bad username or password!";

$wrong_data2[pol] = "Nieprawidłowe słowo z obrazka, spróbuj jeszcze raz";
$wrong_data2[eng] = "You have entered wrong word from picture, try again";

$act_su2[pol] = "Aby przeglądać archiwa musisz zalogować się ponownie do systemu";
$act_su2[eng] = "You must relogin to system";

$act_info[pol] = "Usługa archiwizowania rozmów nie została aktywowana dla użytkownika: ";
$act_info[eng] = "Message archiving is not activated for user: ";

$warning1[pol] = "System wykrył że nie posiadasz jeszcze profilu, który wymagany jest do pracy. Aktywuj swój profil teraz.<br>
			UWAGA: System jest w trakcie testów co oznacza że może nie działac w ogóle, działać wadliwie lub narazić Cię na utratę danych. Używasz go na własną odpowiedzialność!";
$warning1[eng] = "System discovered that you dont have profile yet, profile is required to work with Jorge. Create your profile now.<br>
			WARNING - We are still testing the system, that mean it may not work at all or work wrong or even lead to datalost. Use it at your own risk!";

$welcome_1[pol] = "Jorge - archiwa rozmów. Zaloguj się do systemu";
$welcome_1[eng] = "Welcome to Jorge - message archives. Please login";

$login_w[pol] = "Login";
$login_w[eng] = "Login";

$passwd_w[pol] = "Hasło";
$passwd_w[eng] = "Password";

$login_act[pol] = "Zaloguj";
$login_act[eng] = "Login";

$devel_info[pol] = "Wersja BETA";
$devel_info[eng] = "Development version";

$activate_m[pol] = "AKTYWUJ";
$activate_m[eng] = "Enable message archiving";

$ch_lan[pol] = "Zmień język na:";
$ch_lan[eng] = "Change language to:";

$ch_lan2[eng] = "Zmień język na ";
$ch_lan2[pol] = "Change language to ";

$lang_sw[pol] = "English";
$lang_sw[eng] = "Polski";

$lang_sw2[eng] = "Angielski";
$lang_sw2[pol] = "English";

$header_l[pol] = "Archiwa rozmów serwera";
$header_l[eng] = "Message archives of server";

$menu_item_browser[pol] = "Przeglądarka";
$menu_item_browser[eng] = "Browser";

$menu_item_map[pol] = "Mapa Rozmów";
$menu_item_map[eng] = "Chat Map";

$menu_item_fav[pol] = "Ulubione";
$menu_item_fav[eng] = "Favorites";

$menu_item_search[pol] = "Wyszukiwarka";
$menu_item_search[eng] = "Search";

$menu_item_links[pol] = "MyLinks";
$menu_item_links[eng] = "MyLinks";

$menu_item_panel[pol] = "Panel Sterowania";
$menu_item_panel[eng] = "Control Panel";

$menu_item_contacts[pol] = "Kontakty";
$menu_item_contacts[eng] = "Contacts";

$menu_item_logs[pol] = "Logi";
$menu_item_logs[eng] = "Logs";

$menu_item_trash[pol] = "Kosz";
$menu_item_trash[eng] = "Trash";

$filter_form[pol] = "Filtruj listę kontaktów<span style=\"vertical-align: super;\"><small> *</small></span>";
$filter_form[eng] = "Filter your contacts<span style=\"vertical-align: super;\"><small> *</small></span>";

$filter_form_tip[pol] = "Wpisz nazwę kontaktu";
$filter_form_tip[eng] = "Type contact name";

$filter_tip[pol] = "...a następnie wybierz z listy, lub przeszukaj listę ręcznie:";
$filter_tip[eng] = "...and next select it from list, or search contact list by hand:";

$ff_notice[pol] = "Ta opcja działa tylko w przeglądarce Firefox";
$ff_notice[eng] = "This function work only in Firefox browser";

$search_box[pol] = "Szukaj w archiwach";
$search_box[eng] = "Search in archives";

$search_tip[pol] = "Wyświetlam";
$search_tip[eng] = "Displaying";

$search_why[pol] = " wyników (<i>nie więcej niż 100</i>). <a href=\"help.php#22\" target=\"_blank\"><u>Dowiedz się dlaczego</u></a>";
$search_why[eng] = " search results (<i>not more then 100</i>). <a href=\"help.php#22\" target=\"_blank\"><u>Find out why</u></a>";

$search_warn[pol] = "Uwaga: Wyszukuje tylko w wybranym przedziale czasu";
$search_warn[eng] = "Warning: Showing results only from selected time range";

$all_for_u[pol] = "Pokaż wszystkie rozmowy używając: ";
$all_for_u[eng] = "Show all chats using: ";

$all_for_u_m[pol] = "strumienia";
$all_for_u_m[eng] = "stream";

$all_for_u_m_d[pol] = "Pokazuje rozmowę jako strumień wiadomości";
$all_for_u_m_d[eng] = "Show chat as chat stream";

$all_for_u_m2[pol] = "mapy";
$all_for_u_m2[eng] = "map";

$all_for_u_m2_d[pol] = "Pokazuje rozmowę jako mapę rozmów";
$all_for_u_m2_d[eng] = "Show chat as chat map";

$all_for_u_t[pol] = "Pokaż wszystkie rozmowy z tym użytkownikiem";
$all_for_u_t[eng] = "Show all chats from this user";

$arch_on[pol] = "Włącz archiwizacje";
$arch_on[eng] = "Turn on archivization";

$arch_off[pol] = "Wyłącz archiwizacje";
$arch_off[eng] = "Turn off archivization";

$log_out_b[pol] = "Wyloguj";
$log_out_b[eng] = "Logout";

$archives_t[pol] = "Przeglądarka archiwum";
$archives_t[eng] = "Archive browser";

$main_date[pol] = "Data:";
$main_date[eng] = "Date:";

$talks[pol] = "Lista rozmów:";
$talks[eng] = "Chat list:";

$thread[pol] = "Treść:";
$thread[eng] = "Content:";

$time_t[pol] = "Czas:";
$time_t[eng] = "Time:";

$user_t[pol] = "Użytkownik:";
$user_t[eng] = "User:";

$my_links_save[pol] = "MyLinks";
$my_links_save[eng] = "MyLinks";

$my_links_desc_m[pol] = "MyLinks - Twoje linki";
$my_links_desc_m[eng] = "MyLinks - Your links";

$my_links_desc_e[pol] = "Tutaj znajdziesz listę zapisanych fragmentów rozmów";
$my_links_desc_e[eng] = "Here you can find saved fragments of your chats";

$settings_desc[pol] = "Ustawienia archiwum";
$settings_desc[eng] = "Archive settings";

$settings_desc_detail[pol] = "Panel zawiera opcje pozwalające kontrolować archiwizacje rozmów oraz opcje dotyczące konta";
$settings_desc_detail[eng] = "The panel consist of options that let you control message archiving as well as options regarding your account";

$api_access_enable[pol] = "Włącz publiczne API dla tego konta";
$api_access_enable[eng] = "Enable API access for this account";

$api_access_disable[pol] = "Wyłącz publiczne API dla tego konta";
$api_access_disable[eng] = "Disable API access for this account";

$api_access_on[pol] = "API dla tego konta jest włączone";
$api_access_off[eng] = "API access is enabled for this account";

$api_access_learn[pol] = "Dowiedz się więcej na temat publicznego API";
$api_access_learn[eng] = "Learn more about public API";

$print_t[pol] = "drukuj";
$print_t[eng] = "print";

$del_t[pol] = "usuń";
$del_t[eng] = "delete";

$resource_only[pol] = "Pokaż rozmowę tylko z tym zasobem";
$resource_only[eng] = "Show chat only with this resource";

$resource_warn[pol] = "Pokazuję rozmowę z zasobem: ";
$resource_warn[eng] = "Showing chat only with resource: ";

$resource_discard[pol] = "Pokaż ";
$resource_discard[eng] = "Show ";

$resource_discard2[pol] = "całą rozmowę.";
$resource_discard2[eng] = "entire chat thread.";

$del_all_conf[pol] = "Czy napewno chcesz usunąć *CAŁE* swoje archiwum wiadomości?\\nUWAGA: Nie będzie możliwości przywrócenia archiwum!";
$del_all_conf[eng] = "You are about to delete all your message archives. Are you *really* sure?\\nWARNING: It would be impossible to recover your archives!";

$deleted_all[pol] = "Całe Twoje archiwum zostało usunięte";
$deleted_all[eng] = "All your message archive has been deleted";

$delete_nothing[pol] = "Twoje archiwum jest puste. Nic nie usunięto";
$delete_nothing[eng] = "Your message archive is empty. Nothing was deleted";

$delete_error[pol] = "Ooops...Wystąpiły błędy podczas wykonywania polecenia. Proszę spróbować poźniej";
$delete_error[eng] = "Ooops...There were errors during processing your request. Please try again later";

$search_w1[pol] = "Wyszukiwany ciąg nie może być krótszy niż 3 i dłuższy niż 70 znaków...";
$search_w1[eng] = "Search string cannot be shorter than 3 and longer than 70 characters...";

$search_res[pol] = "Wyniki wyszukiwania: ";
$search_res[eng] = "Search results: ";

$my_links_save_d[pol] = "Zapisuje link. Wprowadź dane";
$my_links_save_d[eng] = "Saving link. Fill the form below";

$my_links_optional[pol] = "Opis (opcjonalne, max 120 znakow)";
$my_links_optional[eng] = "Description (optional, max 120 characters)";

$my_links_chat[pol] = "Rozmowa z:";
$my_links_chat[eng] = "Chat with:";

$my_links_commit[pol] = "zapisz";
$my_links_commit[eng] = "save";

$my_links_cancel[pol] = "anuluj";
$my_links_cancel[eng] = "cancel";

$my_links_link[pol] = "Link z dnia:";
$my_links_link[eng] = "Link from day:";

$my_links_desc[pol] = "Opis:";
$my_links_desc[eng] = "Description:";

$my_links_added[pol] = "Link został zapisany!";
$my_links_added[eng] = "Link succesfuly added!";

$my_links_back[pol] = "Wróć do rozmowy";
$my_links_back[eng] = "Back to chat";

$my_links_removed[pol] = "Link został usunięty z bazy danych";
$my_links_removed[eng] = "Link succesfuly deleted";

$my_links_none[pol] = "Brak opisu";
$my_links_none[eng] = "No decsription";

$status_msg1[pol] = "Archiwizacja rozmów jest aktualnie wyłączona";
$status_msg1[eng] = "Message archiving is disabled by user";

$status_msg2[pol] = "Archiwizacja została włączona. (zmiany w profilu widoczne są po 10 sekundach)";
$status_msg2[eng] = "Message archiving have beed enabled. Changes may take 10s";

$status_msg3[pol] = "Archiwizacja została wyłączona. (zmiany w profilu widoczne są po 10 sekundach)";
$status_msg3[eng] = "Message archiving have beed disabled. Changes may take 10s";

$my_links_no_links[pol] = "Nie masz aktualnie zapisanych linków...";
$my_links_no_links[eng] = "You don't have any MyLinks saved...";

$quest1[pol] = "Znalazłeś błąd? Napisz!";
$quest1[eng] = "Found error? Write to us!";

$search1[pol] = "Szukaj...";
$search1[eng] = "Search...";

$no_result[pol] = "Brak rezultatów wyszukiwania";
$no_result[eng] = "No search results";

$settings_del[pol] = "Usuń całe archiwum";
$settings_del[eng] = "Delete entire archive";

$del_conf[pol] = "Czy na pewno usunąć tą rozmowę?";
$del_conf[eng] = "Do you really want to delete this chat?";

$del_conf_my_link[pol] = "Czy na pewno usunąć ten link?";
$del_conf_my_link[eng] = "Do you really want to remove that link?";

$not_in_r[pol] = "Kontakt specjalny";
$not_in_r[eng] = "Special contact";

$del_moved[pol] = "Rozmowa została przeniesiona do kosza.";
$del_moved[eng] = "Chat have been moved to trash.";

$del_info[pol] = "Rozmowa została usunięta";
$del_info[eng] = "Chat have been deleted";

$undo_info[pol] = "Rozmowa została przywrócona";
$undo_info[eng] = "Chat restored succesfuly";

$del_my_link[pol] = "usuń";
$del_my_link[eng] = "delete";

$help_but[pol] = "Pomoc";
$help_but[eng] = "Help";

$tip_delete[pol] = "Usuń historię rozmowy z tego dnia";
$tip_delete[eng] = "Delete chat from this day";

$tip_export[pol] = "Eksportuj rozmowę do pliku tekstowego";
$tip_export[eng] = "Export this chat into text file";

$customize1[pol] = "Dostosuj logowanie";
$customize1[eng] = "Customize logging";

$from_u[pol] = "Od: ";
$from_u[eng] = "From: ";

$to_u[pol] = "Do: ";
$to_u[eng] = "To: ";

$search_next[pol] = "Następne wyniki...";
$search_next[eng] = "Next results...";

$search_prev[pol] = "Poprzednie wyniki...";
$search_prev[eng] = "Previous results...";

$change_pass[pol] = "Zmień hasło";
$change_pass[eng] = "Change password";

$no_contacts[pol] = "Brak kontaktów na liście";
$no_contacts[eng] = "Your contacts list is currently empty";

$no_archives[pol] = "W tej chwili nie masz zapisanych żadnych rozmów";
$no_archives[eng] = "Currently you dont have any chats saved";

$con_tab1[pol] = "Lp.";
$con_tab1[eng] = "No.";

$con_tab2[pol] = "Nazwa kontaktu";
$con_tab2[eng] = "Contact name";

$con_tab3[pol] = "JabberID";
$con_tab3[eng] = "JabberID";

$con_tab4[pol] = "Włączyć archiwizacje";
$con_tab4[eng] = "Enable archiving";

$con_tab_act_y[pol] = "Tak";
$con_tab_act_y[eng] = "Yes";

$con_tab_act_n[pol] = "Nie";
$con_tab_act_n[eng] = "No";

$con_tab_submit[pol] = "Zapisz zmiany";
$con_tab_submit[eng] = "Save changes";

$con_tab6[pol] = "Grupa";
$con_tab6[eng] = "Group";

$con_no_g[pol] = "Brak grupy";
$con_no_g[eng] = "No group";

$map_no_g[pol] = "brak grupy";
$map_no_g[eng] = "no group";

$con_head[pol] = "Zarządzanie kontaktami";
$con_head[eng] = "Contacts managment";

$con_notice[pol] = "Uwaga: wyświetlane są tylko kontakty z przypisaną nazwą kontaktu.";
$con_notice[eng] = "Notice: displaying only contacts with assigned nicknames.";

$con_title[pol] = "Kliknij na kontakcie aby zobaczyć archiwum rozmów";
$con_title[eng] = "Click on contact name to see chat history";

$con_saved[pol] = "Zmiany zostały zapisane";
$con_saved[eng] = "Changes have beed saved";

$help_notice[pol] = "Główne zagadnienia";
$help_notice[eng] = "Main topics";

$nx_dy[pol] = "Kolejny dzień";
$nx_dy[eng] = "Next day";

$no_more[pol] = "Brak większej ilości wyników";
$no_more[eng] = "No more search results";

$in_min[pol] = "minut";
$in_min[eng] = "minutes";

$verb_h[pol] = "przerwa w rozmowie trwająca ponad godzinę";
$verb_h[eng] = "chat break more than one hour";

$time_range_w[pol] = "Pole \"Od\" nie może być większe od pola \"Do\"";
$time_range_w[eng] = "Field \"From\" cannot be greater than field \"To\"";

$time_range_from[pol] = "od";
$time_range_from[eng] = "from";

$time_range_to[pol] = "do";
$time_range_to[eng] = "to";

$export_link[pol] = "eksportuj";
$export_link[eng] = "export";

$export_head1[pol] = "Historia rozmowy między Tobą a ";
$export_head1[eng] = "Exported chat between you and ";

$export_head2[pol] = "przeprowadzona w dniu";
$export_head2[eng] = "performed on";


$help_search_tips[pol] = "
<br/><br/>
<li>Wyszukiwarka: Podpowiedzi.</li>
<ul>Przeszukując archiwa można zadawać kilka rodzajów zapytań na przykład:<br />
	żeby znaleźć wszystkie rozmowy z danym użytkownikiem wpisujemy w oknie wyszukiwania:<br />
	<b>from:jid@przykład.pl</b> - gdzie <i>jid</i> to nazwa użytkownika, a <i>przykład.pl</i> to serwer na którym wyszukiwana osoba ma konto.<br >
	aby wyszukać daną frazę w rozmowie z użytkownikiem możemy wykonać następujące zapytanie:<br />
	<b>from:jid@przykład.pl:co to jest jabber</b> - takie zapytanie przeszuka wszystkie rozmowy z użytkownikem <i>jid</i> z serwera <i>przykład.pl</i> w poszukiwaniu frazy: <i>co to jest jabber</i><br />
	Wyszukiwarka obsługuje oczywiście zwykłe wyszukiwanie - we wszystkich przeprowadzonych przez nas rozmowach:<br />
	<b>co to jest jabber</b> - wyszuka we wszystkich rozmowach frazy \"co to jest jabber\" jak również wyświetli wszystkie linie rozmowy zawierające słowa kluczowe<br />
	Jeśli nie znamy pełnej nazwy której poszukijemy możemy daną/dane litery zastąpić znakiem: * (gwiazdka) np.:<br />
	<b>jak*</b> - znajdzie wszystkie słowa zaczynające się na <i>jak</i> czyli np. <i>jaki, jaka</i>


</ul>

";

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

$help_my_links_note[pol] = "
<br/><br/>
<li>MyLinks: informacje ogólne.</li>
<ul>MyLinks służy do przechowywania(zapamiętywania) ulubionych fragmentów rozmów. Dzieki opcji MyLinks można w łatwy i szybki sposób odnaleźć poszukiwaną rozmowę.<br />
Aby dodać daną rozmowę do MyLinks należy kliknąć po prawej stronie okna z wyszukiwaną rozmową na opcji \"zapisz w mylinks\". Po wprowadzeniu opisu, link zostanie<br />
zapisany w zakładce MyLinks.
</ul>

";

$help_my_links_note[eng] = "
<br/><br/>
<li>MyLinks: overview.</li>
<ul>MyLinks let you store your favorited links. Thanks to MyLinks option you can easly and fast find your favorited talk.<br />
To add chat to MyLinks just click on the right side of the chat window onto option called \"save in mylinks\". Then fill the form with description and save link into database.
</ul>




";


$help_advanced_tips[pol] = "
<br/><br/>
<li>Jak szukać dokładnie?</li>
<ul>Wyszukiwarga <b>Jorge</b> obsługuje zaawansowane tryby wyszukiwania tzw. <i>Boolean mode</i>, co oznacza że znacznie można poprawić rezultaty wyszukiwania.<br/>
	Wyszukiwarka przeszukuje wszystkie Twoje archiwa w poszukiwaniu danej frazy, następnie ocenia tzw. <i>\"score\"</i>, sortuje dane i wyświetla najlepiej pasujące 100 wyników<br/>
	Aby ułatwić wyszukiwanie możesz użyć następujących modyfikatorów:<br>
	<b>+</b> - oznacza że dane słowo musi znaleźć się w wynikach wyszukiwania np. (+abc +def - odszuka wszystkie rozmowy zawierające w danej lini abc oraz def)<br>
	<b>-</b> - oznacza że dane słowo ma nie występować w wynikach wyszukiwania<br/>
	<b>></b> oraz <b><</b> - nadaje dodatkowe punkty wyszukiwanemu słowu w frazie. Np. poszukując linka wiemy że zawieta http i np. słowo planeta. Aby zwiększyć trafność wyników zapytanie powinno wyglądać tak: \"http &lt;planeta\"</br>
	<b>( )</b> - oznacza wykonanie pod-zapytania</br>
	<b>~</b> - dodaje negatywne punkty do danego słowa - ale go nie wyklucza z wyników</br>
	<b>*</b> - zastępuje ciąg znaków</br>
	<b>\"</b> - oznacza wyszukiwanie dokładnie pasującej frazy np: \"jak to\" znajdzie tylko rozmowy z dokładnie tą frazą

</ul>

";


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

$admin_site_gen[pol] = "Strona została wygenerowana w: ";
$admin_site_gen[eng] = "Site generated in:";

$logger_from_day[pol] = " z dnia: ";
$logger_from_day[eng] = " from day: ";

$logger_overview[pol] = "Logi aktywności w Jorge";
$logger_overview[eng] = "Activity logs on Jorge";

$logger_f1[pol] = "Zdarzenie:";
$logger_f1[eng] = "Event:";

$logger_f2[pol] = "Data zdarzenia:";
$logger_f2[eng] = "Event date:";

$logger_f3[pol] = "Poziom zdarzenia:";
$logger_f3[eng] = "Event level:";

$logger_f4[pol] = "Dodatkowe informacje:";
$logger_f4[eng] = "Additional info:";

$logger_f_ip[pol] = "z adresu IP: ";
$logger_f_ip[eng] = "from IP address: ";

$refresh[pol] = "Odśwież";
$refresh[eng] = "Refresh";

$back_t[pol] = "Wróć na góre strony";
$back_t[eng] = "Back to top of the page";

$trash_name[pol] = "Kosz";
$trash_name[eng] = "Trash";

$trash_desc[pol] = "Lista rozmów usuniętych. Wiadomości które przebywają w koszu dłużej niż 30 dni są automatycznie usuwane";
$trash_desc[eng] = "List of trashed chats. Chats that are left in trash are automaticly deleted after 30 days.";

$trash_undel[pol] = "Przywróć";
$trash_undel[eng] = "Restore";

$trash_vit[pol] = "Zobacz przywróconą rozmowę";
$trash_vit[eng] = "View restored chat";

$trash_del[pol] = "Usuń";
$trash_del[eng] = "Delete";

$trash_link[pol] = "Akcja";
$trash_link[eng] = "Action";

$trash_empty[pol] = "Kosz jest pusty";
$trash_empty[eng] = "Trash is empty";

$trash_recovered[pol] = "Rozmowa została przeniesiona do archiwum";
$trash_recovered[eng] = "Chat have been moved to archive";

$cal_head[pol] = "Kalendarz rozmów.";
$cal_head[eng] = "Chat calendar";

$cal_notice[pol] = "Kliknij na danym dniu aby zobaczyć rozmowy";
$cal_notice[eng] = "Click on days to see chats";

$change_view[pol] = "Zmień na widok drzewa";
$change_view[eng] = "Switch to tree view";

$change_view_cal[pol] = "Przeglądaj archiwum za pomocą widoku kalendarza.";
$change_view_cal[eng] = "Browse archives using calendar view.";

$months_name_pol = array("Styczeń","Luty","Marzec","Kwiecień","Maj","Czerwiec","Lipiec",
                             "Sierpień","Wrzesień","Październik","Listopad","Grudzień");

$months_name_eng = array("January","February","March","April","May","June","July",
                             "August","September","October","November","December");

$jump_to_l[pol] = "Przejdź do miesiąca";
$jump_to_l[eng] = "Jump to month";

$chat_list_l[pol] = "Lista rozmów:";
$chat_list_l[eng] = "Chat list:";

$select_view[pol] = "Wybierz rodzaj widoku przeglądarki:";
$select_view[eng] = "Select prefered view for browser:";

$view_calendar[pol] = "Widok kalendarza";
$view_calendar[eng] = "Calendar view";

$view_standard[pol] = "Widok drzewa";
$view_standard[eng] = "Tree view";

$setting_d1[pol] = "Zmień globalną opcję archiwizacji:";
$setting_d1[eng] = "Change global archivization policy:";

$setting_d2[pol] = "Usuń całe archiwum wiadomości (<i>nie można wycofać</i>):";
$setting_d2[eng] = "Delete entire message archive (<i>cannot undo</i>):";

$chat_map[pol] = "Mapa rozmów";
$chat_map[eng] = "Chat map";

$chat_select[pol] = "Wybierz kontakt aby zobaczyć listę rozmów";
$chat_select[eng] = "Select contact to see chats";

$chat_m_select[pol] = "Wybierz kontakt:";
$chat_m_select[eng] = "Pick a contact:";

$chat_c_list[pol] = "Lista kontaktów";
$chat_c_list[eng] = "Contacts list";

$chat_no_chats[pol] = "Brak rozmów z wybranym kontaktem";
$chat_no_chats[eng] = "There are no chats with selected contact";

$chat_map_back[pol] = "<<< Wróć do Mapy Rozmów";
$chat_map_back[eng] = "<<< Back to ChatMap";

$fav_back[pol] = "<<< Wróć do Ulubionych";
$fav_back[eng] = "<<< Back to Favorites";

$myl_back[pol] = "<<< Wróć do MyLinks";
$myl_back[eng] = "<<< Back to MyLinks";

$sel_language[pol] = "Wybierz preferowany język";
$sel_language[eng] = "Select prefered language";

$sel_client[pol] = "Uruchom Slimster";
$sel_client[eng] = "Launch Slimster";

$sel_yes[pol] = "Tak";
$sel_no[eng] = "Yes";

$sel_no[pol] = "Nie";
$sel_no[eng] = "No";

$jump_to_next[pol] = "Przejdź do następnego dnia rozmowy";
$jump_to_next[eng] = "Jump to next day of chat";

$jump_to_prev[pol] = "Przejdź do poprzedniego dnia rozmowy";
$jump_to_prev[eng] = "Jump to previous day of chat";

$show_chats[pol] = "Pokaż rozmowę jako";
$show_chats[eng] = "Show chat as";

$show_chat_stream[pol] = "strumień";
$show_chat_stream[eng] = "stream";

$show_chat_as_map[pol] = "mapę";
$show_chat_as_map[eng] = "map";

$tip_next_m[pol] = "Przejdź do następnego miesiąca";
$tip_next_m[eng] = "Go to next month";

$tip_prev_m[pol] = "Przejdź do poprzedniego miesiąca";
$tip_prev_m[eng] = "Go to previous month";

$cal_days[pol]['1'] = "Pon";
$cal_days[pol]['2'] = "Wto";
$cal_days[pol]['3'] = "Śro";
$cal_days[pol]['4'] = "Czw";
$cal_days[pol]['5'] = "Pią";
$cal_days[pol]['6'] = "Sob";
$cal_days[pol]['7'] = "Nie";

$cal_days[eng]['1'] = "Mon";
$cal_days[eng]['2'] = "Tue";
$cal_days[eng]['3'] = "Wed";
$cal_days[eng]['4'] = "Thu";
$cal_days[eng]['5'] = "Fri";
$cal_days[eng]['6'] = "Sat";
$cal_days[eng]['7'] = "Sun";

$chat_lines[pol] = "Ilość wiadomości: ";
$chat_lines[eng] = "Messages count: ";

$del_time[pol] = "Usunięto:";
$del_time[eng] = "Deleted:";

$marked_as_d[pol] = "Ta rozmowa znajduje się w koszu. Aby ją przeglądać musisz ją <a href=\"trash.php\"><u>przywrócić</u></a>";
$marked_as_d[eng] = "This chat is in trash. If you want to see it - <a href=\"trash.php\"><u>restore it</u></a>";

$stats_personal_d[pol] = "Statystyki rozmów";
$stats_personal_d[eng] = "Personal statistics";

$stats_personal[pol] = "Twoja całkowita liczba wiadomości w archiwum:";
$stats_personal[eng] = "Your total number of messages in archiwe:";

$stats_personal_top[pol] = "10 najdłuższych rozmów:";
$stats_personal_top[eng] = "Your top 10 chats:";

$stats_when[pol] = "Kiedy";
$stats_when[eng] = "When";

$stats_personal_count[pol] = "Liczba wiadomości";
$stats_personal_count[eng] = "Messages count";

$stats_peer[pol] = "Rozmówca";
$stats_peer[eng] = "Talker";

$stats_see[pol] = "Zobacz rozmowę";
$stats_see[eng] = "See this chat";

$fav_main[pol] = "Ulubione";
$fav_main[eng] = "Favorites";

$fav_desc[pol] = "Lista rozmów oznaczonych jako \"Ulubione\"";
$fav_desc[eng] = "List of chats marked as favorites";

$fav_add[pol] = "Dodaj tę rozmowę do ulubionych";
$fav_add[eng] = "Add this chat to favorites";

$fav_chat[pol] = "Rozmowa z: ";
$fav_chat[eng] = "Chat with: ";

$fav_success[pol] = "Rozmowa została dodana do Twoich <i>Ulubionych</i> !";
$fav_success[eng] = "This chat had been succesfully added to your <i>Favorites</i> !";

$fav_discard[pol] = "Ukryj tą informacje";
$fav_discard[eng] = "Discard this message";

$fav_exist[pol] = "Ooops...Ta rozmowa juz znajduje się w Twoich <i>Ulubionych</i>";
$fav_exist[eng] = "Ooops...This chat is already in your <i>Favorites</i>";

$fav_favorited[pol] = "Ta rozmowa jest dodana do ulubionych";
$fav_favorited[eng] = "This chat is added to favorites";

$fav_contact[pol] = "Rozmowa z:";
$faf_contact[eng] = "Chat with:";

$fav_when[pol] = "Kiedy:";
$fav_when[eng] = "When:";

$fav_comment[pol] = "Komentarz:";
$fav_comment[eng] = "Comment:";

$fav_nocomm[pol] = "Brak komentarza";
$fav_nocomm[eng] = "No comment";

$fav_add_comment[pol] = "Dodaj komentarz";
$fav_add_comment[eng] = "Add comment";

$fav_remove[pol] = "usuń";
$fav_remove[eng] = "delete";

$fav_removed[pol] = "Rozmowa została usnięta z <i>Ulubionych</i>";
$fav_removed[eng] = "Chat has been deleted from <i>Favorites</i>";

$fav_empty[pol] = "Nie masz aktualnie zapisanych żadnych <i>Ulubionych</i> rozmów";
$fav_empty[eng] = "You dont have any <i>Favorites</i> chats saved";

$fav_error[pol] = "Oooups...Wystąpił błąd podczas dodawania rozmowy";
$fav_error[eng] = "Oooups...There was a problem during processing your request";

$reset_sort[pol] = "resetuj sortowanie";
$reset_sort[eng] = "reset sorting";

$cont_chat[pol] = "rozmowa kontynuowana jest następnego dnia >>>";
$cont_chat[eng] = "chat continues on next day >>>";

$cont_chat_p[pol] = "<<< rozmowa jest kontynuacją z dnia poprzedniego";
$cont_chat_p[eng] = "<<< this chat is continuation from last day";

$close_account[pol] = "Usuń konto z serwera:";
$close_account[eng] = "Close your account:";

$close_info[pol] = "UWAGA: wraz z kontem XMPP zostanie usunięte konto z Google Apps!";
$close_info[eng] = "WARNING: during account removal also account on Google Apps will be removed!";

$close_warn[pol] = "Czy napewno usunąć konto i wszystkie wiadomości?";
$close_warn[eng] = "Do you really want to remove all messages and user account?";

$close_commit[pol] = "- Usuń teraz -";
$close_commit[eng] = "- Close now -";

$close_failed[pol] = "Usunięcie konta nie powiodło się. Proszę spróbować później";
$close_failed[eng] = "Close account failed. Please try again later";

$oper_fail[pol] = "<center><b>Operacja nie została wykonana! Proszę spróbować później lub skontaktować się z administratorem!</b></center>";
$oper_fail[eng] = "<center><b>Operation failed! Please try again later or contact administrator!</b></center>";

$go_to_jorge[pol] = "Idz do strony glownej";
$go_to_jorge[eng] = "Go to Jorge main page";

$qlink_l[pol] = "Szybki link: Przejdź do ostatnich rozmów";
$qlink_l[eng] = "Quick link: Go to latest chats";

$message_type_message[pol] = "Wiadomość";
$message_type_message[eng] = "Message";

$message_type_error[pol] = "Wiadomość została oznaczona jako zawierająca błąd i prawdopodobnie nie została dostarczona.";
$message_type_error[eng] = "Message have been marked as faulty, and probably was not delivered.";

$message_type_headline[pol] = "Headline";
$message_type_headline[eng] = "Headline";

?>
