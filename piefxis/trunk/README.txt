

	piefxis - Import/Export Users (XEP-0227)

	Modules for ejabberd 2.0.x. Not needed in ejabberd 2.1.x or 3.x
	Requirements: exmpp


	IMPORTANT
	=========

You only need this code if using ejabberd 2.0.x.
ejabberd 2.1.0 and higher, 3.0.0 and higher will include this feature.

You need to have the exmpp library installed in the machine
in order to compile and run this code.


	CONFIGURATION
	=============

Add the module to your ejabberd.cfg, on the modules section:
{modules, [
  ...
  {mod_piefxis, []},
  ...
]}.


	IMPORT
	======

How to import an XML file into ejabberd:

1. Add in ejabberd.cfg the virtual hosts you will import:
  {hosts, ["capulet.com", "montague.net", "shakespeare.lit"]}.

2. Start ejabberd.

3. Execute this command to import an XML file:
  ejabberdctl import-piefxis /path/to/file.xml

4. If everything went right you don't get any error message.


	EXPORT
	======

How to export to XML file the users of all hosts in ejabberd:

1. Start ejabberd.

2. Execute this command, indicating the directory:
  ejabberdctl export-piefxis /path/to/export/

3. If everything went right you don't get any error message,
and you will get one or several XML files like this:
  20090805-120450.xml
  20090805-120450_capulet_com.xml
  20090805-120450_jabber_example_org.xml
  20090805-120450_localhost.xml


It is also possible to export the users of only one host:

1. Start ejabberd.

2. Execute this command, indicating the directory and host to export:
  ejabberdctl export-piefxis_host /path/to/export/ jabber.example.org

3. If everything went right you don't get any error message,
and you will get one or several XML files like this:
  20090805-120723_jabber_example_org.xml

