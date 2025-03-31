-- MySQL dump 10.13  Distrib 8.0.32, for Win64 (x86_64)
--
-- Host: lsm-fyp-rds.cpk00i8mcpir.ap-southeast-1.rds.amazonaws.com    Database: lsm_fyp
-- ------------------------------------------------------
-- Server version	8.0.40

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!50503 SET NAMES utf8 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;
SET @MYSQLDUMP_TEMP_LOG_BIN = @@SESSION.SQL_LOG_BIN;
SET @@SESSION.SQL_LOG_BIN= 0;

--
-- GTID state at the beginning of the backup 
--

-- SET @@GLOBAL.GTID_PURGED=/*!80000 '+'*/ '';

--
-- Table structure for table `documents`
--

DROP TABLE IF EXISTS `documents`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `documents` (
  `id` varchar(36) NOT NULL,
  `name` varchar(255) NOT NULL,
  `uploadedAt` datetime DEFAULT NULL,
  `status` varchar(50) DEFAULT NULL,
  `summary` text,
  `topics` json DEFAULT NULL,
  `classification` varchar(50) DEFAULT NULL,
  `confidence` decimal(18,16) DEFAULT NULL,
  `user_corrected_category` varchar(255) DEFAULT NULL,
  `feedback` text,
  `classification_type` varchar(10),
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `users`
--

DROP TABLE IF EXISTS `users`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `users` (
  `id` int NOT NULL AUTO_INCREMENT,
  `email` varchar(255) NOT NULL,
  `password` varchar(255) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `email` (`email`)
) ENGINE=InnoDB AUTO_INCREMENT=4 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

DROP TABLE IF EXISTS `topics`;
CREATE TABLE `topics` (
    `topic_name` VARCHAR(255) NOT NULL,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `status` VARCHAR(10) NOT NULL DEFAULT 'Pending',
    PRIMARY KEY (`topic_name`)
);

INSERT INTO topics (topic_name) VALUES
('Operational'),
('Administrative'),
('Strategic'),
('Technology'),
('Market and Public Communications'),
('Regulatory and Compliance'),
('Consumer Finance'),
('Anti Money Laundering'),
('Financial Regulations'),
('Taxation'),
('Risk Management'),
('Audit Reports'),
('Legal and Contractual'),
('Employment'),
('Loans'),
('Client Agreements'),
('Non-Disclosure Agreements'),
('Derivatives'),
('Partnerships'),
('Merges and Acquisitions'),
('Financial'),
('Investments and Market Research'),
('Annual Reports');


DROP TABLE IF EXISTS `ModelState`;
CREATE TABLE `ModelState` (
    `id` INT DEFAULT 1 PRIMARY KEY,
    `state` JSON NOT NULL,
    `updatedAt` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

INSERT INTO ModelState (state) VALUES
('{"isRetraining": false}');

--
-- Dumping data for table `users`
--

LOCK TABLES `users` WRITE;
/*!40000 ALTER TABLE `users` DISABLE KEYS */;
INSERT INTO `users` VALUES (1,'mockuser@example.com','$2b$12$YHRAgL39qBzZbgZm4kglJ.Vg0ZZQkIMWkm3FjD1GnFjFGhtPjlGDi'),(3,'test@example.com','$2b$12$VWyevMtTADGOdhzEy6t3V.3bTweSFxeMSndDqpnRPqDGNvysYau32');
/*!40000 ALTER TABLE `users` ENABLE KEYS */;
UNLOCK TABLES;
SET @@SESSION.SQL_LOG_BIN = @MYSQLDUMP_TEMP_LOG_BIN;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2025-03-11 18:33:38
