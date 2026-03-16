import Foundation

enum L10n {
    private static var lm: LanguageManager { LanguageManager.shared }
    private static func s(_ key: String) -> String { lm.localizedString(key) }

    // MARK: - Common
    static var appName: String { s("app.name") }
    static var version: String { s("app.version") }
    static var appDescription: String { s("app.description") }

    // MARK: - Navigation
    static var dashboard: String { s("nav.dashboard") }
    static var liveSession: String { s("nav.liveSession") }
    static var morningReport: String { s("nav.morningReport") }
    static var recordings: String { s("nav.recordings") }
    static var noiseAnalysis: String { s("nav.noiseAnalysis") }
    static var rooms: String { s("nav.rooms") }
    static var noiseTypes: String { s("nav.noiseTypes") }
    static var trends: String { s("nav.trends") }
    static var profiles: String { s("nav.profiles") }
    static var settings: String { s("nav.settings") }

    // MARK: - Session
    static var startTracking: String { s("session.startTracking") }
    static var stopTracking: String { s("session.stopTracking") }
    static var startTrackingShort: String { s("session.startTrackingShort") }
    static var stop: String { s("session.stop") }
    static var recording: String { s("session.recording") }
    static var notTracking: String { s("session.notTracking") }
    static var openDashboard: String { s("session.openDashboard") }
    static var quit: String { s("app.quit") }

    // MARK: - Metrics
    static var sleepScore: String { s("metric.sleepScore") }
    static var totalSleep: String { s("metric.totalSleep") }
    static var efficiency: String { s("metric.efficiency") }
    static var deepSleep: String { s("metric.deepSleep") }
    static var remSleep: String { s("metric.remSleep") }
    static var sleepStages: String { s("metric.sleepStages") }
    static var bedtime: String { s("metric.bedtime") }
    static var wakeTime: String { s("metric.wakeTime") }
    static var duration: String { s("metric.duration") }
    static var breathing: String { s("metric.breathing") }
    static var signal: String { s("metric.signal") }
    static var signalGood: String { s("metric.signalGood") }
    static var events: String { s("metric.events") }
    static var insights: String { s("metric.insights") }
    static var avgScore: String { s("metric.avgScore") }
    static var avgDuration: String { s("metric.avgDuration") }
    static var trend: String { s("metric.trend") }
    static var improving: String { s("metric.improving") }
    static var scoreTrend: String { s("metric.scoreTrend") }

    // MARK: - Periods
    static var week: String { s("period.week") }
    static var month: String { s("period.month") }
    static var period: String { s("period.label") }

    // MARK: - Profiles
    static var addProfile: String { s("profile.add") }
    static var defaultUser: String { s("profile.defaultUser") }
    static var defaultMicrophone: String { s("profile.defaultMic") }
    static var profileSwitch: String { s("profile.switch") }
    static var profileActive: String { s("profile.active") }
    static var profileDeleteTitle: String { s("profile.deleteTitle") }
    static var profileDeleteConfirm: String { s("profile.deleteConfirm") }
    static var cancel: String { s("common.cancel") }
    static func profileDeleteMessage(_ name: String) -> String {
        String(format: s("profile.deleteMessage"), name)
    }

    // MARK: - Settings
    static var audio: String { s("settings.audio") }
    static var privacy: String { s("settings.privacy") }
    static var about: String { s("settings.about") }
    static var language: String { s("settings.language") }
    static var languageSelection: String { s("settings.languageSelection") }
    static var languageNote: String { s("settings.languageNote") }
    static var audioInput: String { s("settings.audioInput") }
    static var microphone: String { s("settings.microphone") }
    static var sensitivity: String { s("settings.sensitivity") }
    static var calibrateRoom: String { s("settings.calibrateRoom") }
    static var calibrationIntro: String { s("calibration.intro") }
    static var calibrationRecording: String { s("calibration.recording") }
    static var calibrationKeepQuiet: String { s("calibration.keepQuiet") }
    static var calibrationAnalyzing: String { s("calibration.analyzing") }
    static var calibrationDone: String { s("calibration.done") }
    static var calibrationNoiseFloor: String { s("calibration.noiseFloor") }
    static var calibrationGain: String { s("calibration.gain") }
    static var calibrationQuiet: String { s("calibration.quiet") }
    static var calibrationModerate: String { s("calibration.moderate") }
    static var calibrationLoud: String { s("calibration.loud") }
    static var calibrationStart: String { s("calibration.start") }
    static var calibrationFinish: String { s("calibration.finish") }
    static var calibrationRetry: String { s("calibration.retry") }
    static var calibrationRecalibrate: String { s("calibration.recalibrate") }
    static var calibrationNone: String { s("calibration.none") }
    static var calibrationLastDate: String { s("calibration.lastDate") }
    static var noiseLevel: String { s("metric.noiseLevel") }
    static var breathCount: String { s("metric.breathCount") }
    static var data: String { s("settings.data") }
    static var privacyNote: String { s("settings.privacyNote") }
    static var exportData: String { s("settings.exportData") }
    static var deleteAllData: String { s("settings.deleteAll") }

    // MARK: - Sleep Stages
    static var stageAwake: String { s("stage.awake") }
    static var stageN1: String { s("stage.n1") }
    static var stageN2: String { s("stage.n2") }
    static var stageN3: String { s("stage.n3") }
    static var stageREM: String { s("stage.rem") }
    static var stageUnknown: String { s("stage.unknown") }

    static var stageShortAwake: String { s("stage.short.awake") }
    static var stageShortN1: String { s("stage.short.n1") }
    static var stageShortN2: String { s("stage.short.n2") }
    static var stageShortDeep: String { s("stage.short.deep") }
    static var stageShortREM: String { s("stage.short.rem") }

    // MARK: - Chart Axes
    static var chartTime: String { s("chart.time") }
    static var chartStage: String { s("chart.stage") }
    static var chartDay: String { s("chart.day") }
    static var chartScore: String { s("chart.score") }

    // MARK: - Confidence
    static var confidenceVeryLow: String { s("confidence.veryLow") }
    static var confidenceLow: String { s("confidence.low") }
    static var confidenceMedium: String { s("confidence.medium") }
    static var confidenceHigh: String { s("confidence.high") }
    static var confidenceVeryHigh: String { s("confidence.veryHigh") }

    // MARK: - Event Types
    static var eventSnore: String { s("event.snore") }
    static var eventBruxism: String { s("event.bruxism") }
    static var eventSleepTalking: String { s("event.sleepTalking") }
    static var eventDisturbance: String { s("event.disturbance") }
    static var eventSpeech: String { s("event.speech") }
    static var eventOutOfBed: String { s("event.outOfBed") }
    static var eventReturnedToBed: String { s("event.returnedToBed") }
    static var eventApnea: String { s("event.apnea") }

    // MARK: - Disturbance Sources
    static var sourceTraffic: String { s("source.traffic") }
    static var sourceHVAC: String { s("source.hvac") }
    static var sourceRain: String { s("source.rain") }
    static var sourceThunder: String { s("source.thunder") }
    static var sourcePartner: String { s("source.partner") }
    static var sourcePet: String { s("source.pet") }
    static var sourceTV: String { s("source.tv") }
    static var sourceAlarm: String { s("source.alarm") }
    static var sourceUnknown: String { s("source.unknown") }

    // MARK: - Session States
    static var stateIdle: String { s("state.idle") }
    static var statePreparing: String { s("state.preparing") }
    static var stateRecording: String { s("state.recording") }
    static var statePaused: String { s("state.paused") }
    static var stateStopped: String { s("state.stopped") }
    static var stateFailed: String { s("state.failed") }

    // MARK: - Duration Formatting
    static func hoursMinutes(_ h: Int, _ m: Int) -> String { "\(h)h \(m)m" }
    static func minutesOnly(_ m: Int) -> String { "\(m)m" }
    static func hoursMinutesLong(_ h: Int, _ m: Int) -> String { "\(h) hours \(m) minutes" }
    static func minutesOnlyLong(_ m: Int) -> String { "\(m) minutes" }
    static func bpmFormat(_ v: String) -> String { "\(v) BPM" }

    // MARK: - Insight Templates
    static var insightOversleep: String { s("insight.oversleep") }
    static var insightLowDeep: String { s("insight.lowDeep") }
    static var insightGoodDeep: String { s("insight.goodDeep") }
    static var insightLowREM: String { s("insight.lowREM") }
    static var insightNoAwakenings: String { s("insight.noAwakenings") }
    static var insightSlowOnset: String { s("insight.slowOnset") }
    static var insightFastOnset: String { s("insight.fastOnset") }
    static var insightTrackMore: String { s("insight.trackMore") }
    static var insightImproving: String { s("insight.improving") }
    static var insightDeclining: String { s("insight.declining") }
    static var insightConsistent: String { s("insight.consistent") }

    static func insightGoodDuration(_ hours: String) -> String {
        String(format: s("insight.goodDuration"), hours)
    }
    static func insightShortSleep(_ hours: String) -> String {
        String(format: s("insight.shortSleep"), hours)
    }
    static func insightAwakenings(_ count: Int) -> String {
        String(format: s("insight.awakenings"), count)
    }
    static func insightTrafficNoise(_ count: Int) -> String {
        String(format: s("insight.trafficNoise"), count)
    }
    static func insightDisturbances(_ count: Int) -> String {
        String(format: s("insight.disturbances"), count)
    }
    static func insightSnoring(_ count: Int) -> String {
        String(format: s("insight.snoring"), count)
    }
    static func insightGoodScore(_ score: Int) -> String {
        String(format: s("insight.goodScore"), score)
    }
    static func insightPoorScore(_ score: Int) -> String {
        String(format: s("insight.poorScore"), score)
    }

    // MARK: - Recordings
    static var noRecordings: String { s("recordings.none") }
    static var editEvent: String { s("event.edit") }
    static var confirmEvent: String { s("event.confirm") }
    static var eventTypeLabel: String { s("event.typeLabel") }
    static var noteLabel: String { s("event.noteLabel") }
    static var notePlaceholder: String { s("event.notePlaceholder") }
    static var noNoiseSegments: String { s("noise.none") }
    static var noiseFilterAll: String { s("noise.filterAll") }
    static var editNoiseSegment: String { s("noise.edit") }
    static var addRoom: String { s("room.add") }
    static var noRooms: String { s("room.none") }
    static var renameRoom: String { s("room.rename") }
    static var roomNamePlaceholder: String { s("room.namePlaceholder") }
    static var liveCapture: String { s("noise.liveCapture") }
    static var startCapture: String { s("noise.startCapture") }
    static var stopCapture: String { s("noise.stopCapture") }
    static var exportMLData: String { s("ml.export") }
    static var confirmAllNoise: String { s("noise.confirmAll") }
    static var addNoiseType: String { s("noise.addType") }

    // MARK: - Storage Management
    static var storage: String { s("settings.storage") }
    static var storageManagement: String { s("settings.storageManagement") }
    static var maxStorageSize: String { s("settings.maxStorageSize") }
    static var maxStorageDays: String { s("settings.maxStorageDays") }
    static var currentUsage: String { s("settings.currentUsage") }
    static var recordingCount: String { s("settings.recordingCount") }
    static var storageNote: String { s("settings.storageNote") }
    static func storageDaysValue(_ d: Int) -> String {
        String(format: s("settings.storageDaysFormat"), d)
    }
}
