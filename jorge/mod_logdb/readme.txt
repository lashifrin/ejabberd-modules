mod_logdb by Oleg Palij
-----------------------

*NOTE* - Jorge is compatibile only with distributed mod_logdb. Please follow instruction below carefully. 
Jorge try to always be up-to-date with the latest mod_logdb but there still can be some delays.


Instalation instruction:
1) Grab ejabberd2.0 (svn) - rev. 861
2) patch sources of ejabberd using "patch" tool (f.e: patch -p0 < patch-src-mod_logdb_svn), alternativly if you are polish patch lang file with provided patch (msgs/)
2) setup mysql5 database (dbname,username, etc...). Db schema will be automaticly setup during mod_logdb startup.
3) edit config of your ejabberd server by adding followin lines into modules section:

{mod_logdb,
    [{vhosts, [{"your_xmpp_server", mysql}]},
    {dbs, [{mysql, [{user, "db_username"},{password, "db_password"},{server, "ip_of_the_db_server"},{port, 3306},{db, "db_name"}]}]},
    {groupchat, none},
    {purge_older_days, never},
    {ignore_jids, ["example@jid.pl", "example2@jid.pl"]},
    {dolog_default, false}
]},

and add for ad-hoc commands on the top of the config file:

{access, mod_logdb, [{allow, all}]}.
{access, mod_logdb_admin, [{allow, admin}]}.

4) restart the server
5) have fun

For futhure info consult mod_logdb manual.

Note for admins who use clustered setup: you need to install mod_logdb on each ejabberd node. 
Multiple mod_logdb sessions can share database access without any problems.
