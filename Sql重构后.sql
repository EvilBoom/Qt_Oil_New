-- 重构后的数据库表结构设计
-- 主要改进点：
-- 1. 统一数据类型，避免TEXT存储数字
-- 2. 建立清晰的表关系
-- 3. 减少数据冗余
-- 4. 添加索引优化查询性能
-- 5. 规范命名约定

-- 1. 项目主表
CREATE TABLE projects (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    project_name VARCHAR(100) NOT NULL UNIQUE,
    user_name VARCHAR(50) NOT NULL,
    company_name VARCHAR(100),
    well_name VARCHAR(100),
    oil_name VARCHAR(50),
    location VARCHAR(200),
    ps TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- 2. 井基础数据表
CREATE TABLE wells (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    project_id INTEGER NOT NULL,
    well_md REAL,                    -- 井深(m)
    well_tvd REAL,                   -- 垂直深度(m)
    well_dls REAL,                   -- 狗腿度
    inner_diameter REAL,             -- 内径(mm)
    outer_diameter REAL,             -- 外径(mm)
    roughness REAL,                  -- 粗糙度
    perforation_vertical_depth REAL, -- 射孔垂直深度(m)
    pump_hanging_vertical_depth REAL,-- 泵挂垂直深度(m)
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (project_id) REFERENCES projects(id) ON DELETE CASCADE
);

-- 3. 油藏参数表
CREATE TABLE reservoir_data (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    project_id INTEGER NOT NULL,
    geo_produce_index REAL,          -- 地质产能指数
    expected_production REAL,        -- 预期产量
    saturation_pressure REAL,        -- 饱和压力(MPa)
    geo_pressure REAL,               -- 地层压力(MPa)
    bht REAL,                        -- 井底温度(°C)
    bsw REAL,                        -- 含水率(%)
    api REAL,                        -- API度
    gas_oil_ratio REAL,              -- 气油比(m³/m³)
    well_head_pressure REAL,         -- 井口压力(MPa)
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (project_id) REFERENCES projects(id) ON DELETE CASCADE
);

-- 4. 预测结果表
CREATE TABLE predictions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    project_id INTEGER NOT NULL,
    predict_at_pump REAL,            -- 预测泵入口压力
    predict_lift REAL,               -- 预测举升量
    predict_production REAL,         -- 预测产量
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (project_id) REFERENCES projects(id) ON DELETE CASCADE
);

-- 5. 设备类型表
CREATE TABLE equipment_types (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    type_name VARCHAR(50) NOT NULL UNIQUE,
    description TEXT
);

-- 6. 离心泵表
CREATE TABLE centrifugal_pumps (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    impeller_model VARCHAR(50) NOT NULL,
    displacement REAL NOT NULL,
    single_stage_head REAL NOT NULL,
    single_stage_power REAL NOT NULL,
    shaft_diameter REAL NOT NULL,
    mounting_height REAL NOT NULL,
    outside_diameter REAL DEFAULT 102,
    stages_min INTEGER DEFAULT 1,
    stages_max INTEGER DEFAULT 200,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(impeller_model, displacement, single_stage_head, single_stage_power)
);

-- 7. 电机表
CREATE TABLE motors (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    type VARCHAR(50) NOT NULL,
    power_50hz REAL,
    voltage_50hz REAL,
    power_60hz REAL,
    voltage_60hz REAL,
    electric_current REAL,
    weight REAL,
    length REAL,
    outside_diameter REAL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- 8. 保护器表
CREATE TABLE protectors (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    model VARCHAR(50) NOT NULL,
    outside_diameter REAL,
    length REAL,
    weight REAL,
    ps VARCHAR(50),
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- 9. 分离器表
CREATE TABLE separators (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    model VARCHAR(50) NOT NULL,
    outside_diameter REAL,
    length REAL,
    weight REAL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- 10. 设备推荐结果表
CREATE TABLE equipment_recommendations (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    project_id INTEGER NOT NULL,
    pump_id INTEGER,
    motor_id INTEGER,
    protector_id INTEGER,
    separator_id INTEGER,
    recommendation_date DATETIME DEFAULT CURRENT_TIMESTAMP,
    confidence_score REAL,
    notes TEXT,
    FOREIGN KEY (project_id) REFERENCES projects(id) ON DELETE CASCADE,
    FOREIGN KEY (pump_id) REFERENCES centrifugal_pumps(id),
    FOREIGN KEY (motor_id) REFERENCES motors(id),
    FOREIGN KEY (protector_id) REFERENCES protectors(id),
    FOREIGN KEY (separator_id) REFERENCES separators(id)
);

-- 11. 设备性能曲线数据表
CREATE TABLE equipment_curve_data (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    equipment_type VARCHAR(20) NOT NULL, -- 'pump', 'motor', etc.
    equipment_id INTEGER NOT NULL,
    frequency REAL,
    flow_rate REAL,      -- 流量 Q
    head REAL,           -- 扬程 H
    power REAL,          -- 功率 P
    efficiency REAL,     -- 效率 X
    stage INTEGER,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- 12. TDH计算历史表
CREATE TABLE tdh_calculations (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    project_id INTEGER,
    phdm INTEGER,        -- 泵头直径
    frequency INTEGER,   -- 频率
    pressure_ratio REAL, -- Pr
    ip REAL,
    bht REAL,
    qf REAL,
    bsw REAL,
    api REAL,
    gor REAL,
    pb INTEGER,
    whp INTEGER,
    at_pump REAL,
    tdh REAL,
    calculated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (project_id) REFERENCES projects(id) ON DELETE CASCADE
);

-- 13. QF计算历史表
CREATE TABLE qf_calculations (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    project_id INTEGER,
    well_name VARCHAR(100),
    depth REAL,
    stroke_count_surface INTEGER,  -- skcs
    stroke_count_bottom INTEGER,   -- bkcs
    pressure_ratio INTEGER,        -- Pr
    ip REAL,
    bht REAL,
    qf INTEGER,
    design_pip REAL,
    liquid_rate REAL,
    liquid_gas_rate REAL,
    bsw REAL,
    api REAL,
    gor INTEGER,
    pb INTEGER,
    whp INTEGER,
    at_pump REAL,
    tdh REAL,
    pressure_gradient REAL,        -- jdyl
    productivity_index REAL,       -- xlkPI
    calculated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (project_id) REFERENCES projects(id) ON DELETE CASCADE
);

-- 14. GLR计算历史表
CREATE TABLE glr_calculations (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    project_id INTEGER,
    geo_pressure REAL,
    produce_index REAL,
    bht REAL,
    expected_production REAL,
    bsw REAL,
    api REAL,
    gas_oil_ratio REAL,
    saturation_pressure INTEGER,
    well_head_pressure INTEGER,
    pump_pressure REAL,
    calculated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (project_id) REFERENCES projects(id) ON DELETE CASCADE
);

-- 创建索引提高查询性能
CREATE INDEX idx_projects_name ON projects(project_name);
CREATE INDEX idx_wells_project ON wells(project_id);
CREATE INDEX idx_reservoir_project ON reservoir_data(project_id);
CREATE INDEX idx_predictions_project ON predictions(project_id);
CREATE INDEX idx_recommendations_project ON equipment_recommendations(project_id);
CREATE INDEX idx_curve_data_equipment ON equipment_curve_data(equipment_type, equipment_id);
CREATE INDEX idx_tdh_project ON tdh_calculations(project_id);
CREATE INDEX idx_qf_project ON qf_calculations(project_id);
CREATE INDEX idx_glr_project ON glr_calculations(project_id);

-- 创建视图简化常用查询
CREATE VIEW project_summary AS
SELECT 
    p.id,
    p.project_name,
    p.user_name,
    p.company_name,
    p.well_name,
    w.well_md,
    w.well_tvd,
    r.expected_production,
    r.bht,
    r.bsw,
    r.api,
    pred.predict_production,
    p.created_at
FROM projects p
LEFT JOIN wells w ON p.id = w.project_id
LEFT JOIN reservoir_data r ON p.id = r.project_id
LEFT JOIN predictions pred ON p.id = pred.project_id;

-- 创建设备推荐详情视图
CREATE VIEW equipment_recommendation_details AS
SELECT 
    er.id,
    p.project_name,
    cp.impeller_model as pump_model,
    cp.displacement,
    cp.single_stage_head,
    m.type as motor_type,
    m.power_50hz,
    pr.model as protector_model,
    s.model as separator_model,
    er.confidence_score,
    er.recommendation_date
FROM equipment_recommendations er
JOIN projects p ON er.project_id = p.id
LEFT JOIN centrifugal_pumps cp ON er.pump_id = cp.id
LEFT JOIN motors m ON er.motor_id = m.id
LEFT JOIN protectors pr ON er.protector_id = pr.id
LEFT JOIN separators s ON er.separator_id = s.id;