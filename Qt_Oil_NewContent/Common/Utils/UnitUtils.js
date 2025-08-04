// 单位转换工具函数
.pragma library

// 长度转换
function feetToMeters(feet) {
    return feet * 0.3048;
}

function metersToFeet(meters) {
    return meters / 0.3048;
}

// 直径转换
function inchesToMm(inches) {
    return inches * 25.4;
}

function mmToInches(mm) {
    return mm / 25.4;
}

// 压力转换
function psiToMPa(psi) {
    return psi / 145.038;  // psi转MPa
}

function mpaToPsi(mpa) {
    return mpa * 145.038;  // MPa转psi
}

// 温度转换
function fahrenheitToCelsius(f) {
    return (f - 32) * 5 / 9;
}

function celsiusToFahrenheit(c) {
    return c * 9 / 5 + 32;
}

// 流量转换
function bblToM3(bbl) {
    return bbl * 0.159;
}

function m3ToBbl(m3) {
    return m3 / 0.159;
}

// 密度转换
function lbft3ToKgm3(lbft3) {
    return lbft3 * 16.018;
}

function kgm3ToLbft3(kgm3) {
    return kgm3 / 16.018;
}
// 🔥 新增功率转换函数
function hpToKw(hp) {
    return hp * 0.746;
}
function kwToHp(kw) {
    return kw / 0.746;
}
// 🔥 新增力的转换函数
function lbsToNewtons(lbs) {
    return lbs * 4.448;
}

function newtonsToLbs(newtons) {
    return newtons / 4.448;
}

// 修复通用转换函数
function convertValue(value, fromUnit, toUnit) {
    if (fromUnit === toUnit) return value;

    // 深度转换
    if (fromUnit === "ft" && toUnit === "m") return feetToMeters(value);
    if (fromUnit === "m" && toUnit === "ft") return metersToFeet(value);

    // 直径转换
    if (fromUnit === "in" && toUnit === "mm") return inchesToMm(value);
    if (fromUnit === "mm" && toUnit === "in") return mmToInches(value);

    // 🔥 修复压力转换
    if (fromUnit === "psi" && toUnit === "MPa") return psiToMPa(value);
    if (fromUnit === "MPa" && toUnit === "psi") return mpaToPsi(value);

    // 温度转换
    if (fromUnit === "°F" && toUnit === "°C") return fahrenheitToCelsius(value);
    if (fromUnit === "°C" && toUnit === "°F") return celsiusToFahrenheit(value);

    // 流量转换
    if (fromUnit === "bbl/d" && toUnit === "m³/d") return bblToM3(value);
    if (fromUnit === "m³/d" && toUnit === "bbl/d") return m3ToBbl(value);

    // 🔥 新增：功率转换
    if (fromUnit === "HP" && toUnit === "kW") return hpToKw(value);
    if (fromUnit === "kW" && toUnit === "HP") return kwToHp(value);

    // 🔥 新增：力的转换
    if (fromUnit === "lbs" && toUnit === "N") return lbsToNewtons(value);
    if (fromUnit === "N" && toUnit === "lbs") return newtonsToLbs(value);

    return value;
}

// 格式化数值显示
function formatValue(value, decimals) {
    if (typeof decimals === "undefined") decimals = 2;
    return parseFloat(value).toFixed(decimals);
}

// 修复单位标签
function getUnitLabel(unitType, isMetric) {
    if (isMetric) {
        var metricUnits = {
            "depth": "m",
            "diameter": "mm",
            "pressure": "MPa",        // 🔥 改为MPa
            "temperature": "°C",
            "flow": "m³/d",
            "density": "kg/m³",
            "power": "kW",      // 🔥 新增
            "force": "N",       // 🔥 新增
            "weight": "kg"      // 🔥 新增
        };
        return metricUnits[unitType] || "";
    } else {
        var imperialUnits = {
            "depth": "ft",
            "diameter": "in",
            "pressure": "psi",
            "temperature": "°F",
            "flow": "bbl/d",
            "density": "lb/ft³",
            "power": "HP",      // 🔥 新增
            "force": "lbs",     // 🔥 新增
            "weight": "lbs"     // 🔥 新增
        };
        return imperialUnits[unitType] || "";
    }
}

// 获取单位显示文本
function getUnitDisplayText(unitType, isMetric, isChinese) {
    if (isMetric) {
        if (isChinese) {
            var metricTextCN = {
                "depth": "米",
                "diameter": "毫米",
                "pressure": "兆帕",
                "temperature": "摄氏度",
                "flow": "立方米/天",
                "density": "千克/立方米",
                "power": "千瓦",     // 🔥 新增：功率单位
                "force": "牛顿",     // 🔥 新增：力的单位
                "weight": "千克"     // 🔥 新增：重量单位
            };
            return metricTextCN[unitType] || "";
        } else {
            return getUnitLabel(unitType, true);
        }
    } else {
        if (isChinese) {
            var imperialTextCN = {
                "depth": "英尺",
                "diameter": "英寸",
                "pressure": "磅每平方英寸",  // 🔥 修正表述
                "temperature": "华氏度",
                "flow": "桶每天",           // 🔥 修正表述
                "density": "磅每立方英尺",   // 🔥 修正表述
                "power": "马力",            // 🔥 新增：功率单位
                "force": "磅力",            // 🔥 新增：力的单位
                "weight": "磅"              // 🔥 新增：重量单位
            };
            return imperialTextCN[unitType] || "";
        } else {
            return getUnitLabel(unitType, false);
        }
    }
}