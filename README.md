# SleepAnalyser

一款 macOS 原生睡眠分析应用，通过床头麦克风实时分析呼吸声音，自动记录睡眠阶段、检测打鼾/磨牙/梦呓等事件，并在早晨给出详细的睡眠报告。

![macOS 14+](https://img.shields.io/badge/macOS-14%2B-blue) ![Swift 5.9](https://img.shields.io/badge/Swift-5.9-orange) ![Core ML](https://img.shields.io/badge/Core%20ML-3%20Models-green) ![License](https://img.shields.io/badge/License-MIT-lightgrey)

## 功能特性

### 睡眠追踪
- **实时音频采集** — AVAudioEngine 16kHz 单声道，支持多麦克风切换
- **呼吸分析** — DSP 流水线：降噪 → 预加重 → FFT → MFCC → 呼吸频率估计
- **5 阶段睡眠分期** — Core ML 模型推理：清醒 / N1 / N2 / 深睡(N3) / REM
- **HMM 时序平滑** — 隐马尔可夫模型确保生理合理的阶段转换
- **90 分钟周期约束** — 前半夜偏重深睡，后半夜偏重 REM

### 事件检测
- **打鼾检测** — 谐波结构分析 (100-800Hz)
- **磨牙检测** — 高频瞬态特征识别
- **梦呓检测** — 语音频段活动检测
- **离床检测** — 状态机：sleeping → possibleAwake → outOfBed → returnedToBed
- **呼吸暂停预警** — 长时间呼吸信号消失

### 环境噪声处理
- **C 语言 DSP 引擎** — FFT 频谱减法分离前景(呼吸)/背景(噪声)
- **7 频段分析** — 次低音 → 低音 → 中低 → 中频 → 中高 → 存在感 → 明亮度
- **自动噪声分类** — 风声 / 汽车 / 摩托车 / 空调 / 雨声 / 人声
- **自适应噪声基底** — 最小统计量跟踪，持续适应环境变化
- **房间声学校准** — 4 步向导，录制 10 秒建立噪声档案

### 录音系统
- **整夜录音** — 全程 CAF 格式录制，振幅降采样用于波形显示
- **事件片段** — 6 秒环形缓冲区，事件触发自动截取 ±2s 音频
- **声音管理** — 浏览、播放、删除录音
- **整夜波形图** — 振幅条形图 + 事件标记 + 播放光标

### 报告与趋势
- **晨间报告** — 睡眠评分(0-100)、时长、效率、阶段分布、事件时间线、智能建议
- **评分算法** — 时长 25% + 效率 30% + 阶段平衡 25% + 干扰 20%
- **周报/月报** — 历史趋势折线图、平均指标、改善/下降检测
- **智能建议** — 基于规则引擎的个性化睡眠改善建议

### 机器学习
- **3 个 Core ML 模型**：
  - `SleepStageClassifier` — RandomForest 200 棵树，5 阶段分类，91% 准确率
  - `SnoreDetector` — RandomForest 150 棵树，打鼾二分类，100% 准确率
  - `NoiseContextClassifier` — RandomForest 150 棵树，5 类噪声分类，93% 准确率
- **规则引擎回退** — 模型不可用时自动切换至基于睡眠医学的规则推理
- **人工反馈闭环** — 用户确认/修改事件标注，数据可用于模型再训练

### 用户界面
- **暗色主题** — 深海军蓝背景 (#0F172A)，靛蓝主色 (#6366F1)
- **实时呼吸动画** — Canvas 60fps 三层波形，振幅跟随真实麦克风信号
- **催眠图** — Swift Charts 睡眠阶段时间线
- **菜单栏常驻** — 快速查看状态、开始/停止追踪、一键退出
- **多语言** — 英文 / 简体中文 / 繁体中文，应用内切换即时生效

## 系统要求

- macOS 14.0 (Sonoma) 或更高版本
- Xcode 15.0+
- 麦克风（内置或外接）

## 快速开始

### 构建运行

```bash
# 克隆项目
git clone <repo-url> && cd SleepAnalyser

# 用 Xcode 打开
open SleepAnalyser.xcodeproj

# 或命令行构建
xcodebuild -project SleepAnalyser.xcodeproj -scheme SleepAnalyser -configuration Debug build

# 运行测试
xcodebuild -project SleepAnalyser.xcodeproj -scheme SleepAnalyser -configuration Debug -destination 'platform=macOS' test
```

### 重新训练 ML 模型（可选）

```bash
# 安装依赖
pip3 install 'scikit-learn==1.5.1' coremltools numpy

# 训练并编译模型
python3 MLTraining/train_models.py
```

模型会自动生成到 `SleepAnalyser/Resources/ML/` 目录。

## 项目结构

```
SleepAnalyser/
├── App/                        # 应用入口、AppState、依赖注入
├── Audio/
│   ├── Capture/                # AVAudioEngine 麦克风采集、设备管理
│   ├── CSeparator/             # C 语言噪声分离引擎 + Swift 桥接
│   ├── Detection/              # 打鼾/干扰/语音/离床检测器
│   ├── DSP/                    # 预处理、降噪、AGC、FFT、MFCC、呼吸估计
│   ├── Pipeline/               # 音频流水线协调器、实时帧回调
│   └── Recording/              # 整夜录音、事件片段、音频播放
├── Data/
│   ├── DTOs/                   # 数据传输对象
│   ├── Mappers/                # Domain ↔ SwiftData 双向映射
│   ├── Persistence/SwiftData/  # @Model 实体、ModelContainer
│   └── Repositories/           # Session、Profile、Report 仓储
├── Domain/
│   ├── Enums/                  # SleepStage、EventType、SessionState...
│   ├── Models/                 # 15+ 领域模型
│   ├── Protocols/              # 9 个服务协议
│   └── UseCases/               # 7 个用例
├── ML/
│   ├── CoreML/                 # 模型加载、推理引擎（ML + 规则回退）
│   └── Temporal/               # HMM 后处理、睡眠周期约束、置信度平滑
├── Presentation/
│   ├── Dashboard/              # 主仪表盘
│   ├── MenuBar/                # 菜单栏弹窗
│   ├── NoiseAnalysis/          # 噪声分析浏览/编辑
│   ├── Profiles/               # 用户管理
│   ├── Recordings/             # 录音管理、波形图、事件编辑
│   ├── Reports/                # 晨间报告、趋势图
│   ├── Session/                # 实时监测 + 呼吸动画
│   ├── Settings/               # 音频/语言/隐私/校准/关于
│   ├── Shared/                 # 共享组件：评分仪表、催眠图、指标卡片
│   └── Theme/                  # 颜色、字体、间距
├── Reporting/                  # 评分计算、报告生成、趋势聚合、建议引擎
├── Resources/
│   ├── Assets.xcassets/        # AppIcon
│   ├── Config/                 # FeatureFlags.plist
│   ├── ML/                     # 3 个 .mlmodelc 模型（5.1 MB）
│   ├── en.lproj/               # 英文翻译
│   ├── zh-Hans.lproj/          # 简体中文翻译
│   └── zh-Hant.lproj/          # 繁体中文翻译
├── Utilities/                  # L10n、常量、Date/Array 扩展
└── Platform/                   # 权限、日志、后台生命周期

SleepAnalyserTests/             # 61 个单元测试
├── AudioTests/                 # 预处理、频谱提取、环形缓冲区
├── DomainTests/                # 模型、评分、用例
├── MLTests/                    # 推理引擎、HMM、置信度平滑
├── ReportingTests/             # 评分计算、建议引擎
└── TestDoubles/                # Mock 仓储、时钟、音频 fixture

MLTraining/                     # Python 模型训练脚本
```

## 技术架构

```
麦克风 (AVAudioEngine, 16kHz mono)
  → 预处理 (DC 去除 / 预加重 / AGC)
    → C 噪声分离 (FFT 频谱减法 → 前景 + 背景)
      → 特征提取 (MFCC 13 系数 / 频谱质心 / ZCR / RMS)
        → Core ML 推理 (SleepStageClassifier / SnoreDetector / NoiseContextClassifier)
          → HMM 时序平滑 (转移概率矩阵)
            → 90 分钟周期约束
              → SwiftData 持久化 + UI 实时更新
```

## 统计

| 指标 | 数值 |
|------|------|
| Swift 源文件 | 128 |
| C 源文件 | 4 |
| Swift 代码行 | 7,765 |
| C 代码行 | ~370 |
| 单元测试 | 61 |
| Core ML 模型 | 3 (5.1 MB) |
| 支持语言 | 3 (en/zh-Hans/zh-Hant) |
| L10n 翻译键 | 140+ |
| Git 提交 | 25 |

## 许可证

MIT License
