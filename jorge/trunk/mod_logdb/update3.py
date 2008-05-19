#!/usr/bin/env python
import os, MySQLdb, logging, sys, re
from _mysql_exceptions import IntegrityError

user="root"
passwd=""
dbname="logdb"
host="localhost"
port=3306
vhost="test"

logger = logging.getLogger('main')
ch = logging.StreamHandler()
formatter_con = logging.Formatter("%(asctime)s - %(levelname)s: %(message)s")
ch.setFormatter(formatter_con)
logger.addHandler(ch)
logger.setLevel(logging.INFO)

db = MySQLdb.connect(host=host, port=port, db=dbname, user=user, passwd=passwd)
cursor = db.cursor()

escaped_vhost = vhost.replace(".", "_")

Query = "select type,type_id from `logdb_types_%s`;"%escaped_vhost
cursor.execute(Query)
Types = cursor.fetchall()

cursor.execute("""SHOW TABLES""")
Tables = cursor.fetchall()

cursor.close()
db.close()

for Table in Tables:
    if re.match("logdb_.*"+escaped_vhost+"$", Table[0]):
       if re.search("[0-9]+-[0-9]+-[0-9]+", Table[0]):
          db = MySQLdb.connect(host=host, port=port, db=dbname, user=user, passwd=passwd)
          cursor = db.cursor()
          TableName = "`"+Table[0]+"`"
          cursor.execute("""DESCRIBE %s"""%TableName)
          TableDesc = cursor.fetchall()
          if TableDesc[5][0] == 'type_id':
              Query = "ALTER TABLE %s CHANGE type_id type_id TEXT;"%(TableName)
              cursor.execute(Query)
              for Type in Types:
                  TypeName = Type[0]
                  if TypeName=='':
                     TypeName='normal'
                  TypeId = Type[1]
                  Query = "UPDATE %s SET type_id='%s' WHERE type_id='%s'"%(TableName,TypeName,TypeId)
                  cursor.execute(Query)
              Query = "ALTER TABLE %s CHANGE type_id type ENUM('chat','error','groupchat','headline','normal') NOT NULL;"%(TableName)
              cursor.execute(Query)
              logger.info("updated type in %s"%TableName)
              Query = "ALTER TABLE %s CHANGE direction direction TEXT;"%(TableName)
              cursor.execute(Query)
              Query = "UPDATE %s SET direction='to' WHERE direction='0'"%(TableName)
              cursor.execute(Query)
              Query = "UPDATE %s SET direction='from' WHERE direction='1'"%(TableName)
              cursor.execute(Query)
              Query = "ALTER TABLE %s CHANGE direction direction ENUM('to','from');"%(TableName)
              cursor.execute(Query)
              logger.info("updated direction in %s"%TableName)
              Query = """CREATE OR REPLACE VIEW `%s` AS
SELECT owner.username AS owner_name,
       peer.username AS peer_name,
       servers.server AS peer_server,
       resources.resource AS peer_resource,
       messages.direction,
       messages.type,
       messages.subject,
       messages.body,
       messages.timestamp
FROM
       `%s` owner,
       `%s` peer,
       `%s` servers,
       `%s` resources,
       `%s` messages
WHERE
       owner.user_id=messages.owner_id and
       peer.user_id=messages.peer_name_id and
       servers.server_id=messages.peer_server_id and
       resources.resource_id=messages.peer_resource_id
ORDER BY messages.timestamp;"""%("v_"+Table[0], "logdb_users_"+escaped_vhost, "logdb_users_"+escaped_vhost, "logdb_servers_"+escaped_vhost, "logdb_resources_"+escaped_vhost, Table[0])
              cursor.execute(Query)
              logger.info("created view for %s"%TableName)
          elif TableDesc[5][0] == 'type':
                logger.info("%s already updated"%TableName)
          else:
                logger.info("internal error at %s: %s"%(TableName,TableDesc[5][0]))

          cursor.close()
          db.close()
