#!/usr/bin/env python
from optparse import OptionParser
import os, MySQLdb, logging, sys, re

user=""
passwd=""
dbname=""
host=""
port=3306
vhost=""

parser = OptionParser()
parser.add_option("-f", "--force",
                     action="store_true", dest="FORCE", default=False,
                     help="force make changes")
(options, args) = parser.parse_args()

logger = logging.getLogger('main')
ch = logging.StreamHandler()
formatter_con = logging.Formatter("%(asctime)s - %(levelname)s: %(message)s")
ch.setFormatter(formatter_con)
logger.addHandler(ch)
logger.setLevel(logging.INFO)

db = MySQLdb.connect(host=host, port=port, db=dbname, user=user, passwd=passwd)
cursor = db.cursor()

escaped_vhost = vhost.replace(".", "_")

Query = "DROP TABLE `messages-stats_" + escaped_vhost + "`"
if not options.FORCE:
   QRes = "skipped"
else:
   cursor.execute(Query)
   QRes = "done (" + str(cursor.fetchall()) + ")"
logger.info("Doing %s: %s"%(Query, QRes))

cursor.execute("""SHOW TABLES""")
Tables = cursor.fetchall()
for Table in Tables:
    if re.match(".*"+vhost+".*", Table[0]):
       Match = re.search("[0-9]+-[0-9]+-[0-9]+", Table[0])
       if Match:
          Date = Table[0][Match.start():Match.end()]
          Query = "RENAME TABLE `messages_"+escaped_vhost+"_"+Date+"` TO `logdb_messages_"+Date+"_"+escaped_vhost+"`"
          if not options.FORCE:
             QRes = "skipped"
          else:
             cursor.execute(Query)
             QRes = "done (" + str(cursor.fetchall()) + ")"
          logger.info("Doing %s: %s"%(Query, QRes))
