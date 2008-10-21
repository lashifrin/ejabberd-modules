
        ejabberd_xmlrpc - XML-RPC server

        Homepage: http://www.ejabberd.im/ejabberd_xmlrpc
        Author: Badlop


	DESCRIPTION
	-----------

ejabberd_xmlrpc is an ejabberd listener that starts a XML-RPC server
and waits for external calls.

ejabberd_xmlrpc implements some example calls that can be used to test
during the development of a new XML-RPC client.  But most
imporntantly, ejabberd_xmlrpc is also a frontend to execute ejabberd
commands.  This way a XML-RPC client can execute any ejabberd command.

This allows external programs written in any language like websites or
administrative tools to communicate with ejabberd to get information
or to make changes without the need to know ejabberd internals.  One
example usage is a corporate site in PHP that creates a Jabber user
every time a new user is created on the website.

Some benefits of interfacing with the Jabber server by XML-RPC instead
of modifying directly the database are:
 - external programs are more simple and easy to develop and debug
 - can communicate with a server in a different machine, and even on Internet


	REQUIREMENTS
	------------

    ejabberd trunk SVN 1635 or newer
    XMLRPC-Erlang 1.13 with IP, Ruby and Xmerl 1.x patches
    Optional: mod_admin_extra implements many ejabberd commands for general server administration
    Optional: mod_muc_admin implements ejabberd commands for MUC administration


 - Install XMLRPC-Erlang

wget http://www.ejabberd.im/files/contributions/xmlrpc-1.13-ipr2.tgz
tar -xzvf xmlrpc-1.13-ipr2.tgz
cd xmlrpc-1.13/src
make
cd ../../


	CONFIGURE EJABBERD
	------------------

1. Add an option like this to the ejabberd start script:

$ erl -pa '/home/jabber/xmlrpc-1.13/ebin' ...

2. Configure ejabberd to start this listener at startup:
edit ejabberd.cfg and add on the 'listen' section:
{listen, [
   {4560, ejabberd_xmlrpc, []},
    ...
 ]}.

3. Now start ejabberd.

4. Verify that ejabberd is listening in that port:
$ netstat -n -l | grep 4560
tcp        0      0 0.0.0.0:4560            0.0.0.0:*               LISTEN

5. If there is any problem, check ejabberd.log and sasl.log files


	CONFIGURE
	---------

You can configure the port where the XML-RPC server will listen.

The listener allow several configurable options:
    {ip, IPValue}
    IP address to listen, in Erlang format, for example: {ip, {127, 0, 0, 1}}
    Set to 'all' to listen on all IP address: {ip, all}
    Default: all

    {maxsessions, Integer}
    Number of concurrent connections allowed.
    Default: 10

    {timeout, Integer}
    Timeout of the connections, expressed in milliseconds.
    Default: 5000

    {access, AccessRule}
    This option defines access to the port.
    If this value is different than 'all', then the first argument of each XML-RPC call
    must be a struct with a user, server and password of an account in ejabberd
    that has privileges in AccessRule.
    If this value is 'all', then such struct must not be provided.
    Default: all

In this example configuration, only the Jabber account xmlrpc-robot@jabber.example.org can use the XML-RPC service:

{acl, xmlrpcbot, {user, "xmlrpc-robot", "jabber.example.org"}}.
{access, xmlrpcaccess, [{allow, xmlrpcbot}]}.
{listen, [
    {4560, ejabberd_xmlrpc, [{ip, {71, 202, 202, 79}}, {maxsessions, 10}, {timeout, 5000}, {access, xmlrpcaccess}]},
   ...
 ]}.


	USAGE
	-----

You can send calls to http://host:4560/

Call:           Arguments:                                                 Returns:

 -- debug
echothis        String                                                       String
echothisnew     struct[{sentence, String}]               struct[{repeated, String}]
multhis         struct[{a, Integer}, {b, Integer}]                          Integer
multhisnew      struct[{a, Integer}, {b, Integer}]            struct[{mu, Integer}]

 -- statistics
tellme_title    String                                                       String
tellme_value    String                                                       String
tellme          String                     struct[{title, String}, {value. String}]


With ejabberd_xmlrpc you can execute any ejabberd command with a XML-RPC call.

1. Get a list of available ejabberd commands, for example:
$ ejabberdctl help
Available commands in this ejabberd node:
  connected_users              List all established sessions
  connected_users_number       Get the number of established sessions
  delete_expired_messages      Delete expired offline messages from database
  delete_old_messages days     Delete offline messages older than DAYS
  dump file                    Dump the database to text file
  register user host password  Register a user
  registered_users host        List all registered users in HOST
  reopen_log                   Reopen the log files
  restart                      Restart ejabberd
  restore file                 Restore the database from backup file
  status                       Get ejabberd status
  stop                         Stop ejabberd
  unregister user host         Unregister a user
  user_resources user host     List user's connected resources

2. When you found the command you want to call, get some additional
   help of the arguments and result:
$ ejabberdctl help user_resources
  Command Name: user_resources
  Arguments: user::string
             host::string
  Returns: resources::[ resource::string ]
  Tags: session
  Description: List user's connected resources

3. You can try to execute the command in the shell for the account testuser@localhost:
$ ejabberdctl user_resources testuser localhost
Home
Psi

4. Now implement the proper XML-RPC call in your XML-RPC client.
   This example will use the Erlang library:
$ erl
1> xmlrpc:call({127, 0, 0, 1}, 4560, "/", {call, user_resources, [{struct, [{user, "testuser"}, {host, "localhost"}]}]}).
{ok,{response,[{struct,[{resources,{array,[{struct,[{resource,"Home"}]},
                                           {struct,[{resource,"Psi"}]}]}}]}]}}

5. Note: if ejabberd_xmlrpc has an 'access' configured, as the example
   configuration provided above, the XML-RPC must include first an
   argument providing information of a valid account. For example:
1> xmlrpc:call({127, 0, 0, 1}, 4560, "/", {call, user_resources, [
  {struct, [{user, "xmlrpc-robot"}, {server, "jabber.example.org"}, {password, "mYXMLrpcBotPasSword"}]},
  {struct, [{user, "testuser"}, {host, "localhost"}]}
]}).


	EXAMPLE IN PHP
	--------------

This is an XML-RPC client in PHP, thanks to Zbyszek Żółkiewski and Calder.
It requires "allow_url_fopen = On" in your php.ini.

-------
<?
$param=array("user"=>"testuser", "host"=>"localhost");
$request = xmlrpc_encode_request('user_resources', $param, (array('encoding' => 'utf-8')));

$context = stream_context_create(array('http' => array(
    'method' => "POST",
    'header' => "User-Agent: XMLRPC::Client mod_xmlrpc\r\n" .
                "Content-Type: text/xml\r\n" .
                "Content-Length: ".strlen($request),
    'content' => $request
)));

$file = file_get_contents("http://127.0.0.1:4560/RPC2", false, $context);

$response = xmlrpc_decode($file);

if (xmlrpc_is_fault($response)) {
    trigger_error("xmlrpc: $response[faultString] ($response[faultCode])");
} else {
    print_r($response);
}

?>
-------

The response, following the example would be like this:
-------
$ php5 call.php
Array
(
    [resources] => Array
        (
            [0] => Array
                (
                    [resource] => Home
                )
            [1] => Array
                (
                    [resource] => Psi
                )
        )
)
-------



 **** WARNING: all the remaining text was written for mod_xmlrpc and
      is NOT valid for ejabberd_xmlrpc ****


	TEST
	----

 - You can easily try the XML-RPC server starting a new Erlang Virtual Machine
   and making calls to ejabberd's XML-RPC:

1. Start Erlang with this option:
$ erl -pa '/home/jabber/xmlrpc-1.13/ebin'

2. Now on the Erlang console, write commands and check the results:

1> xmlrpc:call({127, 0, 0, 1}, 4560, "/", {call, echothis, [800]}).
{ok,{response,[800]}}

2> xmlrpc:call({127, 0, 0, 1}, 4560, "/", {call, echothis, ["blot cloc 557.889 kg"]}).
{ok,{response,["blot cloc 557.889 kg"]}}

3> xmlrpc:call({127, 0, 0, 1}, 4560, "/", {call, multhis, [{struct,[{a, 83}, {b, 689}]}]}).
{ok,{response,[57187]}}

4> xmlrpc:call({127, 0, 0, 1}, 4560, "/", {call, create_account,
[{struct, [{user, "ggeo"}, {host, "example.com"}, {password, "gogo11"}]}]}).
{ok,{response,[0]}}

5> xmlrpc:call({127, 0, 0, 1}, 4560, "/", {call, create_account,
[{struct, [{user, "ggeo"}, {host, "example.com"}, {password, "gogo11"}]}]}).
{ok,{response,[409]}}

6> xmlrpc:call({127, 0, 0, 1}, 4560, "/", {call, muc_room_change_option,
[{struct, [{name, "test"}, {service, "conference.localhost"},
 {option, "title"}, {value, "Test Room"}]}]}).

7> xmlrpc:call({127, 0, 0, 1}, 4560, "/", {call, muc_room_set_affiliation,
[{struct, [{name, "test"}, {service, "conference.example.com"},
{jid, "ex@example.com"}, {affiliation, "member"}]}]}).

8> xmlrpc:call({127, 0, 0, 1}, 4560, "/", {call, muc_room_set_affiliation,
[{struct, [{name, "test"}, {service, "conference.example.com"},
{jid, "ex@example.com"}, {affiliation, "none"}]}]}).


 - Some possible XML-RPC error messages:

   + Client: connection refused: wrong IP, wrong port, the server is not started...

2> xmlrpc:call({127, 0, 0, 1}, 44444, "/", {call, echothis, [800]}).
{error,econnrefused}

   + Client: bad value: a800 is a string, so it must be put into ""

7> xmlrpc:call({127, 0, 0, 1}, 4560, "/", {call, echothis, [a800]}).
{error,{bad_value,a800}}

   + Server: unknown call: you sent a call that the server does not implement

3> xmlrpc:call({127, 0, 0, 1}, 4560, "/", {call, bububu, [800]}).
{ok,{response,{fault,-1,"Unknown call: {call,bububu,[800]}"}}}


	EXAMPLE IN PYTHON
	-----------------

This is an example XML-RPC client in Python, thanks to Diddek:
-------
import xmlrpclib

server_url = 'http://127.0.0.1:4560';
server = xmlrpclib.Server(server_url);

params = {}
params["user"] = "ggeo"
params["host"] = "localhost"
params["password"] = "gogo11"

result = server.create_account(params)
print result
-------


	EXAMPLE IN RUBY
	---------------

This is an example XML-RPC client in Ruby, thanks to Diddek:
-------
require 'xmlrpc/client'

host = "172.16.29.6:4560"
timeout = 3000000
client = XMLRPC::Client.new2("http://#{host}", "#{host}", timeout)
result = client.call("echothis", "800")
puts result
-------


	EXAMPLE IN JAVA
	---------------

This is an XML-RPC client in Java, thanks to Calder.
It requires Apache XML-RPC available at http://ws.apache.org/xmlrpc/

-------
import java.net.URL;
import java.util.HashMap;
import java.util.Map;

import org.apache.xmlrpc.client.XmlRpcClient;
import org.apache.xmlrpc.client.XmlRpcClientConfigImpl;

public class Test {

	public static void main(String[] args) {
		try {
		    XmlRpcClientConfigImpl config = new XmlRpcClientConfigImpl();
		    config.setServerURL(new URL("http://127.0.0.1:4560/RPC2"));
		    XmlRpcClient client = new XmlRpcClient();
		    client.setConfig(config);

		    /* Command string */
		    String command = "check_password";

		    /* Parameters as struct */
		    Map struct = new HashMap();
		    struct.put("user", "test1");
		    struct.put("host", "localhost");
		    struct.put("password", "test");

		    Object[] params = new Object[]{struct};
		    Integer result = (Integer) client.execute(command, params);
		    System.out.println(result);
		} catch (Exception e) {
			System.out.println(e);
		}
	}

}
-------
