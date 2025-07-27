# 持续学习模块使用说明

## 概述
持续学习模块是一个完整的机器学习工作流管理系统，支持任务选择、数据准备、模型训练和评估的全流程管理。该模块已重新设计为嵌入式组件，可以直接集成到主界面中。

## 文件结构

```
Qt_Oil_NewContent/ContinuousLearning/
├── ContinuousLearningPage.qml          # 主页面
├── ContinuousLearningExample.qml       # 完整示例
├── components/
│   ├── TaskSelector.qml                # 任务选择组件
│   ├── StepIndicator.qml               # 步骤指示器组件
│   └── qmldir                          # 组件模块定义
Controller/
└── ContinuousLearningController.py     # Python控制器
```

## 核心组件

### 1. TaskSelector 组件
嵌入式任务选择器，支持三种预测任务：
- 扬程预测
- 产量预测
- 气液比预测

**属性:**
- `isChinese: bool` - 语言设置
- `selectedTask: int` - 当前选择的任务ID

**信号:**
- `taskSelected(int taskType)` - 任务选择信号
- `confirmClicked()` - 确认按钮点击
- `cancelClicked()` - 取消按钮点击

**方法:**
- `resetSelection()` - 重置选择
- `setTask(int taskType)` - 设置任务
- `getTaskName(int taskType)` - 获取任务名称

### 2. ContinuousLearningPage 组件
主要的持续学习页面，包含完整的工作流程：

**阶段管理:**
1. **任务选择阶段** (`task_selection`)
2. **数据准备阶段** (`data_preparation`)
3. **模型训练阶段** (`training`)
4. **模型评估阶段** (`evaluation`)

**界面特性:**
- 进度指示器显示当前阶段
- 分步骤的工作流程
- 任务说明和指导
- 导航控制

### 3. ContinuousLearningController 控制器
Python后端控制器，处理持续学习的业务逻辑：

**主要功能:**
- 任务管理
- 阶段控制
- 数据准备
- 模型训练
- 模型评估

**信号:**
- `taskSelectionChanged(int)` - 任务选择变化
- `phaseChanged(str)` - 阶段变化
- `dataPreparationCompleted(int, dict)` - 数据准备完成
- `trainingCompleted(int, dict)` - 训练完成
- `evaluationCompleted(int, dict)` - 评估完成

## 使用方法

### 1. 嵌入到现有界面

```qml
import QtQuick
import QtQuick.Controls
import "ContinuousLearning"

Rectangle {
    // 您的主界面
    
    // 嵌入持续学习页面
    ContinuousLearningPage {
        anchors.fill: parent
        isChinese: true
        currentProjectId: yourProjectId
    }
}
```

### 2. 独立使用任务选择器

```qml
import QtQuick
import "ContinuousLearning/components"

Rectangle {
    TaskSelector {
        anchors.centerIn: parent
        isChinese: true
        
        onTaskSelected: function(taskType) {
            console.log("选择的任务:", taskType)
            // 处理任务选择
        }
        
        onConfirmClicked: {
            // 处理确认操作
        }
    }
}
```

### 3. 与控制器交互

```qml
// 连接控制器信号
Connections {
    target: continuousLearningController
    
    function onTaskSelectionChanged(taskId) {
        console.log("任务变化:", taskId)
    }
    
    function onPhaseChanged(phase) {
        console.log("阶段变化:", phase)
    }
    
    function onTrainingCompleted(taskType, result) {
        console.log("训练完成:", result)
    }
}

// 调用控制器方法
Button {
    text: "开始数据准备"
    onClicked: continuousLearningController.startDataPreparation()
}
```

## 集成到主系统

### 1. 主程序集成
已在 `main.py` 中注册控制器：

```python
# 控制器已注册为: continuousLearningController
self.continuous_learning_controller = ContinuousLearningController()
self.engine.rootContext().setContextProperty("continuousLearningController", self.continuous_learning_controller)
```

### 2. 添加到主导航

```qml
// 在您的主界面导航中添加
NavigationItem {
    text: "持续学习"
    onClicked: {
        mainStackView.push("ContinuousLearning/ContinuousLearningPage.qml")
    }
}
```

### 3. 作为对话框使用

```qml
Dialog {
    width: 800
    height: 600
    
    ContinuousLearningPage {
        anchors.fill: parent
        isChinese: true
        currentProjectId: currentProject.id
    }
}
```

## 自定义和扩展

### 1. 添加新的预测任务
在 `ContinuousLearningController.py` 中：

```python
self._task_names = {
    0: {"zh": "扬程预测", "en": "Head Prediction"},
    1: {"zh": "产量预测", "en": "Production Prediction"}, 
    2: {"zh": "气液比预测", "en": "Gas-Liquid Ratio Prediction"},
    3: {"zh": "您的新任务", "en": "Your New Task"}  # 添加新任务
}
```

在 `TaskSelector.qml` 中添加对应的 RadioButton。

### 2. 自定义界面样式
修改组件中的颜色和字体：

```qml
// 在组件中自定义颜色
property color primaryColor: "#007bff"
property color backgroundColor: "#f8f9fa"
property color textColor: "#495057"
```

### 3. 添加新的工作流阶段
在控制器中添加新阶段，并在页面中添加对应的界面。

## 数据流程

1. **任务选择**: 用户选择预测任务类型
2. **数据准备**: 系统准备训练数据，进行预处理
3. **模型训练**: 使用准备好的数据训练模型
4. **模型评估**: 评估模型性能，生成报告

## 注意事项

1. **性能**: 大数据量训练时建议使用后台线程
2. **错误处理**: 每个阶段都有完整的错误处理机制
3. **状态管理**: 使用控制器统一管理状态
4. **数据持久化**: 建议保存中间结果以支持断点续训

## 示例应用

查看 `ContinuousLearningExample.qml` 获取完整的集成示例，包括：
- 左侧导航栏
- 内容区域加载
- 控制器信号处理
- 项目信息管理

这个模块设计为高度可配置和可扩展，可以根据具体需求进行定制。
