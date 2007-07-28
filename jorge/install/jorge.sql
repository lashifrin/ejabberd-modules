-- SQL definitions for Jorge @ 2007 Zbyszek Zolkiewski
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
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `jorge_logger_level_dict`
--

DROP TABLE IF EXISTS `jorge_logger_level_dict`;
CREATE TABLE `jorge_logger_level_dict` (
  `id_level` int(11) NOT NULL auto_increment,
  `level` varchar(20) default NULL,
  `lang` char(3) default NULL,
  PRIMARY KEY  (`id_level`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;


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
) ENGINE=MyISAM DEFAULT CHARSET=latin1;


