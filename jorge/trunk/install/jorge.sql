-- MySQL dump 10.11
--
-- Host: localhost    Database: jabster_logdb
-- ------------------------------------------------------
-- Server version	5.0.51b-log

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

--
-- Table structure for table `jorge_favorites`
--

DROP TABLE IF EXISTS `jorge_favorites`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `jorge_favorites` (
  `owner_id` int(11) default NULL,
  `peer_name_id` int(11) default NULL,
  `peer_server_id` int(11) default NULL,
  `resource_id` int(11) default NULL,
  `tslice` varchar(20) default NULL,
  `comment` varchar(50) default NULL,
  `ext` int(11) default NULL,
  `link_id` int(10) unsigned NOT NULL auto_increment,
  `vhost` varchar(255) default NULL,
  PRIMARY KEY  (`link_id`),
  KEY `jorge_favorites_ext_idx` (`owner_id`,`ext`),
  KEY `favorites_idx` (`owner_id`,`peer_name_id`,`peer_server_id`,`tslice`,`vhost`)
) ENGINE=InnoDB AUTO_INCREMENT=100 DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;

--
-- Table structure for table `jorge_logger`
--

DROP TABLE IF EXISTS `jorge_logger`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `jorge_logger` (
  `id_user` int(11) default NULL,
  `id_log_detail` int(11) default NULL,
  `id_log_level` int(11) default NULL,
  `log_time` timestamp NOT NULL default CURRENT_TIMESTAMP on update CURRENT_TIMESTAMP,
  `extra` text,
  `vhost` varchar(255) default NULL,
  KEY `logger_idx` (`id_user`,`id_log_detail`,`id_log_level`,`vhost`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;

--
-- Table structure for table `jorge_logger_dict`
--

DROP TABLE IF EXISTS `jorge_logger_dict`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `jorge_logger_dict` (
  `id_event` int(11) NOT NULL auto_increment,
  `event` text,
  `lang` char(3) default NULL,
  PRIMARY KEY  (`id_event`),
  KEY `jorge_logger_dict_idx` (`id_event`,`lang`)
) ENGINE=MyISAM AUTO_INCREMENT=10 DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;

--
-- Table structure for table `jorge_logger_level_dict`
--

DROP TABLE IF EXISTS `jorge_logger_level_dict`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `jorge_logger_level_dict` (
  `id_level` int(11) NOT NULL auto_increment,
  `level` varchar(20) default NULL,
  `lang` char(3) default NULL,
  PRIMARY KEY  (`id_level`)
) ENGINE=MyISAM AUTO_INCREMENT=4 DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;

--
-- Table structure for table `jorge_mylinks`
--

DROP TABLE IF EXISTS `jorge_mylinks`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `jorge_mylinks` (
  `id_link` int(11) NOT NULL auto_increment,
  `owner_id` int(11) default NULL,
  `peer_name_id` int(11) default NULL,
  `peer_server_id` int(11) default NULL,
  `datat` text,
  `link` text,
  `description` text,
  `ext` int(11) default NULL,
  `link_id` int(11) default NULL,
  `vhost` varchar(255) default NULL,
  PRIMARY KEY  (`id_link`),
  KEY `mylinks_idx` (`owner_id`,`vhost`)
) ENGINE=InnoDB AUTO_INCREMENT=454 DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;

--
-- Table structure for table `jorge_pref`
--

DROP TABLE IF EXISTS `jorge_pref`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `jorge_pref` (
  `owner_id` int(11) default NULL,
  `pref_id` int(11) default NULL,
  `pref_value` int(11) default NULL,
  `vhost` varchar(255) default NULL,
  KEY `pref_idx` (`owner_id`,`vhost`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;

--
-- Table structure for table `jorge_stats`
--

DROP TABLE IF EXISTS `jorge_stats`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `jorge_stats` (
  `day` date default NULL,
  `hour` tinyint(4) default NULL,
  `value` int(11) default NULL,
  `vhost` varchar(255) default NULL,
  KEY `stats_idx` (`day`,`vhost`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;

--
-- Table structure for table `pending_del`
--

DROP TABLE IF EXISTS `pending_del`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `pending_del` (
  `owner_id` int(11) default NULL,
  `peer_name_id` int(11) default NULL,
  `date` varchar(20) default NULL,
  `peer_server_id` int(11) default NULL,
  `timeframe` timestamp NOT NULL default CURRENT_TIMESTAMP,
  `type` enum('chat','favorite','mylink','other') default NULL,
  `vhost` varchar(255) default NULL,
  KEY `pending_idx` (`owner_id`,`peer_name_id`,`peer_server_id`,`date`,`type`,`vhost`),
  KEY `pending_time_idx` (`timeframe`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2008-09-24 18:02:54
