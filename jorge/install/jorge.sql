--
-- Table structure for table `jorge_logger`
--

DROP TABLE IF EXISTS `jorge_logger`;
CREATE TABLE `jorge_logger` (
  `id_user` int(11) default NULL,
  `id_log_detail` int(11) default NULL,
  `id_log_level` int(11) default NULL,
  `log_time` varchar(20) default NULL,
  `extra` text,
  KEY `jorge_log_idx` (`id_user`,`id_log_level`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `jorge_logger_dict`
--

DROP TABLE IF EXISTS `jorge_logger_dict`;
CREATE TABLE `jorge_logger_dict` (
  `id_event` int(11) NOT NULL auto_increment,
  `event` text,
  `lang` char(3) default NULL,
  PRIMARY KEY  (`id_event`),
  KEY `jorge_logger_dict_idx` (`id_event`,`lang`)
) ENGINE=MyISAM AUTO_INCREMENT=10 DEFAULT CHARSET=latin1;

--
-- Table structure for table `jorge_logger_level_dict`
--

DROP TABLE IF EXISTS `jorge_logger_level_dict`;
CREATE TABLE `jorge_logger_level_dict` (
  `id_level` int(11) NOT NULL auto_increment,
  `level` varchar(20) default NULL,
  `lang` char(3) default NULL,
  PRIMARY KEY  (`id_level`)
) ENGINE=MyISAM AUTO_INCREMENT=4 DEFAULT CHARSET=latin1;

--
-- Table structure for table `jorge_mylinks`
--

DROP TABLE IF EXISTS `jorge_mylinks`;
CREATE TABLE `jorge_mylinks` (
  `id_link` int(11) NOT NULL auto_increment,
  `owner_id` int(11) default NULL,
  `peer_name_id` int(11) default NULL,
  `peer_server_id` int(11) default NULL,
  `datat` text,
  `link` text,
  `description` text,
  PRIMARY KEY  (`id_link`)
) ENGINE=MyISAM AUTO_INCREMENT=179 DEFAULT CHARSET=latin1;

--
-- Insert data into dictionary
--

LOCK TABLES `jorge_logger_dict` WRITE;
/*!40000 ALTER TABLE `jorge_logger_dict` DISABLE KEYS */;
INSERT INTO `jorge_logger_dict` VALUES (1,'Logged in','eng'),(2,'Logged out','eng'),(3,'Login failed','eng'),(4,'Deleted chat thread','eng'),(5,'Deleted whole archive','eng'),(6,'Turned off archivization','eng'),(7,'Turned on archivization','eng'),(8,'Chat exported','eng'),(9,'Deleted entire archive','eng');
/*!40000 ALTER TABLE `jorge_logger_dict` ENABLE KEYS */;
UNLOCK TABLES;


LOCK TABLES `jorge_logger_level_dict` WRITE;
/*!40000 ALTER TABLE `jorge_logger_level_dict` DISABLE KEYS */;
INSERT INTO `jorge_logger_level_dict` VALUES (1,'normal','eng'),(2,'warn','eng'),(3,'alert','eng');
/*!40000 ALTER TABLE `jorge_logger_level_dict` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Lets create view for jorge_logger for out convinience
--

CREATE VIEW v_jorge_logger AS 

SELECT b.username AS username, c.level AS level, d.event AS event, a.log_time AS log_time, a.extra AS extra 
	
FROM 
	jorge_logger a, 
	jorge_logger_dict d, 
	jorge_logger_level_dict c, 
	logdb_users_jabber_autocom_pl b 
	
WHERE 
b.user_id = a.id_user and 
c.id_level = a.id_log_level and 
d.id_event = a.id_log_detail;

--
-- Here is little tip: message view for your convinience. You can use this JOINS as primary data source:


-- CREATE VIEW `v_logdb_messages_YOUR_DATE_TABLE_YOUR_XMPP_SERVER` AS
-- 
-- SELECT a.username AS user_name, b.username AS peer_name, c.server, d.resource, f.direction, e.type, f.subject, f.body, f.timestamp 
--
-- FROM 
--  `logdb_users_YOUR_XMPP_SERVER` a, 
--  `logdb_users_YOUR_XMPP_SERVER` b,
--  `logdb_servers_YOUR_XMPP_SERVER` c, 
--  `logdb_resources_YOUR_XMPP_SERVER` d, 
--  `logdb_types_YOUR_XMPP_SERVER` e,
--  `logdb_messages_YOUR_DATE_TABLE_YOUR_XMPP_SERVER` f
--
-- WHERE 
-- a.user_id=f.owner_id and 
-- b.user_id=f.peer_name_id and
-- c.server_id=f.peer_server_id and 
-- d.resource_id=f.peer_resource_id and
-- e.type_id=f.type_id;

