/*
 Navicat Premium Data Transfer

 Source Server         : 测试油气
 Source Server Type    : SQLite
 Source Server Version : 3035005
 Source Schema         : main

 Target Server Type    : SQLite
 Target Server Version : 3035005
 File Encoding         : 65001

 Date: 12/08/2025 20:36:05
*/

PRAGMA foreign_keys = false;

-- ----------------------------
-- Table structure for Device_Motor
-- ----------------------------
DROP TABLE IF EXISTS "Device_Motor";
CREATE TABLE "Device_Motor" (
  "Type" TEXT(255),
  "power50HZ" TEXT(255),
  "voltage50HZ" TEXT(255),
  "power60HZ" TEXT(255),
  "voltage60HZ" TEXT(255),
  "electricCurrent" TEXT(255),
  "weight" TEXT(255),
  "Length" TEXT(255),
  "OutsideDiameter" TEXT(255)
);

-- ----------------------------
-- Records of Device_Motor
-- ----------------------------
INSERT INTO "Device_Motor" VALUES ('YQY107A', '20', '500', '24', '600', '39', '280', '4190.6', '107');
INSERT INTO "Device_Motor" VALUES ('YQY107A', '27.5', '710', '33', '852', '38.2', '308', '4540.6', '107');
INSERT INTO "Device_Motor" VALUES ('YQY107A', '30', '750', '36', '900', '39', '420', '5940.6', '107');
INSERT INTO "Device_Motor" VALUES ('YQY107A', '37.5', '970', '45', '1164', '38.2', '420', '5940.6', '107');
INSERT INTO "Device_Motor" VALUES ('YQY107A_Double', '50(20-30)', '1250', '60(24-36)', '1500', '39', '700', '4193.2-5961.6', '107');
INSERT INTO "Device_Motor" VALUES ('YQY107A_Double', '55(27.5-27.5)', '1420', '66(33-33)', '1704', '38.2', '616', '4543.2-4561.6', '107');
INSERT INTO "Device_Motor" VALUES ('YQY107A_Double', '65(27.5-37.5)', '1680', '78(33-45)', '2016', '38.2', '728', '4543.2-5961.6', '107');
INSERT INTO "Device_Motor" VALUES ('YQY107A_Double', '75(37.5-37.5)', '1940', '90(45-45)', '2328', '38.2', '840', '5943.2-5961.6', '107');
INSERT INTO "Device_Motor" VALUES ('YQY107B', '32.5', '865', '39', '1038', '35', '288', '4190.6', '107');
INSERT INTO "Device_Motor" VALUES ('YQY107B', '35', '970', '42', '1164', '35', '316.8', '4540.6', '107');
INSERT INTO "Device_Motor" VALUES ('YQY107B', '46', '1300', '55.2', '1560', '35', '432', '5940.6', '107');
INSERT INTO "Device_Motor" VALUES ('YQY107B_Double', '65(32.5-32.5)', '1730', '78(35-35)', '2076', '35', '576', '4193.2-4211.6', '107');
INSERT INTO "Device_Motor" VALUES ('YQY107B_Double', '70(35-35)', '1940', '84(42-42)', '2328', '35', '633.6', '4543.2-4561.6', '107');
INSERT INTO "Device_Motor" VALUES ('YQY114A', '12.5', '350', '15', '420', '31', '108', '2245.9', '114');
INSERT INTO "Device_Motor" VALUES ('YQY114A', '18.4', '616', '22.1', '739', '27', '162', '3014.7', '114');
INSERT INTO "Device_Motor" VALUES ('YQY114A', '21.3', '800', '25.6', '960', '24', '189', '3399.1', '114');
INSERT INTO "Device_Motor" VALUES ('YQY114A', '24.3', '804', '29.2', '965', '27', '216', '3783.5', '114');
INSERT INTO "Device_Motor" VALUES ('YQY114A', '30.9', '1000', '37.1', '1200', '27', '270', '4552.3', '114');
INSERT INTO "Device_Motor" VALUES ('YQY114A', '37', '1200', '44.4', '1440', '27', '324', '5321.1', '114');
INSERT INTO "Device_Motor" VALUES ('YQY114A', '40', '820', '48', '984', '43', '351', '5705.5', '114');
INSERT INTO "Device_Motor" VALUES ('YQY114A_Double_高电压', '46', '1535', '55.2', '1842', '27', '405', '6474.3', '114');
INSERT INTO "Device_Motor" VALUES ('YQY114A_Double_低电压', '46', '945', '55.2', '1134', '43', '405', '6474.3', '114');
INSERT INTO "Device_Motor" VALUES ('YQY114A_Double_高电压', '52', '1733', '62.4', '2080', '27', '459', '7243.1', '114');
INSERT INTO "Device_Motor" VALUES ('YQY114A_Double_低电压', '52', '1075', '62.4', '1290', '43', '459', '7243.1', '114');
INSERT INTO "Device_Motor" VALUES ('YQY114A_Double_高电压', '61', '1200', '73.2', '1440', '43', '540', '8396.3', '114');
INSERT INTO "Device_Motor" VALUES ('YQY114A_Double_低电压', '61', '958', '73.2', '1150', '56', '540', '8396.3', '114');
INSERT INTO "Device_Motor" VALUES ('YQY114A_Double_高电压', '73.5', '1150', '88.2', '1380', '64', '648	', '9933.9', '114');
INSERT INTO "Device_Motor" VALUES ('YQY114A_Double_低电压', '73.5', '1000', '88.2', '1200', '56', '648	', '9933.9', '114');
INSERT INTO "Device_Motor" VALUES ('YQY114B', '33', '852', '39.6', '1022', '35', '193.2', '3399.1', '114');
INSERT INTO "Device_Motor" VALUES ('YQY114B', '38', '975', '45.6', '1170', '35', '220.8', '3783.5', '114');
INSERT INTO "Device_Motor" VALUES ('YQY114B', '42.5', '1098', '51', '1318', '35', '248.4', '4167.9', '114');
INSERT INTO "Device_Motor" VALUES ('YQY114B', '47', '946', '56.4', '1135', '45', '276', '4552.3', '114');
INSERT INTO "Device_Motor" VALUES ('YQY114B', '52', '1040', '62.4', '1248', '45', '303.6', '4936.7', '114');
INSERT INTO "Device_Motor" VALUES ('YQY114B', '61', '1230', '73.2', '1476', '45', '358.8', '5705.5', '114');
INSERT INTO "Device_Motor" VALUES ('YQY114B', '65.5', '1320', '78.6', '1584', '45', '386.4', '6089.9', '114');
INSERT INTO "Device_Motor" VALUES ('YQY114B_Double_高电压', '71', '1500', '85.2', '1800', '45', '414', '6474.3', '114');
INSERT INTO "Device_Motor" VALUES ('YQY114B_Double_低电压', '71', '1008', '85.2', '1210', '64', '414', '6474.3', '114');
INSERT INTO "Device_Motor" VALUES ('YQY114B_Double_高电压', '81', '1380', '97.2', '1656', '53', '469.2', '7243.1', '114');
INSERT INTO "Device_Motor" VALUES ('YQY114B_Double_低电压', '81', '1142', '97.2', '1370', '64', '469.2', '7243.1', '114');
INSERT INTO "Device_Motor" VALUES ('YQY114B_Double_高电压', '81', '1380', '97.2', '1656', '53', '469.2', '7243.1', '114');
INSERT INTO "Device_Motor" VALUES ('YQY114B_Double_低电压', '81', '1142', '97.2', '1370', '64', '469.2', '7243.1', '114');
INSERT INTO "Device_Motor" VALUES ('YQY114B_Double_高电压', '88', '1994', '105.6', '2393', '45', '552', '8396.3', '114');
INSERT INTO "Device_Motor" VALUES ('YQY114B_Double_低电压', '88', '1700', '105.6', '2040', '45', '552', '8396.3', '114');
INSERT INTO "Device_Motor" VALUES ('YQY114B_Double_高电压', '103', '1780', '123.6', '2136', '53', '607.2', '9165.1', '114');
INSERT INTO "Device_Motor" VALUES ('YQY114B_Double_低电压', '103', '1620', '123.6', '1944', '53', '607.2', '9165.1', '114');
INSERT INTO "Device_Motor" VALUES ('YQY114B_Double_高电压', '113', '1950', '135.6', '2340', '53', '662.4', '9933.9', '114');
INSERT INTO "Device_Motor" VALUES ('YQY114B_Double_低电压', '113', '1008', '135.6', '1210', '64', '662.4', '9933.9', '114');
INSERT INTO "Device_Motor" VALUES ('YQY138', '45', '900', '54', '1080', '45', '300', '2897.9', '138');
INSERT INTO "Device_Motor" VALUES ('YQY138', '55', '0', '0', '0', '0', '0', '0', '138');
INSERT INTO "Device_Motor" VALUES ('YQY138', '64', '0', '0', '0', '0', '0', '0', '138');
INSERT INTO "Device_Motor" VALUES ('YQY138', '72', '0', '0', '0', '0', '0', '0', '138');
INSERT INTO "Device_Motor" VALUES ('YQY138', '81', '0', '0', '0', '0', '0', '0', '138');
INSERT INTO "Device_Motor" VALUES ('YQY138', '90', '0', '0', '0', '0', '0', '0', '138');
INSERT INTO "Device_Motor" VALUES ('YQY138', '102', '0', '0', '0', '0', '0', '0', '138');
INSERT INTO "Device_Motor" VALUES ('YQY138', '110', '0', '0', '0', '0', '0', '0', '138');
INSERT INTO "Device_Motor" VALUES ('YQY138', '126', '0', '0', '0', '0', '0', '0', '138');
INSERT INTO "Device_Motor" VALUES ('YQY138_Double', '138', '0', '165.6', '0', '0', '0', '0', '138');
INSERT INTO "Device_Motor" VALUES ('YQY138_Double', '157', '0', '188.4', '0', '0', '0', '0', '138');
INSERT INTO "Device_Motor" VALUES ('YQY138_Double', '157', '0', '188.4', '0', '0', '0', '0', '138');
INSERT INTO "Device_Motor" VALUES ('YQY138_Double', '174', '0', '220.8', '0', '0', '0', '0', '138');
INSERT INTO "Device_Motor" VALUES ('YQY138_Double', '184', '0', '220.8', '0', '0', '0', '0', '138');
INSERT INTO "Device_Motor" VALUES ('YQY138_Double', '193', '0', '231.6', '0', '0', '0', '0', '138');
INSERT INTO "Device_Motor" VALUES ('YQY143_Double', '280', '2320', '336', '2784', '96', '1680', '6669', '147');

PRAGMA foreign_keys = true;
