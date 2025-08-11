import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Controls.Material

Rectangle {
    id: panel
    
    property bool isChineseMode: true
    property bool isMetric: false
    property string currentStepId: ""
    property var stepData: ({})
    property var constraints: ({})
    
    // 信号定义
    signal recommendationAccepted(var recommendation)
    
    color: Material.background
    radius: 8
    border.color: Material.dividerColor
    border.width: 1
    
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 16
        
        // 面板标题
        Text {
            text: isChineseMode ? "智能推荐建议" : "AI Recommendations"
            font.pixelSize: 18
            font.bold: true
            color: Material.primaryTextColor
        }
        
        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: Material.dividerColor
        }
        
        // 推荐内容区域
        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            
            ColumnLayout {
                width: parent.width
                spacing: 12
                
                // 当前步骤分析
                RecommendationCard {
                    id: currentStepAnalysis
                    Layout.fillWidth: true
                    
                    title: isChineseMode ? "当前步骤分析" : "Current Step Analysis"
                    icon: "🔍"
                    cardType: "analysis"
                    isChineseMode: panel.isChineseMode
                }
                
                // 智能推荐列表
                Repeater {
                    id: recommendationsRepeater
                    model: generateRecommendations()
                    
                    RecommendationCard {
                        Layout.fillWidth: true
                        
                        title: modelData.title
                        description: modelData.description
                        confidence: modelData.confidence
                        icon: modelData.icon
                        cardType: modelData.type
                        actionText: modelData.actionText
                        recommendationData: modelData
                        isChineseMode: panel.isChineseMode
                        
                        onActionClicked: function(data) {
                            panel.recommendationAccepted(data)
                        }
                    }
                }
                
                // 相关知识
                RecommendationCard {
                    id: relatedKnowledge
                    Layout.fillWidth: true
                    
                    title: isChineseMode ? "相关知识" : "Related Knowledge"
                    icon: "📚"
                    cardType: "knowledge"
                    isChineseMode: panel.isChineseMode
                }
            }
        }
        
        // 底部操作区域
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 50
            color: Material.dialogColor
            radius: 6
            
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                
                Button {
                    text: isChineseMode ? "🔄 刷新建议" : "🔄 Refresh"
                    flat: true
                    onClicked: updateRecommendations()
                }
                
                Item { Layout.fillWidth: true }
                
                Button {
                    text: isChineseMode ? "💡 获取更多建议" : "💡 More Suggestions"
                    Material.background: Material.primary
                    Material.foreground: "white"
                    onClicked: showMoreRecommendations()
                }
            }
        }
    }
    
    // 推荐数据生成
    function generateRecommendations() {
        var recommendations = []
        
        switch(currentStepId) {
            case "lift_method":
                recommendations = generateLiftMethodRecommendations()
                break
            case "pump":
                recommendations = generatePumpRecommendations()
                break
            case "separator":
                recommendations = generateSeparatorRecommendations()
                break
            case "protector":
                recommendations = generateProtectorRecommendations()
                break
            case "motor":
                recommendations = generateMotorRecommendations()
                break
            default:
                recommendations = generateDefaultRecommendations()
        }
        
        return recommendations
    }
    
    function generateLiftMethodRecommendations() {
        var recommendations = []
        
        // 基于生产参数的推荐
        var production = constraints.minProduction || 0
        var head = constraints.totalHead || 0
        
        if (production > 1000 && head > 1000) {
            recommendations.push({
                title: isChineseMode ? "推荐ESP举升" : "Recommend ESP Lift",
                description: isChineseMode ? 
                    "基于高产量(" + production.toFixed(0) + " bbl/d)和高扬程(" + head.toFixed(0) + " ft)要求，ESP举升是最佳选择" :
                    "Based on high production (" + production.toFixed(0) + " bbl/d) and high head (" + head.toFixed(0) + " ft), ESP lift is optimal",
                confidence: 0.92,
                icon: "⚡",
                type: "primary",
                actionText: isChineseMode ? "选择ESP" : "Select ESP",
                data: { method: "esp", reason: "high_production_head" }
            })
        }
        
        if (production < 500) {
            recommendations.push({
                title: isChineseMode ? "考虑PCP举升" : "Consider PCP Lift",
                description: isChineseMode ? 
                    "对于低产量井(" + production.toFixed(0) + " bbl/d)，PCP举升更经济" :
                    "For low production wells (" + production.toFixed(0) + " bbl/d), PCP lift is more economical",
                confidence: 0.78,
                icon: "🔄",
                type: "secondary",
                actionText: isChineseMode ? "选择PCP" : "Select PCP",
                data: { method: "pcp", reason: "low_production" }
            })
        }
        
        return recommendations
    }
    
    function generatePumpRecommendations() {
        var recommendations = []
        
        var liftMethod = stepData.lift_method?.selectedMethod
        var requiredHead = constraints.totalHead || 0
        var requiredFlow = constraints.minProduction || 0
        
        if (liftMethod === "esp" && requiredHead > 2000) {
            recommendations.push({
                title: isChineseMode ? "推荐多级离心泵" : "Recommend Multistage Centrifugal Pump",
                description: isChineseMode ? 
                    "扬程要求(" + requiredHead.toFixed(0) + " ft)较高，建议选择80-120级离心泵" :
                    "High head requirement (" + requiredHead.toFixed(0) + " ft), suggest 80-120 stage centrifugal pump",
                confidence: 0.88,
                icon: "⚙️",
                type: "primary",
                actionText: isChineseMode ? "查看泵型" : "View Pumps",
                data: { pumpType: "multistage_centrifugal", stages: Math.ceil(requiredHead / 25) }
            })
        }
        
        // 效率优化建议
        recommendations.push({
            title: isChineseMode ? "效率优化建议" : "Efficiency Optimization",
            description: isChineseMode ? 
                "建议选择效率≥75%的泵型，以降低运行成本" :
                "Recommend pumps with efficiency ≥75% to reduce operating costs",
            confidence: 0.85,
            icon: "📈",
            type: "optimization",
            actionText: isChineseMode ? "应用建议" : "Apply Suggestion",
            data: { optimizationType: "efficiency", minEfficiency: 75 }
        })
        
        return recommendations
    }
    
    function generateSeparatorRecommendations() {
        var recommendations = []
        
        var gasRate = constraints.gasRate || stepData.prediction?.finalValues?.gasRate || 0
        
        if (gasRate > 100) {
            recommendations.push({
                title: isChineseMode ? "推荐安装分离器" : "Recommend Gas Separator",
                description: isChineseMode ? 
                    "气液比(" + gasRate.toFixed(1) + ")较高，建议安装气液分离器以提高泵效" :
                    "High GLR (" + gasRate.toFixed(1) + "), recommend gas separator to improve pump efficiency",
                confidence: 0.90,
                icon: "🔄",
                type: "primary",
                actionText: isChineseMode ? "选择分离器" : "Select Separator",
                data: { separatorType: "gas_liquid", required: true }
            })
        } else {
            recommendations.push({
                title: isChineseMode ? "可选配分离器" : "Optional Separator",
                description: isChineseMode ? 
                    "气液比较低，分离器为可选配置" :
                    "Low GLR, separator is optional",
                confidence: 0.65,
                icon: "ℹ️",
                type: "info",
                actionText: isChineseMode ? "跳过" : "Skip",
                data: { separatorType: "none", required: false }
            })
        }
        
        return recommendations
    }
    
    function generateProtectorRecommendations() {
        var recommendations = []
        
        var pumpPower = constraints.totalPower || stepData.pump?.totalPower || 0
        
        recommendations.push({
            title: isChineseMode ? "推荐保护器配置" : "Recommend Protector Configuration",
            description: isChineseMode ? 
                "基于泵功率(" + pumpPower.toFixed(0) + " HP)，建议配置2个保护器确保安全" :
                "Based on pump power (" + pumpPower.toFixed(0) + " HP), recommend 2 protectors for safety",
            confidence: 0.85,
            icon: "🛡️",
            type: "primary",
            actionText: isChineseMode ? "配置保护器" : "Configure Protector",
            data: { quantity: 2, totalCapacity: pumpPower * 1.2 }
        })
        
        return recommendations
    }
    
    function generateMotorRecommendations() {
        var recommendations = []
        
        var requiredPower = constraints.totalPower || stepData.pump?.totalPower || 0
        
        if (requiredPower > 0) {
            var recommendedPower = requiredPower * 1.15 // 15%安全裕量
            
            recommendations.push({
                title: isChineseMode ? "电机功率推荐" : "Motor Power Recommendation",
                description: isChineseMode ? 
                    "泵功率需求" + requiredPower.toFixed(0) + " HP，推荐电机功率" + recommendedPower.toFixed(0) + " HP（含15%安全裕量）" :
                    "Pump power requirement " + requiredPower.toFixed(0) + " HP, recommend motor power " + recommendedPower.toFixed(0) + " HP (15% safety margin)",
                confidence: 0.90,
                icon: "⚡",
                type: "primary",
                actionText: isChineseMode ? "选择电机" : "Select Motor",
                data: { 
                    recommendedPower: recommendedPower,
                    voltage: 3300,
                    frequency: 60
                }
            })
        }
        
        return recommendations
    }
    
    function generateDefaultRecommendations() {
        return [
            {
                title: isChineseMode ? "完善前续步骤" : "Complete Previous Steps",
                description: isChineseMode ? 
                    "请先完成前面的选型步骤以获得智能推荐" :
                    "Please complete previous selection steps to get AI recommendations",
                confidence: 1.0,
                icon: "⏮️",
                type: "info",
                actionText: isChineseMode ? "返回" : "Go Back",
                data: { action: "go_back" }
            }
        ]
    }
    
    // 显示节点详情
    function showNodeDetails(nodeData) {
        console.log("显示节点详情:", nodeData.label)
        currentStepAnalysis.updateContent(
            isChineseMode ? "节点分析: " + nodeData.label : "Node Analysis: " + nodeData.label,
            generateNodeAnalysis(nodeData)
        )
    }
    
    function showRelationshipDetails(relationData) {
        console.log("显示关系详情:", relationData.label)
        currentStepAnalysis.updateContent(
            isChineseMode ? "关系分析: " + relationData.label : "Relationship Analysis: " + relationData.label,
            generateRelationshipAnalysis(relationData)
        )
    }
    
    function generateNodeAnalysis(nodeData) {
        switch(nodeData.type) {
            case "lift_method":
                return isChineseMode ? 
                    "该举升方式适用于产量范围: 500-5000 bbl/d，扬程范围: 1000-8000 ft" :
                    "This lift method is suitable for production range: 500-5000 bbl/d, head range: 1000-8000 ft"
            case "pump_type":
                return isChineseMode ? 
                    "该泵型具有高效率和可靠性，适合中高产量井" :
                    "This pump type offers high efficiency and reliability, suitable for medium to high production wells"
            default:
                return isChineseMode ? 
                    "点击查看详细参数和建议" :
                    "Click to view detailed parameters and recommendations"
        }
    }
    
    function generateRelationshipAnalysis(relationData) {
        return isChineseMode ? 
            "该关系表示两个组件之间的" + relationData.type + "关系，强度为" + (relationData.strength * 100).toFixed(0) + "%" :
            "This relationship indicates " + relationData.type + " between components with " + (relationData.strength * 100).toFixed(0) + "% strength"
    }
    
    // 更新推荐
    function updateRecommendations() {
        console.log("更新推荐建议")
        recommendationsRepeater.model = generateRecommendations()
    }
    
    function showMoreRecommendations() {
        console.log("显示更多推荐")
        // 实现显示更多推荐的逻辑
    }
}