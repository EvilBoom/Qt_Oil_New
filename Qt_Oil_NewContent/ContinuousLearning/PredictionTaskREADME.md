# 预测任务选择对话框使用说明

## 概述
这个功能实现了一个预测任务选择对话框，用户可以在其中选择三种不同的预测任务类型：
- 扬程预测
- 产量预测  
- 气液比预测

## 文件结构

### 1. QML界面文件
- `Qt_Oil_NewContent/PredictionTaskDialog.qml` - 主要的任务选择对话框
- `Qt_Oil_NewContent/PredictionTaskExample.qml` - 使用示例

### 2. Python控制器
- `Controller/PredictionTaskController.py` - 预测任务控制器

### 3. 主程序集成
- `main.py` - 已更新，添加了预测任务控制器的注册

## 使用方法

### 1. 在QML中使用对话框

```qml
import QtQuick
import QtQuick.Controls

Rectangle {
    // 预测任务选择对话框
    PredictionTaskDialog {
        id: predictionTaskDialog
        isChinese: true  // 设置语言
        
        onTaskSelected: function(taskType) {
            // 处理任务选择
            console.log("选择的任务:", taskType)
            // taskType: 0=扬程预测, 1=产量预测, 2=气液比预测
        }
    }
    
    Button {
        text: "选择预测任务"
        onClicked: predictionTaskDialog.open()
    }
}
```

### 2. 与后端控制器交互

```qml
// 使用预测任务控制器
Connections {
    target: predictionTaskController
    
    function onTaskSelectionChanged(taskId) {
        console.log("任务选择变化:", taskId)
    }
    
    function onPredictionCompleted(taskType, result) {
        console.log("预测完成:", result)
    }
    
    function onPredictionFailed(taskType, errorMsg) {
        console.log("预测失败:", errorMsg)
    }
}

// 选择任务
predictionTaskController.selectTask(0)  // 选择扬程预测

// 开始预测
var parameters = {
    "geopressure": 3350.0,
    "expected_production": 1000.0,
    "bht": 210.0
}
predictionTaskController.startPrediction(parameters)
```

### 3. Python后端API

```python
# 在您的控制器中
prediction_controller = PredictionTaskController()

# 选择任务
prediction_controller.selectTask(0)  # 0=扬程预测

# 获取任务名称
task_name = prediction_controller.getTaskName(0, True)  # 中文名称

# 开始预测
parameters = {
    "geopressure": 3350.0,
    "expected_production": 1000.0
}
prediction_controller.startPrediction(parameters)
```

## 对话框功能

### 界面特性
- 响应式设计，支持中英文切换
- 清晰的单选按钮界面
- 确定/取消按钮
- 美观的现代化界面风格

### 任务类型
1. **扬程预测 (Head Prediction)**
   - 预测所需扬程
   - 任务ID: 0

2. **产量预测 (Production Prediction)**  
   - 预测产量
   - 任务ID: 1

3. **气液比预测 (Gas-Liquid Ratio Prediction)**
   - 预测气液比
   - 任务ID: 2

### 信号和方法

#### PredictionTaskDialog.qml
- `signal taskSelected(int taskType)` - 任务选择信号
- `function resetSelection()` - 重置选择
- `function setDefaultTask(int taskType)` - 设置默认任务

#### PredictionTaskController.py
- `signal taskSelectionChanged(int)` - 任务选择变化
- `signal predictionStarted(int)` - 预测开始
- `signal predictionCompleted(int, dict)` - 预测完成
- `signal predictionFailed(int, str)` - 预测失败

## 自定义和扩展

### 添加新的预测任务类型
1. 在 `PredictionTaskController.py` 中的 `_task_names` 字典添加新任务
2. 在 `PredictionTaskDialog.qml` 中添加新的 RadioButton
3. 在控制器中添加相应的预测方法

### 自定义界面样式
修改 `PredictionTaskDialog.qml` 中的颜色、字体和布局属性：
- 背景色: `color: "#f5f7fa"`
- 边框色: `border.color: "#e0e6ed"`
- 选中色: `color: "#3498db"`

## 集成到现有系统

要将此功能集成到您现有的油井管理系统中：

1. 确保 `main.py` 已正确注册控制器
2. 在相应的QML页面中导入 `PredictionTaskDialog`
3. 连接信号处理预测结果
4. 根据需要调整界面语言设置

## 示例应用

查看 `PredictionTaskExample.qml` 获取完整的使用示例，包括：
- 如何打开对话框
- 如何处理任务选择
- 如何显示预测结果
- 如何处理错误情况

## 注意事项

1. 确保在使用前已正确初始化控制器
2. 预测参数格式需要与MLPredictionService兼容
3. 错误处理应该包含用户友好的消息
4. 建议在预测过程中显示加载指示器
