// Qt_Oil_NewContent/DeviceRecommendation/Steps/Step3_LiftMethodSelection.qml

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Controls.Material
import QtQuick.Effects
import "../Components" as LocalComponents

Rectangle {
    id: root

    // 外部属性
    property var controller: null
    property bool isChineseMode: true
    property int wellId: -1
    property var stepData: ({})
    property var constraints: ({})

    // 信号
    signal nextStepRequested()
    signal dataChanged(var data)

    // 内部属性
    property int selectedMethodIndex: -1
    property var selectedMethod: null

    // 举升方式定义
    property var liftMethods: [
        {
            id: "esp",
            name: isChineseMode ? "潜油离心泵" : "Electric Submersible Pump",
            shortName: "ESP",
            icon: "🔄",
            color: "#4A90E2",
            description: isChineseMode
                ? "适用于大排量、中深井，效率高，可靠性好"
                : "Suitable for high flow rate, medium-deep wells with high efficiency",
            advantages: [
                isChineseMode ? "排量范围大(100-60000 bbl/d)" : "Wide flow range (100-60000 bbl/d)",
                isChineseMode ? "扬程高，可达15000ft" : "High head capacity up to 15000ft",
                isChineseMode ? "效率高(35-60%)" : "High efficiency (35-60%)",
                isChineseMode ? "可处理含砂量低的流体" : "Can handle low sand content fluids"
            ],
            limitations: [
                isChineseMode ? "不适合高含气井" : "Not suitable for high GOR wells",
                isChineseMode ? "温度限制(<300°F)" : "Temperature limitation (<300°F)",
                isChineseMode ? "对固体颗粒敏感" : "Sensitive to solid particles",
                isChineseMode ? "初期投资大" : "High initial investment"
            ],
            applicableRange: {
                production: { min: 100, max: 60000 },
                depth: { min: 1000, max: 15000 },
                temperature: { max: 300 },
                gor: { max: 2000 },
                viscosity: { max: 1000 }
            }
        },
        {
            id: "pcp",
            name: isChineseMode ? "潜油螺杆泵" : "Progressive Cavity Pump",
            shortName: "PCP",
            icon: "🌀",
            color: "#F5A623",
            description: isChineseMode
                ? "适用于高粘度、含砂原油，运行平稳"
                : "Suitable for high viscosity and sandy oil with smooth operation",
            advantages: [
                isChineseMode ? "可处理高粘度流体(50000cp)" : "Can handle high viscosity fluids (50000cp)",
                isChineseMode ? "耐砂性能好" : "Good sand tolerance",
                isChineseMode ? "效率较高(50-70%)" : "High efficiency (50-70%)",
                isChineseMode ? "运行平稳，无脉动" : "Smooth operation without pulsation"
            ],
            limitations: [
                isChineseMode ? "温度限制(<250°F)" : "Temperature limitation (<250°F)",
                isChineseMode ? "不适合含气量高的井" : "Not suitable for high gas content",
                isChineseMode ? "排量相对较小" : "Relatively low flow rate",
                isChineseMode ? "定子易磨损" : "Stator prone to wear"
            ],
            applicableRange: {
                production: { min: 10, max: 5000 },
                depth: { min: 500, max: 6000 },
                temperature: { max: 250 },
                gor: { max: 500 },
                viscosity: { max: 50000 }
            }
        },
        {
            id: "espcp",
            name: isChineseMode ? "潜油柱塞泵" : "Electric Submersible Plunger Pump",
            shortName: "ESPCP",
            icon: "⚡",
            color: "#7ED321",
            description: isChineseMode
                ? "适用于低产井、间歇生产井"
                : "Suitable for low production and intermittent wells",
            advantages: [
                isChineseMode ? "适合低产量井" : "Suitable for low production wells",
                isChineseMode ? "可处理高含气井" : "Can handle high gas content",
                isChineseMode ? "结构简单，维护方便" : "Simple structure, easy maintenance",
                isChineseMode ? "投资成本低" : "Low investment cost"
            ],
            limitations: [
                isChineseMode ? "排量小" : "Low flow rate",
                isChineseMode ? "效率相对较低" : "Relatively low efficiency",
                isChineseMode ? "冲程长度限制" : "Stroke length limitation",
                isChineseMode ? "不适合深井" : "Not suitable for deep wells"
            ],
            applicableRange: {
                production: { min: 1, max: 500 },
                depth: { min: 500, max: 4000 },
                temperature: { max: 250 },
                gor: { max: 5000 },
                viscosity: { max: 1000 }
            }
        },
        {
            id: "hpp",
            name: isChineseMode ? "水力柱塞泵" : "Hydraulic Piston Pump",
            shortName: "HPP",
            icon: "💧",
            color: "#50E3C2",
            description: isChineseMode
                ? "利用高压动力液驱动，适用于偏远井"
                : "Driven by high pressure power fluid, suitable for remote wells",
            advantages: [
                isChineseMode ? "可用于偏远地区" : "Can be used in remote areas",
                isChineseMode ? "适应性强" : "High adaptability",
                isChineseMode ? "可处理腐蚀性流体" : "Can handle corrosive fluids",
                isChineseMode ? "易于控制和调节" : "Easy to control and adjust"
            ],
            limitations: [
                isChineseMode ? "需要动力液系统" : "Requires power fluid system",
                isChineseMode ? "系统复杂" : "Complex system",
                isChineseMode ? "效率较低(30-40%)" : "Low efficiency (30-40%)",
                isChineseMode ? "维护成本高" : "High maintenance cost"
            ],
            applicableRange: {
                production: { min: 50, max: 4000 },
                depth: { min: 1000, max: 10000 },
                temperature: { max: 400 },
                gor: { max: 1000 },
                viscosity: { max: 2000 }
            }
        },
        {
            id: "jet",
            name: isChineseMode ? "射流泵" : "Jet Pump",
            shortName: "JP",
            icon: "🚀",
            color: "#BD10E0",
            description: isChineseMode
                ? "无运动部件，适用于含砂、腐蚀性流体"
                : "No moving parts, suitable for sandy and corrosive fluids",
            advantages: [
                isChineseMode ? "无运动部件" : "No moving parts",
                isChineseMode ? "可处理含砂量高的流体" : "Can handle high sand content",
                isChineseMode ? "耐腐蚀性好" : "Good corrosion resistance",
                isChineseMode ? "安装简单" : "Simple installation"
            ],
            limitations: [
                isChineseMode ? "效率低(20-30%)" : "Low efficiency (20-30%)",
                isChineseMode ? "需要高压动力液" : "Requires high pressure power fluid",
                isChineseMode ? "排量受限" : "Limited flow rate",
                isChineseMode ? "噪音较大" : "High noise level"
            ],
            applicableRange: {
                production: { min: 100, max: 15000 },
                depth: { min: 1000, max: 10000 },
                temperature: { max: 500 },
                gor: { max: 2000 },
                viscosity: { max: 1000 }
            }
        }
    ]

    color: "transparent"

    ColumnLayout {
        anchors.fill: parent
        spacing: 16

        // 标题栏
        RowLayout {
            Layout.fillWidth: true

            Text {
                text: isChineseMode ? "举升方式选择" : "Lift Method Selection"
                font.pixelSize: 20
                font.bold: true
                color: Material.primaryTextColor
            }

            Item { Layout.fillWidth: true }

            // 筛选条件显示 - 修复toFixed错误
            Rectangle {
                Layout.preferredWidth: childrenRect.width + 24
                Layout.preferredHeight: 36
                color: Material.dialogColor
                radius: 18

                Row {
                    anchors.centerIn: parent
                    spacing: 12

                    Text {
                        text: isChineseMode ? "当前条件：" : "Current Conditions:"
                        color: Material.hintTextColor
                        font.pixelSize: 12
                    }

                    Text {
                        text: {
                            var conditions = []

                            // 安全访问预测数据
                            if (stepData && stepData.prediction && stepData.prediction.finalValues) {
                                var prod = stepData.prediction.finalValues.production
                                if (prod !== undefined && prod !== null) {
                                    conditions.push((isChineseMode ? "产量: " : "Prod: ") + Number(prod).toFixed(0) + " bbl/d")
                                }

                                var depth = stepData.prediction.finalValues.pumpDepth
                                if (depth !== undefined && depth !== null) {
                                    conditions.push((isChineseMode ? "深度: " : "Depth: ") + Number(depth).toFixed(0) + " ft")
                                }
                            }

                            // 安全访问参数数据
                            if (stepData && stepData.parameters) {
                                var temp = stepData.parameters.bht
                                if (temp !== undefined && temp !== null) {
                                    conditions.push((isChineseMode ? "温度: " : "Temp: ") + temp + " °F")
                                }

                                var gor = stepData.parameters.gasOilRatio
                                if (gor !== undefined && gor !== null) {
                                    conditions.push("GOR: " + gor + " scf/bbl")
                                }
                            }

                            return conditions.length > 0 ? conditions.join(" | ") : (isChineseMode ? "数据加载中..." : "Loading data...")
                        }
                        color: Material.primaryTextColor
                        font.pixelSize: 12
                        font.bold: true
                    }
                }
            }
        }

        // 方法选择区域
        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            Flow {
                width: parent.width
                spacing: 16

                Repeater {
                    model: liftMethods

                    LocalComponents.LiftMethodCard {
                        width: {
                            var availableWidth = parent.width
                            var minCardWidth = 320  // 最小卡片宽度
                            var maxCardWidth = 400  // 最大卡片宽度
                            var cols = Math.floor(availableWidth / minCardWidth)
                            if (cols === 0) cols = 1
                            var cardWidth = (availableWidth - (cols - 1) * 16) / cols
                            return Math.min(Math.max(cardWidth, minCardWidth), maxCardWidth)
                        }
                        height: 280

                        methodData: modelData
                        isSelected: selectedMethodIndex === index
                        matchScore: calculateMatchScore(modelData)
                        isChineseMode: root.isChineseMode

                        onClicked: {
                            selectedMethodIndex = index
                            selectedMethod = modelData
                            updateStepData()
                        }
                    }
                }
            }
        }

        // 底部详情面板
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: selectedMethod ? 180 : 0
            color: Material.dialogColor
            radius: 8
            visible: selectedMethod !== null

            Behavior on Layout.preferredHeight {
                NumberAnimation { duration: 200; easing.type: Easing.InOutQuad }
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 12
                visible: parent.visible

                RowLayout {
                    Layout.fillWidth: true

                    Text {
                        text: (selectedMethod ? selectedMethod.icon : "") + " " +
                              (selectedMethod ? selectedMethod.name : "")
                        font.pixelSize: 18
                        font.bold: true
                        color: Material.primaryTextColor
                    }

                    Item { Layout.fillWidth: true }

                    // 匹配度指示
                    Rectangle {
                        width: 120
                        height: 32
                        radius: 16
                        color: {
                            var score = selectedMethod ? calculateMatchScore(selectedMethod) : 0
                            if (score >= 80) return Material.color(Material.Green)
                            if (score >= 60) return Material.color(Material.Orange)
                            return Material.color(Material.Red)
                        }

                        Text {
                            anchors.centerIn: parent
                            text: isChineseMode
                                  ? "匹配度: " + (selectedMethod ? calculateMatchScore(selectedMethod) : 0) + "%"
                                  : "Match: " + (selectedMethod ? calculateMatchScore(selectedMethod) : 0) + "%"
                            color: "white"
                            font.bold: true
                            font.pixelSize: 14
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: Material.dividerColor
                }

                // 详细说明
                ScrollView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true

                    Text {
                        width: parent.width
                        text: getDetailedExplanation()
                        color: Material.primaryTextColor
                        font.pixelSize: 14
                        wrapMode: Text.Wrap
                        lineHeight: 1.5
                    }
                }
            }
        }
    }

    // 调试信息
    Component.onCompleted: {
        console.log("=== Step3 组件加载完成 ===")
        console.log("stepData:", JSON.stringify(stepData, null, 2))

        // 添加数据监控
        debugDataStructure()
    }

    // 数据结构调试函数
    function debugDataStructure() {
        console.log("=== 调试数据结构 ===")

        if (stepData) {
            console.log("stepData exists")
            console.log("stepData keys:", Object.keys(stepData))

            if (stepData.prediction) {
                console.log("prediction exists:", JSON.stringify(stepData.prediction, null, 2))
                if (stepData.prediction.finalValues) {
                    console.log("finalValues exists:", JSON.stringify(stepData.prediction.finalValues, null, 2))
                }
            } else {
                console.log("prediction 不存在")
            }

            if (stepData.parameters) {
                console.log("parameters exists:", JSON.stringify(stepData.parameters, null, 2))
            } else {
                console.log("parameters 不存在")
            }
        } else {
            console.log("stepData 为空")
        }
    }

    Timer {
        id: debugTimer
        interval: 2000
        repeat: true
        running: true
        onTriggered: {
            if (!stepData || !stepData.prediction || !stepData.parameters) {
                console.log("=== 定期检查数据状态 ===")
                debugDataStructure()
            } else {
                running = false
                console.log("=== 数据已完整，停止监控 ===")
            }
        }
    }

    // 修复匹配度计算函数
    function calculateMatchScore(method) {
        // 添加详细的调试信息
        console.log("=== calculateMatchScore 开始 ===")
        console.log("method:", method ? method.id : "null")
        console.log("stepData存在:", !!stepData)
        console.log("prediction存在:", !!(stepData && stepData.prediction))
        console.log("parameters存在:", !!(stepData && stepData.parameters))

        // 检查数据完整性
        if (!stepData) {
            console.log("stepData为空，返回默认分数50")
            return 50
        }

        if (!stepData.prediction || !stepData.prediction.finalValues) {
            console.log("prediction数据不完整，返回默认分数50")
            return 50
        }

        if (!stepData.parameters) {
            console.log("parameters数据不完整，返回默认分数50")
            return 50
        }

        var score = 100
        var penalties = 0

        try {
            // 安全获取预测数据
            var production = Number(stepData.prediction.finalValues.production) || 0
            var depth = Number(stepData.prediction.finalValues.pumpDepth) || 0

            console.log("获取到的数据 - 产量:", production, "深度:", depth)

            // 产量匹配度
            if (production < method.applicableRange.production.min) {
                penalties += 20
                console.log("产量过低，扣20分")
            } else if (production > method.applicableRange.production.max) {
                penalties += 30
                console.log("产量过高，扣30分")
            }

            // 深度匹配度
            if (depth < method.applicableRange.depth.min) {
                penalties += 15
                console.log("深度过小，扣15分")
            } else if (depth > method.applicableRange.depth.max) {
                penalties += 20
                console.log("深度过大，扣20分")
            }

            // 温度匹配度
            var temperature = parseFloat(stepData.parameters.bht) || 0
            if (temperature > method.applicableRange.temperature.max) {
                penalties += 25
                console.log("温度过高，扣25分")
            }

            // GOR匹配度
            var gor = parseFloat(stepData.parameters.gasOilRatio) || 0
            if (gor > method.applicableRange.gor.max) {
                penalties += 20
                console.log("GOR过高，扣20分")
            }

            // API重度影响（粘度估算）
            var api = parseFloat(stepData.parameters.api) || 30
            var estimatedViscosity = api < 20 ? 1000 : (api < 30 ? 100 : 10)
            if (estimatedViscosity > method.applicableRange.viscosity.max) {
                penalties += 15
                console.log("粘度过高，扣15分")
            }

            var finalScore = Math.max(0, score - penalties)
            console.log("计算结果 - 基础分:", score, "扣分:", penalties, "最终分:", finalScore)

            return finalScore

        } catch (error) {
            console.log("计算匹配度时出错:", error)
            return 50
        }
    }

    function updateStepData() {
        if (!selectedMethod) return

        var data = {
            selectedMethod: selectedMethod.id,
            methodName: selectedMethod.name,
            methodShortName: selectedMethod.shortName,
            matchScore: calculateMatchScore(selectedMethod)
        }
        console.log("=== Step3 updateStepData ===")
        console.log("发送的数据:", JSON.stringify(data))

        root.dataChanged(data)
    }

    function getDetailedExplanation() {
        if (!selectedMethod) return ""

        // 检查数据完整性
        if (!stepData || !stepData.prediction || !stepData.parameters) {
            return isChineseMode ? "数据加载中，请稍候..." : "Loading data, please wait..."
        }

        var explanation = selectedMethod.description + "\n\n"

        explanation += (isChineseMode ? "基于当前井况分析：\n" : "Based on current well conditions:\n")

        var score = calculateMatchScore(selectedMethod)
        if (score >= 80) {
            explanation += isChineseMode
                ? "✓ 该举升方式非常适合当前井况，各项参数都在最佳工作范围内。"
                : "✓ This lift method is highly suitable for current well conditions, with all parameters within optimal range."
        } else if (score >= 60) {
            explanation += isChineseMode
                ? "⚠ 该举升方式基本适合当前井况，但某些参数接近极限值，需要特别注意。"
                : "⚠ This lift method is generally suitable, but some parameters are close to limits and require attention."
        } else {
            explanation += isChineseMode
                ? "✗ 该举升方式可能不是最佳选择，建议考虑其他方案或调整设计参数。"
                : "✗ This lift method may not be optimal, consider other options or adjust design parameters."
        }

        // 安全添加具体的参数分析
        try {
            explanation += "\n\n" + (isChineseMode ? "参数分析：" : "Parameter Analysis:")

            var production = Number(stepData.prediction.finalValues.production) || 0
            var prodRange = selectedMethod.applicableRange.production
            explanation += "\n• " + (isChineseMode ? "产量" : "Production") + ": " + production.toFixed(0) + " bbl/d "
            explanation += (isChineseMode ? "(范围: " : "(Range: ") + prodRange.min + "-" + prodRange.max + " bbl/d) "
            explanation += getStatusIcon(production, prodRange.min, prodRange.max)

            var depth = Number(stepData.prediction.finalValues.pumpDepth) || 0
            var depthRange = selectedMethod.applicableRange.depth
            explanation += "\n• " + (isChineseMode ? "深度" : "Depth") + ": " + depth.toFixed(0) + " ft "
            explanation += (isChineseMode ? "(范围: " : "(Range: ") + depthRange.min + "-" + depthRange.max + " ft) "
            explanation += getStatusIcon(depth, depthRange.min, depthRange.max)

            var temperature = parseFloat(stepData.parameters.bht) || 0
            explanation += "\n• " + (isChineseMode ? "温度" : "Temperature") + ": " + temperature + " °F "
            explanation += (isChineseMode ? "(上限: " : "(Max: ") + selectedMethod.applicableRange.temperature.max + " °F) "
            explanation += temperature <= selectedMethod.applicableRange.temperature.max ? "✓" : "✗"

        } catch (error) {
            console.log("生成详细说明时出错:", error)
            explanation += "\n\n" + (isChineseMode ? "参数分析加载中..." : "Parameter analysis loading...")
        }

        return explanation
    }

    function getStatusIcon(value, min, max) {
        if (value < min || value > max) return "✗"
        if (value < min * 1.2 || value > max * 0.8) return "⚠"
        return "✓"
    }
}
