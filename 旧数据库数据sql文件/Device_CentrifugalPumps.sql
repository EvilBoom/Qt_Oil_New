/*
 Navicat Premium Data Transfer

 Source Server         : 测试油气
 Source Server Type    : SQLite
 Source Server Version : 3035005
 Source Schema         : main

 Target Server Type    : SQLite
 Target Server Version : 3035005
 File Encoding         : 65001

 Date: 12/08/2025 20:35:58
*/

PRAGMA foreign_keys = false;

-- ----------------------------
-- Table structure for Device_CentrifugalPumps
-- ----------------------------
DROP TABLE IF EXISTS "Device_CentrifugalPumps";
CREATE TABLE "Device_CentrifugalPumps" (
  "ImpellerModel" TEXT NOT NULL,
  "Displacement" TEXT NOT NULL,
  "SingleStageHead" TEXT NOT NULL,
  "SingleStagePower" TEXT NOT NULL,
  "ShaftDiameter" TEXT NOT NULL,
  "MountingHeight" TEXT NOT NULL,
  "OutsideDiameter" TEXT DEFAULT 102,
  PRIMARY KEY ("ImpellerModel", "Displacement", "SingleStageHead", "SingleStagePower", "ShaftDiameter", "MountingHeight")
);

-- ----------------------------
-- Records of Device_CentrifugalPumps
-- ----------------------------
INSERT INTO "Device_CentrifugalPumps" VALUES ('DN3000', '300', '4.3', '0.29', '22.2', '57', '102');
INSERT INTO "Device_CentrifugalPumps" VALUES ('DN3000', '350', '3.85', '0.29', '22.2', '57', '102');
INSERT INTO "Device_CentrifugalPumps" VALUES ('DN3000', '400', '3.5', '0.29', '22.2', '57', '102');
INSERT INTO "Device_CentrifugalPumps" VALUES ('DN4300反向', '500', '4.9', '0.48', '22.2', '94', '102');
INSERT INTO "Device_CentrifugalPumps" VALUES ('DN4300反向', '550', '4.8', '0.49', '22.2', '94', '102');
INSERT INTO "Device_CentrifugalPumps" VALUES ('DN4300反向', '600', '4.5', '0.51', '22.2', '94', '102');
INSERT INTO "Device_CentrifugalPumps" VALUES ('DN6000-反向', '500', '4.9', '0.53', '22.2', '94', '102');
INSERT INTO "Device_CentrifugalPumps" VALUES ('DN6000-反向', '550', '4.8', '0.58', '22.2', '94', '102');
INSERT INTO "Device_CentrifugalPumps" VALUES ('DN6000-反向', '600', '4.8', '0.6', '22.2', '94', '102');
INSERT INTO "Device_CentrifugalPumps" VALUES ('DN6000-反向', '636', '4.7', '0.6', '22.2', '94', '102');
INSERT INTO "Device_CentrifugalPumps" VALUES ('DN6000-反向', '700', '4.5', '0.612', '22.2', '94', '102');
INSERT INTO "Device_CentrifugalPumps" VALUES ('DN6000-反向', '800', '4', '0.63', '22.2', '94', '102');
INSERT INTO "Device_CentrifugalPumps" VALUES ('TL-100', '100', '6.8', '0.132', '17.4', '25.4', '102');
INSERT INTO "Device_CentrifugalPumps" VALUES ('TL-100', '120', '6.1', '0.15', '17.4', '25.4', '102');
INSERT INTO "Device_CentrifugalPumps" VALUES ('TL-100', '70', '7.1', '0.132', '17.4', '25.4', '102');
INSERT INTO "Device_CentrifugalPumps" VALUES ('TL-100', '80', '7', '0.132', '17.4', '25.4', '102');
INSERT INTO "Device_CentrifugalPumps" VALUES ('TL-100', '90', '6.9', '0.132', '17.4', '25.4', '102');
INSERT INTO "Device_CentrifugalPumps" VALUES ('TL-150', '120', '6.87', '0.177', '17.4', '24', '102');
INSERT INTO "Device_CentrifugalPumps" VALUES ('TL-150', '125', '6.75', '0.18', '17.4', '24', '102');
INSERT INTO "Device_CentrifugalPumps" VALUES ('TL-150', '150', '6.5', '0.1963', '17.4', '24', '102');
INSERT INTO "Device_CentrifugalPumps" VALUES ('TL-150', '160', '6.3', '0.2', '17.4', '24', '102');
INSERT INTO "Device_CentrifugalPumps" VALUES ('TL-150', '170', '6.18', '0.21', '17.4', '24', '102');
INSERT INTO "Device_CentrifugalPumps" VALUES ('TL-150', '200', '5.15', '0.2286', '17.4', '24', '102');
INSERT INTO "Device_CentrifugalPumps" VALUES ('TL-150', '80', '6.8', '0.15', '17.4', '24', '102');
INSERT INTO "Device_CentrifugalPumps" VALUES ('TL-150-big', '100', '7', '0.17', '22.2', '32', '102');
INSERT INTO "Device_CentrifugalPumps" VALUES ('TL-150-big', '120', '7', '0.17', '22.2', '32', '102');
INSERT INTO "Device_CentrifugalPumps" VALUES ('TL-150-big', '125', '6.8', '0.18', '22.2', '32', '102');
INSERT INTO "Device_CentrifugalPumps" VALUES ('TL-150-big', '130', '6.7', '0.19', '22.2', '32', '102');
INSERT INTO "Device_CentrifugalPumps" VALUES ('TL-150-big', '150', '6.5', '0.2', '22.2', '32', '102');
INSERT INTO "Device_CentrifugalPumps" VALUES ('TL-150-big', '60', '7', '0.14', '22.2', '32', '102');
INSERT INTO "Device_CentrifugalPumps" VALUES ('TL-150-big', '75', '7', '0.17', '22.2', '32', '102');
INSERT INTO "Device_CentrifugalPumps" VALUES ('TL-150-big', '80', '7', '0.15', '22.2', '32', '102');
INSERT INTO "Device_CentrifugalPumps" VALUES ('TL-20', '15', '4.7', '0.04', '15.875', '20.75', '102');
INSERT INTO "Device_CentrifugalPumps" VALUES ('TL-200', '150', '6.4', '0.21', '22.2', '36', '102');
INSERT INTO "Device_CentrifugalPumps" VALUES ('TL-200', '160', '6.5', '0.217', '22.2', '36', '102');
INSERT INTO "Device_CentrifugalPumps" VALUES ('TL-200', '170', '6.45', '0.23', '22.2', '36', '102');
INSERT INTO "Device_CentrifugalPumps" VALUES ('TL-200', '175', '6.4', '0.23', '22.2', '36', '102');
INSERT INTO "Device_CentrifugalPumps" VALUES ('TL-200', '180', '6.35', '0.23', '22.2', '36', '102');
INSERT INTO "Device_CentrifugalPumps" VALUES ('TL-200', '190', '6.2', '0.233', '22.2', '36', '102');
INSERT INTO "Device_CentrifugalPumps" VALUES ('TL-200', '200', '6.1', '0.24', '22.2', '36', '102');
INSERT INTO "Device_CentrifugalPumps" VALUES ('TL-200', '250', '5', '0.2737', '22.2', '36', '102');
INSERT INTO "Device_CentrifugalPumps" VALUES ('TL-200', '60', '6.55', '0.16', '22.2', '36', '102');
INSERT INTO "Device_CentrifugalPumps" VALUES ('TL-200', '75', '7', '0.2026', '22.2', '36', '102');
INSERT INTO "Device_CentrifugalPumps" VALUES ('TL-20反向', '20', '4.3', '0.04', '17.4', '24.2', '102');
INSERT INTO "Device_CentrifugalPumps" VALUES ('TL-250', '200', '6', '0.25', '22.2', '40', '102');
INSERT INTO "Device_CentrifugalPumps" VALUES ('TL-250', '250', '5.5', '0.25', '22.2', '40', '102');
INSERT INTO "Device_CentrifugalPumps" VALUES ('TL-250', '265', '5.2', '0.26', '22.2', '40', '102');
INSERT INTO "Device_CentrifugalPumps" VALUES ('TL-250', '300', '4.3', '0.26', '22.2', '40', '102');
INSERT INTO "Device_CentrifugalPumps" VALUES ('TL-300正向', '200', '5.6', '0.24', '22.2', '40', '102');
INSERT INTO "Device_CentrifugalPumps" VALUES ('TL-300正向', '238', '5.3', '0.25', '22.2', '40', '102');
INSERT INTO "Device_CentrifugalPumps" VALUES ('TL-300正向', '250', '5.2', '0.26', '22.2', '40', '102');
INSERT INTO "Device_CentrifugalPumps" VALUES ('TL-300正向', '280', '4.8', '0.265', '22.2', '40', '102');
INSERT INTO "Device_CentrifugalPumps" VALUES ('TL-300正向', '300', '4.5', '0.27', '22.2', '40', '102');
INSERT INTO "Device_CentrifugalPumps" VALUES ('TL-300正向', '320', '4.2', '0.29', '22.2', '40', '102');
INSERT INTO "Device_CentrifugalPumps" VALUES ('TL-30顺向', '30', '5.5', '0.052', '17.4', '22.5', '102');
INSERT INTO "Device_CentrifugalPumps" VALUES ('TL-400 反向', '300', '4.2', '0.26', '22.2', '57.2', '102');
INSERT INTO "Device_CentrifugalPumps" VALUES ('TL-400 反向', '330', '4', '0.27', '22.2', '57.2', '102');
INSERT INTO "Device_CentrifugalPumps" VALUES ('TL-400 反向', '350', '3.9', '0.28', '22.2', '57.2', '102');
INSERT INTO "Device_CentrifugalPumps" VALUES ('TL-400 反向', '400', '3.8', '0.34', '22.2', '57.2', '102');
INSERT INTO "Device_CentrifugalPumps" VALUES ('TL-500', '400', '4.8', '0.4', '22.2', '93.7', '102');
INSERT INTO "Device_CentrifugalPumps" VALUES ('TL-500', '450', '4.6', '0.425', '22.2', '93.7', '102');
INSERT INTO "Device_CentrifugalPumps" VALUES ('TL-500', '480', '4.5', '0.44', '22.2', '93.7', '102');
INSERT INTO "Device_CentrifugalPumps" VALUES ('TL-500', '500', '4.4', '0.44', '22.2', '93.7', '102');
INSERT INTO "Device_CentrifugalPumps" VALUES ('TL-500', '600', '3.9', '0.4682', '22.2', '93.7', '102');
INSERT INTO "Device_CentrifugalPumps" VALUES ('TL-70', '100', '5.5', '0.1134', '17.4', '27', '102');
INSERT INTO "Device_CentrifugalPumps" VALUES ('TL-70', '30', '6.95', '0.1', '17.4', '27', '102');
INSERT INTO "Device_CentrifugalPumps" VALUES ('TL-70', '50', '7.1', '0.1', '17.4', '27', '102');
INSERT INTO "Device_CentrifugalPumps" VALUES ('TL-70', '60', '6.9', '0.1', '17.4', '27', '102');
INSERT INTO "Device_CentrifugalPumps" VALUES ('TL-70', '65', '6.85', '0.1023', '17.4', '27', '102');
INSERT INTO "Device_CentrifugalPumps" VALUES ('TL-70', '70', '6.8', '0.1023', '17.4', '27', '102');
INSERT INTO "Device_CentrifugalPumps" VALUES ('TL-70', '75', '6.6', '0.1063', '17.4', '27', '102');
INSERT INTO "Device_CentrifugalPumps" VALUES ('TL-70', '80', '6.5', '0.1063', '17.4', '27', '102');
INSERT INTO "Device_CentrifugalPumps" VALUES ('TL-70', '83', '6.2', '0.111', '17.4', '27', '102');
INSERT INTO "Device_CentrifugalPumps" VALUES ('TL-60', '50', '10.3', '0.1606', '17.4', '23.7', '130');
INSERT INTO "Device_CentrifugalPumps" VALUES ('TL-60', '60', '9.8', '0.1703', '17.4', '23.7', '130');
INSERT INTO "Device_CentrifugalPumps" VALUES ('QN200', '150', '11.7', '0.37', '22.2', '25.8', '130');
INSERT INTO "Device_CentrifugalPumps" VALUES ('QN200', '200', '10.6', '0.4', '22.2', '25.8', '130');
INSERT INTO "Device_CentrifugalPumps" VALUES ('QN200', '240', '9.4', '0.42', '22.2', '25.8', '130');
INSERT INTO "Device_CentrifugalPumps" VALUES ('GN2500', '320', '8.5', '0.57', '22.2', '35', '130');
INSERT INTO "Device_CentrifugalPumps" VALUES ('TL-300', '300', '8.2', '0.515', '25.4', '35', '130');
INSERT INTO "Device_CentrifugalPumps" VALUES ('TL-300', '350', '6.5', '0.52', '25.4', '35', '130');
INSERT INTO "Device_CentrifugalPumps" VALUES ('QN300', '200', '11.1', '0.53', '22.2', '35', '130');
INSERT INTO "Device_CentrifugalPumps" VALUES ('QN300', '250', '10.7', '0.53', '22.2', '35', '130');
INSERT INTO "Device_CentrifugalPumps" VALUES ('QN300', '265', '10.6', '0.53', '22.2', '35', '130');
INSERT INTO "Device_CentrifugalPumps" VALUES ('QN300', '290', '10.3', '0.53', '22.2', '35', '130');
INSERT INTO "Device_CentrifugalPumps" VALUES ('QN300', '300', '10.2', '0.53', '22.2', '35', '130');
INSERT INTO "Device_CentrifugalPumps" VALUES ('QN300', '320', '9.9', '0.53', '22.2', '35', '130');
INSERT INTO "Device_CentrifugalPumps" VALUES ('QN300', '350', '9.25', '0.6', '22.2', '35', '130');
INSERT INTO "Device_CentrifugalPumps" VALUES ('QN300', '360', '9', '0.67', '22.2', '35', '130');
INSERT INTO "Device_CentrifugalPumps" VALUES ('GN3100', '400', '8', '0.6072', '22.2', '35', '130');
INSERT INTO "Device_CentrifugalPumps" VALUES ('TL400', '400', '8.2', '0.6417', '25.4', '35', '130');
INSERT INTO "Device_CentrifugalPumps" VALUES ('TLST400', '400', '10.2', '0.78', '25.4', '59', '130');
INSERT INTO "Device_CentrifugalPumps" VALUES ('TLST450', '300', '11.1', '0.66', '25.4', '59', '130');
INSERT INTO "Device_CentrifugalPumps" VALUES ('TLST450', '350', '11', '0.73', '25.4', '59', '130');
INSERT INTO "Device_CentrifugalPumps" VALUES ('TLST450', '360', '10.8', '0.747', '25.4', '59', '130');
INSERT INTO "Device_CentrifugalPumps" VALUES ('TLST450', '400', '10.4', '0.8', '25.4', '59', '130');
INSERT INTO "Device_CentrifugalPumps" VALUES ('TLST450', '450', '10', '0.88', '25.4', '59', '130');
INSERT INTO "Device_CentrifugalPumps" VALUES ('TLST450', '500', '9.6', '0.94', '25.4', '59', '130');
INSERT INTO "Device_CentrifugalPumps" VALUES ('GN4000', '400', '8.5', '0.7', '25.4', '63.5', '130');
INSERT INTO "Device_CentrifugalPumps" VALUES ('GN4000', '450', '8.1', '0.7', '25.4', '63.5', '130');
INSERT INTO "Device_CentrifugalPumps" VALUES ('GN4000', '480', '7.9', '0.7', '25.4', '63.5', '130');
INSERT INTO "Device_CentrifugalPumps" VALUES ('GN4000', '500', '7.6', '0.7', '25.4', '63.5', '130');
INSERT INTO "Device_CentrifugalPumps" VALUES ('GN4000', '520', '7.6', '0.73', '25.4', '63.5', '130');
INSERT INTO "Device_CentrifugalPumps" VALUES ('GN4000', '530', '7.3', '0.74', '25.4', '63.5', '130');
INSERT INTO "Device_CentrifugalPumps" VALUES ('GN4000', '550', '7.1', '0.74', '25.4', '63.5', '130');
INSERT INTO "Device_CentrifugalPumps" VALUES ('GN4000', '600', '6.5', '0.75', '25.4', '63.5', '130');
INSERT INTO "Device_CentrifugalPumps" VALUES ('GN5200', '600', '7.2', '0.83', '25.4', '92.1', '130');
INSERT INTO "Device_CentrifugalPumps" VALUES ('GN5200', '650', '6.8', '0.87', '25.4', '92.1', '130');
INSERT INTO "Device_CentrifugalPumps" VALUES ('GN5200', '700', '6.5', '0.87', '25.4', '92.1', '130');
INSERT INTO "Device_CentrifugalPumps" VALUES ('GN5200', '800', '5.6', '0.88', '25.4', '92.1', '130');
INSERT INTO "Device_CentrifugalPumps" VALUES ('GN5600', '700', '6.3', '0.8', '25.4', '92.1', '130');
INSERT INTO "Device_CentrifugalPumps" VALUES ('GN5600', '800', '6.2', '0.83', '25.4', '92.1', '130');
INSERT INTO "Device_CentrifugalPumps" VALUES ('GN7000', '800', '7.6', '1.1', '25.4', '92.1', '130');
INSERT INTO "Device_CentrifugalPumps" VALUES ('GN7000', '900', '6.9', '1.1', '25.4', '92.1', '130');
INSERT INTO "Device_CentrifugalPumps" VALUES ('GN7000', '954', '6.8', '1.2', '25.4', '92.1', '130');
INSERT INTO "Device_CentrifugalPumps" VALUES ('GN7000', '1000', '6.4', '1.2', '25.4', '92.1', '130');
INSERT INTO "Device_CentrifugalPumps" VALUES ('GN7000', '1100', '5.5', '1.22', '25.4', '92.1', '130');
INSERT INTO "Device_CentrifugalPumps" VALUES ('GN7000', '1200', '5', '1.25', '25.4', '92.1', '130');
INSERT INTO "Device_CentrifugalPumps" VALUES ('GN10000', '1000', '6.4', '1.36', '30.15', '108', '130');
INSERT INTO "Device_CentrifugalPumps" VALUES ('GN10000', '1060', '6.3', '1.38', '30.15', '108', '130');
INSERT INTO "Device_CentrifugalPumps" VALUES ('GN10000', '1100', '6.2', '1.38', '30.15', '108', '130');
INSERT INTO "Device_CentrifugalPumps" VALUES ('GN10000', '1200', '6', '1.4', '30.15', '108', '130');
INSERT INTO "Device_CentrifugalPumps" VALUES ('TL1600', '1270', '7.6', '1.8', '30.2', '108', '130');
INSERT INTO "Device_CentrifugalPumps" VALUES ('TL1600', '1300', '7.5', '1.8', '30.2', '108', '130');
INSERT INTO "Device_CentrifugalPumps" VALUES ('TL1600', '1400', '7.2', '1.88', '30.2', '108', '130');
INSERT INTO "Device_CentrifugalPumps" VALUES ('TL1600', '1440', '7.1', '1.9', '30.2', '108', '130');
INSERT INTO "Device_CentrifugalPumps" VALUES ('TL1600', '1500', '6.8', '1.925', '30.2', '108', '130');
INSERT INTO "Device_CentrifugalPumps" VALUES ('TL1600', '1600', '6.5', '1.925', '30.2', '108', '130');
INSERT INTO "Device_CentrifugalPumps" VALUES ('TL1600', '1700', '6', '1.925', '30.2', '108', '130');
INSERT INTO "Device_CentrifugalPumps" VALUES ('TL1600', '1750', '5.9', '1.93', '30.2', '108', '130');
INSERT INTO "Device_CentrifugalPumps" VALUES ('TL1600', '1800', '5.7', '1.925', '30.2', '108', '130');

PRAGMA foreign_keys = true;
