/*
 Navicat Premium Data Transfer

 Source Server         : 测试油气
 Source Server Type    : SQLite
 Source Server Version : 3035005
 Source Schema         : main

 Target Server Type    : SQLite
 Target Server Version : 3035005
 File Encoding         : 65001

 Date: 12/08/2025 20:36:11
*/

PRAGMA foreign_keys = false;

-- ----------------------------
-- Table structure for Device_Protector
-- ----------------------------
DROP TABLE IF EXISTS "Device_Protector";
CREATE TABLE "Device_Protector" (
  "OuterDiameter" TEXT(255),
  "Length" TEXT(255),
  "Weigth" TEXT(255),
  "PS" TEXT(255)
);

-- ----------------------------
-- Records of Device_Protector
-- ----------------------------
INSERT INTO "Device_Protector" VALUES ('95', '3522', '/', '连114电机');
INSERT INTO "Device_Protector" VALUES ('98', '3406.2', '140', NULL);
INSERT INTO "Device_Protector" VALUES ('98', '3397.2', '140', '连107电机');
INSERT INTO "Device_Protector" VALUES ('130', '3883', '238', NULL);
INSERT INTO "Device_Protector" VALUES (NULL, NULL, NULL, NULL);

PRAGMA foreign_keys = true;
