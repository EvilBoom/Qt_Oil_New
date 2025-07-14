# WellDataController提供了以下功能：

信号系统：

- wellDataLoaded：井数据加载完成时发射
- wellDataSaved：井数据保存成功时发射
- operationStarted/operationFinished：操作状态跟踪
- error：错误发生时发射


Qt属性：

currentWellData：可在QML中绑定的当前井数据属性


核心槽函数：

- getWellData()：根据项目ID获取井数据
- saveWellData()：保存完整井数据
- updateWellData()：使用字典更新井数据


便捷更新方法：

为常用字段提供单独的更新方法（如updateWellMD、updateInnerDiameter等）
这些方法使QML调用更简单


数据验证：

validateWellData()：验证井数据的有效性
返回验证结果和错误信息


与DatabaseService集成：

初始化时获取DatabaseService实例
连接DatabaseService的信号
处理数据库操作结果


# ProjectController提供了以下功能：

信号系统：

- projectsLoaded：项目列表加载完成时发射
- projectCreated：项目创建成功时发射
- projectUpdated：项目更新成功时发射
- projectDeleted：项目删除成功时发射
- projectDetailsLoaded：项目详情加载完成时发射
- operationStarted/operationFinished：操作状态跟踪
- error：错误发生时发射

Qt属性：

projects：可在QML中绑定的项目列表属性


槽函数：

- loadProjects()：加载所有项目
- createProject()：创建新项目
- updateProject()：更新项目信息
- deleteProject()：删除项目
- getProjectByName()：根据名称获取项目
- getProjectSummary()：获取项目汇总信息
- getCurrentProject()：获取当前项目信息


与DatabaseService集成：

初始化时获取DatabaseService实例
连接DatabaseService的信号
处理数据库操作结果


错误处理：

捕获并记录所有异常
通过error信号通知UI
返回适当的默认值

# ReservoirDataController提供了以下功能：

信号系统：

- reservoirDataLoaded：油藏数据加载完成时发射
- reservoirDataSaved：油藏数据保存成功时发射
- operationStarted/operationFinished：操作状态跟踪
- error：错误发生时发射


Qt属性：

currentReservoirData：可在QML中绑定的当前油藏数据属性


核心槽函数：

- getReservoirData()：根据项目ID获取油藏数据
- saveReservoirData()：保存完整油藏数据
- updateReservoirData()：使用字典更新油藏数据


便捷更新方法：

为每个油藏数据字段提供单独的更新方法（如updateBHT、updateAPI等）
这些方法使QML调用更简单


数据验证：

validateReservoirData()：验证油藏数据的有效性
返回验证结果和错误信息


与DatabaseService集成：

初始化时获取DatabaseService实例
连接DatabaseService的信号
处理数据库操作结果
