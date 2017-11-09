DROP TABLE IF EXISTS `abusers`;
CREATE TABLE `abusers` (
  `abuser_id` smallint(5) unsigned NOT NULL AUTO_INCREMENT,
  `abuser_name` varchar(32) NOT NULL,
  PRIMARY KEY (`abuser_id`),
  UNIQUE KEY `abuser_name` (`abuser_name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

--
-- Table structure for table `abusers_edits`
--

DROP TABLE IF EXISTS `abusers_edits`;
CREATE TABLE `abusers_edits` (
  `ae_edit` int(10) unsigned NOT NULL,
  `ae_score` mediumint(11) DEFAULT NULL,
  `ae_abuser` smallint(5) unsigned DEFAULT NULL,
  `ae_confirmed` tinyint(4) NOT NULL,
  PRIMARY KEY (`ae_edit`),
  KEY `edit_score` (`ae_edit`,`ae_score`),
  CONSTRAINT `abusers_edits_ibfk_1` FOREIGN KEY (`ae_edit`) REFERENCES `revisions` (`rev_pk`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

--
-- Table structure for table `projects`
--

DROP TABLE IF EXISTS `projects`;
CREATE TABLE `projects` (
  `project_id` smallint(5) unsigned NOT NULL AUTO_INCREMENT,
  `project_name` varchar(255) NOT NULL,
  PRIMARY KEY (`project_id`),
  UNIQUE KEY `project_name` (`project_name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

--
-- Table structure for table `revisions`
--

DROP TABLE IF EXISTS `revisions`;
CREATE TABLE `revisions` (
  `rev_pk` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `rev_project` smallint(6) unsigned NOT NULL,
  `rev_id` int(11) unsigned NOT NULL,
  `rev_text` int(11) unsigned DEFAULT NULL,
  `rev_timestamp` timestamp NULL DEFAULT NULL,
  `rev_comment` varchar(255) DEFAULT NULL,
  `rev_user_id` int(11) unsigned DEFAULT NULL,
  `rev_user_text` varchar(255) DEFAULT NULL,
  `rev_parent_id` int(11) unsigned DEFAULT NULL,
  `rev_page` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`rev_pk`),
  UNIQUE KEY `rev_project_id` (`rev_project`,`rev_id`),
  KEY `rev_id` (`rev_id`),
  KEY `rev_text` (`rev_text`),
  KEY `rev_page` (`rev_page`),
  CONSTRAINT `revisions_ibfk_1` FOREIGN KEY (`rev_text`) REFERENCES `texts` (`text_id`),
  CONSTRAINT `revisions_ibfk_2` FOREIGN KEY (`rev_project`) REFERENCES `projects` (`project_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

--
-- Table structure for table `texts`
--

DROP TABLE IF EXISTS `texts`;
CREATE TABLE `texts` (
  `text_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `text_content` mediumblob NOT NULL,
  `text_encoding` tinyint(3) unsigned NOT NULL,
  `text_len` int(10) unsigned NOT NULL,
  `text_sha1` binary(20) NOT NULL,
  PRIMARY KEY (`text_id`),
  KEY `text_sha1` (`text_sha1`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
