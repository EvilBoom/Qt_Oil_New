/*
 Navicat Premium Data Transfer

 Source Server         : 测试油气
 Source Server Type    : SQLite
 Source Server Version : 3035005
 Source Schema         : main

 Target Server Type    : SQLite
 Target Server Version : 3035005
 File Encoding         : 65001

 Date: 12/08/2025 20:36:17
*/

PRAGMA foreign_keys = false;

-- ----------------------------
-- Table structure for Device_Separator
-- ----------------------------
DROP TABLE IF EXISTS "Device_Separator";
CREATE TABLE "Device_Separator" (
  "OuterDiameter" TEXT(255),
  "Length" TEXT(255),
  "Weigth" TEXT(255)
);

-- ----------------------------
-- Records of Device_Separator
-- ----------------------------
INSERT INTO "Device_Separator" VALUES ('98吸入口', '295', '6');
INSERT INTO "Device_Separator" VALUES ('130吸入口', '300', '10');
INSERT INTO "Device_Separator" VALUES ('98单分', '825.5', '26');
INSERT INTO "Device_Separator" VALUES ('98双分', '1332', '45');
INSERT INTO "Device_Separator" VALUES ('130单分', '947', '58');

PRAGMA foreign_keys = true;
