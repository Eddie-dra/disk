-- MySQL dump 10.13  Distrib 8.0.33, for Linux (x86_64)
--
-- Host: 127.0.0.1    Database: bigcorp
-- ------------------------------------------------------
-- Server version	8.3.0

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!50503 SET NAMES utf8mb4 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

--
-- Table structure for table `users`
--

DROP TABLE IF EXISTS `users`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `users` (
  `id` int NOT NULL AUTO_INCREMENT,
  `first_name` varchar(50) DEFAULT NULL,
  `last_name` varchar(50) DEFAULT NULL,
  `hash` varchar(255) DEFAULT NULL,
  `salt` varchar(50) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=51 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `users`
--

LOCK TABLES `users` WRITE;
/*!40000 ALTER TABLE `users` DISABLE KEYS */;
INSERT INTO `users` VALUES (1,'Diana','Pace','aa2c7fca38895cec18223aae5782d50f','b9c294366eab9644b4a9d117d2f30169'),(2,'Nanette','Wall','ad573b6cbe3ef40128c866e04e80128e','be324d466e9ed65b1f5bf0ccb769cb1a'),(3,'Allie','Petersen','40e0e6cb2f197c45102ee9a3d1485884','91a646fa333fbcc9963d3fa66aba3b9a'),(4,'Ellsworth','Zuniga','7b02b29678ea4d3864c4d7d9f574a9ed','848e57db0af826a0fd4015f93c726cb5'),(5,'Tara','Stone','5df2ee218ae1a48e2b97cf15faeea70d','039cedcb1916dc6d13cf4155b00f8513'),(6,'Lacy','Howe','1be433927e4ae99a6614f3675639ee39','c60b4ab78618298c3722a776b2fe730c'),(7,'Nathanael','Mcconnell','5f99bc6bee49fe1e2ec021541459e81f','d6297ff7310551b3f325cbac71138655'),(8,'Cleo','Powers','4cbe3ab502c676e8bc692a652f72ff0e','ec856e063a88d154bae9cd08b1c8eb5b'),(9,'Callie','Zimmerman','eb97dc96e0e3e553f506376984372d05','d2ac6f089b850d28ffc05140df18dc58'),(10,'Willy','Adkins','7bf54cee518180da950b547c75e61c61','6094da29e26e34f0bbac2edd368292f8'),(11,'Sheri','Yates','599fb9ff25d7f229fa499493321e83ec','b361e0ddda23c367dab5a7a6483ef674'),(12,'Isabelle','Richards','00e974374e2f4f42638b1cc6511e0fca','4972eed63ec816aab8d5be9085fc76da'),(13,'Lawanda','Rogers','461e74cd4aee197ee25f582fc6a6a6c3','da7d43e8e28caacbc38c71657728e86b'),(14,'Branden','Compton','4ab64a0b21e5e608c1c33c283a734d87','9dc2ad748f19034bcda4c18d4fc2b9f6'),(15,'Darrell','Chapman','8170888219671e8a475ebf2ea389250f','24f62c412ed8ea07a50f0c32d0e6e46e'),(16,'Dick','Gentry','df5c870197ced4dd035b724c1726960c','5d1bbb59be1a61ca409973d6125813cc'),(17,'Isabel','Flynn','e8d76ee086b41a18deedcd9e982a5670','0f333ca4d47dfd4e94a4eb07139cab71'),(18,'Monroe','Kaufman','629d329c08115eeb2be272ecebae3eec','c842fff45395bd19b36fceecd5a3584e'),(19,'Nicole','Roy','386ddc0e1f2f882430064e97548238d9','b1c21543413f44ef1d5bd62743c66293'),(20,'Glenda','Cannon','2eee8916ce6492c6e39dd307c7b1f5f7','291e47b4d90d72c1e9a3b3217a791493'),(21,'Millard','Yang','2c101f9e944f0e197954bce2c07f6876','3f28bd11a2388e4db4439670f04f3d5f'),(22,'Lara','Hatfield','1e35fee860b72ecf5d3d633d9d9d655f','c7c12e5e2c48ac6a0e46e3c9ac3fa0e1'),(23,'Bobbie','Church','56035ba57c68a5d6298bac2928b31abc','13c0002926ca4cd992f9b870fa1ec30f'),(24,'Olive','Luna','4a4415f218123d5d3a5cd3377fa4c4fa','4f689bac81818f82aaa75a5c69501abd'),(25,'Laverne','Potts','d1c2dfd6e400281af0d51482b6292ac7','d2e734c2bce9698ea4cffa6dc156a426'),(26,'Susie','Krueger','a1b1ce40b4d26bf5427c04c315e84e65','6aa408edd967247b70237c0ae3f065b7'),(27,'Damien','Jenkins','9f9d653c6a8cd5548d1667cce1602439','45446bf86edf5ad7627d9324e015e558'),(28,'Markus','Zhang','fc37175d9df7c63818e7dcd38d740b96','00b5d3b406e6dff9438ca3794b1baf4a'),(29,'Leslie','Conley','a1ad941b606e6dd7e608271b778cd2a6','5dcdab6b72c6e2ca1c39acf5ab9d2bd1'),(30,'Terrell','Matthews','1f00e1db67f6e659e9efe2071bc76558','69396bc3f4aa40d1f49c202ac277128d'),(31,'Ronny','Henderson','1472a898aac46ab40f3d2731d630b096','cae5bceb044fb3cfc5d54783464e1f4b'),(32,'Gonzalo','Ward','8b7fc076e8a85d563cc22f3a4c781b72','a931ec4de5caeca605d8df2b78c9ce90'),(33,'Erin','Glover','d809ab64ddd9a727fa07ba4b02eeb42c','b9e454b84a9ac734949245c37223016f'),(34,'Mary','Melton','a79079c52c495448dad8279f1eca935b','f7378c440e101d3b2c5fb8a705927232'),(35,'Margery','Santana','8dac3b3508f2ea66604dde84b42bdeb5','f74affbcd75a84599bda778490057dfd'),(36,'Christie','Nixon','2a3cf5b313adcb95e52faf6ee8f1ddfa','1329d3bcf6c195377b4cc43d14cc4352'),(37,'Jennifer','Medina','9782fb92e46dd895f773faa07cf06fbf','35d4460afb5df8f8939670a997ea5000'),(38,'Marianne','Webb','e036463380e3b50a6d153d50fd930589','103ecc55f3965acea7bd5caaf27034c6'),(39,'Ramon','Wilcox','60a633cbe65ed3897cda728c460de1ef','1c583ab7a1a44b00f96276e6587677b1'),(40,'Alec','Horton','91e5ba6408bd8528234ca6df528efcd3','ca3bb4bce2e277675ca0fa95bd57abf5'),(41,'Roberto','Greene','b323ca64caa1c573964363cf590e1933','a8dcad922fb6542b5832ae01ad214f43'),(42,'Oren','Mahoney','600e55cfb77df932f3297e6f6bf7ce5d','6612fd5d0c18d64dca96601b429b3ecc'),(43,'Lesley','Stafford','c35cbdc998f5d4dffe895533b2a45a1a','756c9af9bc12855b1ab0e3892c0d8cd6'),(44,'Melissa','Dennis','9df5df7768f28357acf42efc6dbd9b45','60ba7fee820fcec77e08b30fa2ad5c78'),(45,'Lavonne','Bradshaw','3c21b5c8212f0a884bd94dfe76e708ae','5db6432c4d30c92df0123aa8f95c7c4a'),(46,'Sidney','Glenn','17c8855ffb9469c5f37578d702b63b8b','ebb9cb2840d6ca82cede895cc6048d00'),(47,'Dane','Berry','0027365e3c239554f9674d599375f10c','dc664139914a296dd210016f41c29f41'),(48,'Johnathan','Chambers','4032429d812e9b0a076d0d2539db9f42','921978d46563a20441551b9add75094d'),(49,'Kirk','Sherman','02f0845b3973563659a5f20fc3c24c2e','356d13ab6e00ce4c17653630e0dabfc1'),(50,'Elva','Baxter','5bfe7124490dd9a835edea3571a8256b','5db80705c809fe2b0e0ad983c463d24d');
/*!40000 ALTER TABLE `users` ENABLE KEYS */;
UNLOCK TABLES;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2024-03-06 13:56:33
