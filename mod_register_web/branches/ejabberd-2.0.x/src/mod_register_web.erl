%%%-------------------------------------------------------------------
%%% File    : mod_register_web.erl
%%% Author  : Badlop <badlop@process-one.net>
%%% Purpose : Web pages to register account and related tasks
%%% Created :  4 May 2008 by Badlop <badlop@process-one.net>
%%%-------------------------------------------------------------------

-module(mod_register_web).
-author('badlop@process-one.net').

-behaviour(gen_mod).

-export([
	 start/2,
	 stop/1,
	 process/2
	]).

-include("ejabberd.hrl").
-include("jlib.hrl").
-include("web/ejabberd_http.hrl").
-include("web/ejabberd_web_admin.hrl").

%% TODO: Check that all the text is translatable.
%% TODO: Check EDoc syntax is correct.


%%%----------------------------------------------------------------------
%%% gen_mod callbacks
%%%----------------------------------------------------------------------

%% TODO: Improve this module to allow each virtual host to have different
%% options. See http://support.process-one.net/browse/EJAB-561
start(_Host, _Opts) ->
    %% case gen_mod:get_opt(docroot, Opts, undefined) of
    ok.

stop(_Host) ->
    ok.


%%%----------------------------------------------------------------------
%%% HTTP handlers
%%%----------------------------------------------------------------------

process([], #request{method = 'GET', lang = Lang}) ->
    index_page(Lang);

process(["register.css"], #request{method = 'GET'}) ->
    serve_css();

process(["new"], #request{method = 'GET', lang = Lang}) ->
    form_new_get(Lang);

process(["delete"], #request{method = 'GET', lang = Lang}) ->
    form_del_get(Lang);

process(["change_password"], #request{method = 'GET', lang = Lang}) ->
    form_changepass_get(Lang);

%% TODO: Currently only the first vhost is usable. The web request record
%% should include the host where the POST was sent.
process(["new"], #request{method = 'POST', q = Q, lang = Lang}) ->
    Host = ?MYNAME,
    case form_new_post(Q, Host) of
    	{atomic, ok} ->
	    Text = ?T("Your Jabber account was succesfully created."),
	    {200, [], Text};
	Error ->
	    ErrorText = ?T("There was an error creating the account: ") ++
		?T(get_error_text(Error)),
	    {404, [], ErrorText}
    end;

%% TODO: Currently only the first vhost is usable. The web request record
%% should include the host where the POST was sent.
process(["delete"], #request{method = 'POST', q = Q, lang = Lang}) ->
    Host = ?MYNAME,
    case form_del_post(Q, Host) of
    	{atomic, ok} ->
	    Text = ?T("Your Jabber account was succesfully deleted."),
	    {200, [], Text};
	Error ->
	    ErrorText = ?T("There was an error deleting the account: ") ++
		?T(get_error_text(Error)),
	    {404, [], ErrorText}
    end;

%% TODO: Currently only the first vhost is usable. The web request record
%% should include the host where the POST was sent.
process(["change_password"], #request{method = 'POST', q = Q, lang = Lang}) ->
    Host = ?MYNAME,
    case form_changepass_post(Q, Host) of
    	{atomic, ok} ->
	    Text = ?T("The password of your Jabber account was succesfully changed."),
	    {200, [], Text};
	Error ->
	    ErrorText = ?T("There was an error changing the password: ") ++
		?T(get_error_text(Error)),
	    {404, [], ErrorText}
    end.


%%%----------------------------------------------------------------------
%%% CSS
%%%----------------------------------------------------------------------

serve_css() ->
    {200, [{"Content-Type", "text/css"},
	   last_modified(), cache_control_public()], css()}.

last_modified() ->
    {"Last-Modified", "Mon, 25 Feb 2008 13:23:30 GMT"}.
cache_control_public() ->
    {"Cache-Control", "public"}.

css() ->
    "html,body {
background: white;
margin: 0;
padding: 0;
height: 100%;
}".


%%%----------------------------------------------------------------------
%%% Index page 
%%%----------------------------------------------------------------------

index_page(Lang) ->
    HeadEls = [
	       ?XCT("title", "Jabber Account Registration"),
	       ?XA("link",
		   [{"href", "/register/register.css"},
		    {"type", "text/css"},
		    {"rel", "stylesheet"}])
	      ],
    Els=[
	 ?XACT("h1", 
	       [{"class", "title"}, {"style", "text-align:center;"}],
	       "Jabber Account Registration"),
	 ?XE("ul", [
		    ?XE("li", [?ACT("new", "Register a Jabber account")]),
		    ?XE("li", [?ACT("change_password", "Change Password")]),
		    ?XE("li", [?ACT("delete", "Unregister a Jabber account")])
		   ]
	    )
	],
    {200,
     [{"Server", "ejabberd"},
      {"Content-Type", "text/html"}],
     ejabberd_web:make_xhtml(HeadEls, Els)}.


%%%----------------------------------------------------------------------
%%% Formulary new account GET
%%%----------------------------------------------------------------------

form_new_get(Lang) ->
    HeadEls = [
	       ?XCT("title", "Register a Jabber account"),
	       ?XA("link",
		   [{"href", "/register/register.css"},
		    {"type", "text/css"},
		    {"rel", "stylesheet"}])
	      ],
    Els=[
	 ?XACT("h1", 
	       [{"class", "title"}, {"style", "text-align:center;"}],
	       "Register a Jabber account"),
	 ?XCT("p",
	      "This page allows to create a Jabber account in this Jabber server. "
	      "Your JID (Jabber IDentifier) will be of the form: username@server. "
	      "Please read carefully the instructions to fill correctly the fields."),
	 %% <!-- JID's take the form of 'username@server.com'. For example, my JID is 'kirjava@jabber.org'.
	 %% The maximum length for a JID is 255 characters. -->
	 ?XAE("form", [{"action", ""}, {"method", "post"}],
	      [
	       ?XE("ol", [
			  ?XE("li", [
				     ?CT("Username:"),
				     ?C(" "),
				     ?INPUTS("text", "username", "", "20"),
				     ?BR,
				     ?XE("ul", [
						?XC("li", "The JID is case insensitive. The username 'macbeth' is the same that 'MacBeth' and 'Macbeth'."),
						?XC("li", "The username can NOT contain any of those characters: @ : ' \" < > &")
					       ])
				    ]),
			  ?XE("li", [
				     ?CT("Password:"),
				     ?C(" "),
				     ?INPUTS("text", "password", "", "20"),
				     ?BR,
				     ?XE("ul", [
						?XC("li", "This password protects your Jabber account. "
						    "Don't tell your password to anybody else. "
						    "Nobody else than you needs your password for anything, "
						    "not even the administrators of the Jabber server."),
						?XC("li", "You can later change your password using a Jabber client."),
						?XC("li", "Some Jabber clients can store your password in your computer. "
						    "Use that feature only if you trust your computer is safe."),
						?XC("li", "Please, memorize your password, or write it in a paper placed in a safe place. " 
						    "In Jabber there isn't an automated way to recover your password if you forget it.")
					       ])
				    ]),
			  ?XE("li", [
				     ?CT("Password Verification:"),
				     ?C(" "),
				     ?INPUTS("text", "password2", "", "20")
				    ]),
			  %% Nombre</b> (opcional)<b>:</b> <input type="text" size="20" name="name" maxlength="255"> <br /> <br /> -->
			  %% 
			  %% Direcci&oacute;n de correo</b> (opcional)<b>:</b> <input type="text" size="20" name="email" maxlength="255"> <br /> <br /> -->
			  ?XE("li", [
				     ?INPUTT("submit", "register", "Register")
				    ])
			 ])
	      ])
	],
    {200,
     [{"Server", "ejabberd"},
      {"Content-Type", "text/html"}],
     ejabberd_web:make_xhtml(HeadEls, Els)}.


%%%----------------------------------------------------------------------
%%% Formulary new POST
%%%----------------------------------------------------------------------

form_new_post(Q, Host) ->
    case catch get_register_parameters(Q) of
	[Username, Password, Password] ->
	    register_account(Username, Host, Password);
	[_Username, _Password, _Password2] ->
	    {error, passwords_not_identical};
	_ ->
	    {error, wrong_parameters}
    end.

get_register_parameters(Q) ->
    lists:map(
      fun(Key) ->
	      {value, {_Key, Value}} = lists:keysearch(Key, 1, Q),
	      Value
      end,
      ["username", "password", "password2"]).


%%%----------------------------------------------------------------------
%%% Formulary change password GET
%%%----------------------------------------------------------------------

form_changepass_get(Lang) ->
    HeadEls = [
	       ?XCT("title", "Change Password"),
	       ?XA("link",
		   [{"href", "/register/register.css"},
		    {"type", "text/css"},
		    {"rel", "stylesheet"}])
	      ],
    Els=[
	 ?XACT("h1", 
	       [{"class", "title"}, {"style", "text-align:center;"}],
	       "Change Password"),
	 ?XAE("form", [{"action", ""}, {"method", "post"}],
	      [
	       ?XE("ol", [
			  ?XE("li", [
				     ?CT("Username:"),
				     ?C(" "),
				     ?INPUTS("text", "username", "", "20")
				    ]),
			  ?XE("li", [
				     ?CT("Old Password:"),
				     ?C(" "),
				     ?INPUTS("text", "passwordold", "", "20")
				    ]),
			  ?XE("li", [
				     ?CT("New Password:"),
				     ?C(" "),
				     ?INPUTS("text", "password", "", "20")
				    ]),
			  ?XE("li", [
				     ?CT("Password Verification:"),
				     ?C(" "),
				     ?INPUTS("text", "password2", "", "20")
				    ]),
			  ?XE("li", [
				     ?INPUTT("submit", "changepass", "Change Password")
				    ])
			 ])
	      ])
	],
    {200,
     [{"Server", "ejabberd"},
      {"Content-Type", "text/html"}],
     ejabberd_web:make_xhtml(HeadEls, Els)}.


%%%----------------------------------------------------------------------
%%% Formulary change password POST
%%%----------------------------------------------------------------------

form_changepass_post(Q, Host) ->
    case catch get_changepass_parameters(Q) of
	[Username, PasswordOld, Password, Password] ->
	    try_change_password(Username, Host, PasswordOld, Password);
	[_Username, _PasswordOld, _Password, _Password2] ->
	    {error, passwords_not_identical};
	_ ->
	    {error, wrong_parameters}
    end.

get_changepass_parameters(Q) ->
    lists:map(
      fun(Key) ->
	      {value, {_Key, Value}} = lists:keysearch(Key, 1, Q),
	      Value
      end,
      ["username", "passwordold", "password", "password2"]).

%% @spec(Username,Host,PasswordOld,Password) -> {atomic, ok} |
%%                                              {error, account_doesnt_exist} |
%%                                              {error, password_not_changed} |
%%                                              {error, password_incorrect}
try_change_password(Username, Host, PasswordOld, Password) ->
    try change_password(Username, Host, PasswordOld, Password) of
	{atomic, ok} ->
	    {atomic, ok}
    catch
	error:{badmatch, Error} ->
	    {error, Error}
    end.

change_password(Username, Host, PasswordOld, Password) ->
    %% Check the account exists
    account_exists = check_account_exists(Username, Host),

    %% Check the old password is correct
    password_correct = check_password(Username, Host, PasswordOld),

    %% This function always returns: ok
    %% Change the password
    {atomic, ok} = ejabberd_auth:set_password(Username, Host, Password),

    %% Check the new password is correct
    case check_password(Username, Host, Password) of
    	password_correct -> 
	    {atomic, ok};
    	password_incorrect -> 
	    {error, password_not_changed}
    end.

check_account_exists(Username, Host) ->
    case ejabberd_auth:is_user_exists(Username, Host) of
    	true -> account_exists;
	false -> account_doesnt_exist
    end.

check_password(Username, Host, Password) ->
    case ejabberd_auth:check_password(Username, Host, Password) of
    	true -> password_correct;
	false -> password_incorrect
    end.


%%%----------------------------------------------------------------------
%%% Formulary delete account GET
%%%----------------------------------------------------------------------

form_del_get(Lang) ->
    HeadEls = [
	       ?XCT("title", "Unregister a Jabber account"),
	       ?XA("link",
		   [{"href", "/register/register.css"},
		    {"type", "text/css"},
		    {"rel", "stylesheet"}])
	      ],
    Els=[
	 ?XACT("h1", 
	       [{"class", "title"}, {"style", "text-align:center;"}],
	       "Unregister a Jabber account"),
	 ?XCT("p",
	      "This page allows to unregister a Jabber account in this Jabber server."),
	 ?XAE("form", [{"action", ""}, {"method", "post"}],
	      [
	       ?XE("ol", [
			  ?XE("li", [
				     ?CT("Username:"),
				     ?C(" "),
				     ?INPUTS("text", "username", "", "20")
				    ]),
			  ?XE("li", [
				     ?CT("Password:"),
				     ?C(" "),
				     ?INPUTS("text", "password", "", "20")
				    ]),
			  ?XE("li", [
				     ?INPUTT("submit", "unregister", "Unregister")
				    ])
			 ])
	      ])
	],
    {200,
     [{"Server", "ejabberd"},
      {"Content-Type", "text/html"}],
     ejabberd_web:make_xhtml(HeadEls, Els)}.

%% @spec(Username, Host, Password) -> {atomic, ok} |
%%                                    {atomic, exists} |
%%                                    {error, not_allowed} |
%%                                    {error, invalid_jid}
register_account(Username, Host, Password) ->
    ejabberd_auth:try_register(Username, Host, Password).


%%%----------------------------------------------------------------------
%%% Formulary delete POST
%%%----------------------------------------------------------------------

form_del_post(Q, Host) ->
    case catch get_unregister_parameters(Q) of
	[Username, Password] ->
	    try_unregister_account(Username, Host, Password);
	_ ->
	    {error, wrong_parameters}
    end.

get_unregister_parameters(Q) ->
    lists:map(
      fun(Key) ->
	      {value, {_Key, Value}} = lists:keysearch(Key, 1, Q),
	      Value
      end,
      ["username", "password"]).

%% @spec(Username, Host, Password) -> {atomic, ok} |
%%                                    {error, account_doesnt_exist} |
%%                                    {error, account_exists} |
%%                                    {error, password_incorrect}
try_unregister_account(Username, Host, Password) ->
    try unregister_account(Username, Host, Password) of
	{atomic, ok} ->
	    {atomic, ok}
    catch
	error:{badmatch, Error} ->
	    {error, Error}
    end.

unregister_account(Username, Host, Password) ->
    %% Check the account exists
    account_exists = check_account_exists(Username, Host),

    %% Check the password is correct
    password_correct = check_password(Username, Host, Password),

    %% This function always returns: ok
    ok = ejabberd_auth:remove_user(Username, Host, Password),

    %% Check the account does not exist anymore
    account_doesnt_exist = check_account_exists(Username, Host),

    %% If we reached this point, return success
    {atomic, ok}.


%%%----------------------------------------------------------------------
%%% Error texts
%%%----------------------------------------------------------------------

get_error_text({atomic, exists}) ->
    "The account already exists";
get_error_text({error, password_incorrect}) ->
    "Incorrect password";
get_error_text({error, invalid_jid}) ->
    "The username is not valid";
get_error_text({error, not_allowed}) ->
    "Not allowed";
get_error_text({error, account_doesnt_exist}) ->
    "Account doesn't exist";
get_error_text({error, account_exists}) ->
    "The account was not deleted";
get_error_text({error, password_not_changed}) ->
    "The password was not changed";
get_error_text({error, passwords_not_identical}) ->
    "The passwords are different";
get_error_text({error, wrong_parameters}) ->
    "Wrong parameters in the web formulary".

