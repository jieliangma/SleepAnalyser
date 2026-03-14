import Foundation

enum L10n {
    // MARK: - Common
    static let appName = String(localized: "app.name", defaultValue: "SleepAnalyser")
    static let version = String(localized: "app.version", defaultValue: "Version 1.0.0")
    static let appDescription = String(localized: "app.description", defaultValue: "Analyze your sleep through breathing sounds.")

    // MARK: - Navigation
    static let dashboard = String(localized: "nav.dashboard", defaultValue: "Dashboard")
    static let liveSession = String(localized: "nav.liveSession", defaultValue: "Live Session")
    static let morningReport = String(localized: "nav.morningReport", defaultValue: "Morning Report")
    static let trends = String(localized: "nav.trends", defaultValue: "Trends")
    static let profiles = String(localized: "nav.profiles", defaultValue: "Profiles")
    static let settings = String(localized: "nav.settings", defaultValue: "Settings")

    // MARK: - Session
    static let startTracking = String(localized: "session.startTracking", defaultValue: "Start Sleep Tracking")
    static let stopTracking = String(localized: "session.stopTracking", defaultValue: "Stop Tracking")
    static let startTrackingShort = String(localized: "session.startTrackingShort", defaultValue: "Start Tracking")
    static let stop = String(localized: "session.stop", defaultValue: "Stop")
    static let recording = String(localized: "session.recording", defaultValue: "Recording")
    static let notTracking = String(localized: "session.notTracking", defaultValue: "Not tracking")
    static let openDashboard = String(localized: "session.openDashboard", defaultValue: "Open Dashboard")

    // MARK: - Metrics
    static let sleepScore = String(localized: "metric.sleepScore", defaultValue: "Sleep Score")
    static let totalSleep = String(localized: "metric.totalSleep", defaultValue: "Total Sleep")
    static let efficiency = String(localized: "metric.efficiency", defaultValue: "Efficiency")
    static let deepSleep = String(localized: "metric.deepSleep", defaultValue: "Deep Sleep")
    static let remSleep = String(localized: "metric.remSleep", defaultValue: "REM")
    static let sleepStages = String(localized: "metric.sleepStages", defaultValue: "Sleep Stages")
    static let bedtime = String(localized: "metric.bedtime", defaultValue: "Bedtime")
    static let wakeTime = String(localized: "metric.wakeTime", defaultValue: "Wake Time")
    static let duration = String(localized: "metric.duration", defaultValue: "Duration")
    static let breathing = String(localized: "metric.breathing", defaultValue: "Breathing")
    static let signal = String(localized: "metric.signal", defaultValue: "Signal")
    static let signalGood = String(localized: "metric.signalGood", defaultValue: "Good")
    static let events = String(localized: "metric.events", defaultValue: "Events")
    static let insights = String(localized: "metric.insights", defaultValue: "Insights")
    static let avgScore = String(localized: "metric.avgScore", defaultValue: "Avg Score")
    static let avgDuration = String(localized: "metric.avgDuration", defaultValue: "Avg Duration")
    static let trend = String(localized: "metric.trend", defaultValue: "Trend")
    static let improving = String(localized: "metric.improving", defaultValue: "Improving")
    static let scoreTrend = String(localized: "metric.scoreTrend", defaultValue: "Score Trend")

    // MARK: - Periods
    static let week = String(localized: "period.week", defaultValue: "Week")
    static let month = String(localized: "period.month", defaultValue: "Month")
    static let period = String(localized: "period.label", defaultValue: "Period")

    // MARK: - Profiles
    static let addProfile = String(localized: "profile.add", defaultValue: "Add Profile")
    static let defaultUser = String(localized: "profile.defaultUser", defaultValue: "Default User")
    static let defaultMicrophone = String(localized: "profile.defaultMic", defaultValue: "Default Microphone")

    // MARK: - Settings
    static let audio = String(localized: "settings.audio", defaultValue: "Audio")
    static let privacy = String(localized: "settings.privacy", defaultValue: "Privacy")
    static let about = String(localized: "settings.about", defaultValue: "About")
    static let audioInput = String(localized: "settings.audioInput", defaultValue: "Audio Input")
    static let microphone = String(localized: "settings.microphone", defaultValue: "Microphone")
    static let sensitivity = String(localized: "settings.sensitivity", defaultValue: "Sensitivity")
    static let calibrateRoom = String(localized: "settings.calibrateRoom", defaultValue: "Calibrate Room")
    static let data = String(localized: "settings.data", defaultValue: "Data")
    static let privacyNote = String(localized: "settings.privacyNote", defaultValue: "Audio is processed locally and never leaves your device.")
    static let exportData = String(localized: "settings.exportData", defaultValue: "Export Sleep Data")
    static let deleteAllData = String(localized: "settings.deleteAll", defaultValue: "Delete All Data")

    // MARK: - Sleep Stages
    static let stageAwake = String(localized: "stage.awake", defaultValue: "Awake")
    static let stageN1 = String(localized: "stage.n1", defaultValue: "Light Sleep (N1)")
    static let stageN2 = String(localized: "stage.n2", defaultValue: "Light Sleep (N2)")
    static let stageN3 = String(localized: "stage.n3", defaultValue: "Deep Sleep (N3)")
    static let stageREM = String(localized: "stage.rem", defaultValue: "REM Sleep")
    static let stageUnknown = String(localized: "stage.unknown", defaultValue: "Unknown")

    static let stageShortAwake = String(localized: "stage.short.awake", defaultValue: "Awake")
    static let stageShortN1 = String(localized: "stage.short.n1", defaultValue: "N1")
    static let stageShortN2 = String(localized: "stage.short.n2", defaultValue: "N2")
    static let stageShortDeep = String(localized: "stage.short.deep", defaultValue: "Deep")
    static let stageShortREM = String(localized: "stage.short.rem", defaultValue: "REM")

    // MARK: - Chart Axes
    static let chartTime = String(localized: "chart.time", defaultValue: "Time")
    static let chartStage = String(localized: "chart.stage", defaultValue: "Stage")
    static let chartDay = String(localized: "chart.day", defaultValue: "Day")
    static let chartScore = String(localized: "chart.score", defaultValue: "Score")

    // MARK: - Confidence
    static let confidenceVeryLow = String(localized: "confidence.veryLow", defaultValue: "Very Low")
    static let confidenceLow = String(localized: "confidence.low", defaultValue: "Low")
    static let confidenceMedium = String(localized: "confidence.medium", defaultValue: "Medium")
    static let confidenceHigh = String(localized: "confidence.high", defaultValue: "High")
    static let confidenceVeryHigh = String(localized: "confidence.veryHigh", defaultValue: "Very High")

    // MARK: - Event Types
    static let eventSnore = String(localized: "event.snore", defaultValue: "Snoring")
    static let eventDisturbance = String(localized: "event.disturbance", defaultValue: "Disturbance")
    static let eventSpeech = String(localized: "event.speech", defaultValue: "Speech/TV")
    static let eventOutOfBed = String(localized: "event.outOfBed", defaultValue: "Got Out of Bed")
    static let eventReturnedToBed = String(localized: "event.returnedToBed", defaultValue: "Returned to Bed")
    static let eventApnea = String(localized: "event.apnea", defaultValue: "Possible Apnea")

    // MARK: - Disturbance Sources
    static let sourceTraffic = String(localized: "source.traffic", defaultValue: "Traffic")
    static let sourceHVAC = String(localized: "source.hvac", defaultValue: "HVAC/Air Conditioning")
    static let sourceRain = String(localized: "source.rain", defaultValue: "Rain")
    static let sourceThunder = String(localized: "source.thunder", defaultValue: "Thunder")
    static let sourcePartner = String(localized: "source.partner", defaultValue: "Partner")
    static let sourcePet = String(localized: "source.pet", defaultValue: "Pet")
    static let sourceTV = String(localized: "source.tv", defaultValue: "TV/Media")
    static let sourceAlarm = String(localized: "source.alarm", defaultValue: "Alarm/Notification")
    static let sourceUnknown = String(localized: "source.unknown", defaultValue: "Unknown")

    // MARK: - Session States
    static let stateIdle = String(localized: "state.idle", defaultValue: "Idle")
    static let statePreparing = String(localized: "state.preparing", defaultValue: "Preparing")
    static let stateRecording = String(localized: "state.recording", defaultValue: "Recording")
    static let statePaused = String(localized: "state.paused", defaultValue: "Paused")
    static let stateStopped = String(localized: "state.stopped", defaultValue: "Stopped")
    static let stateFailed = String(localized: "state.failed", defaultValue: "Failed")

    // MARK: - Duration Formatting
    static func hoursMinutes(_ h: Int, _ m: Int) -> String {
        String(localized: "\(h)h \(m)m", table: "Duration", comment: "Short format: hours and minutes")
    }
    static func minutesOnly(_ m: Int) -> String {
        String(localized: "\(m)m", table: "Duration", comment: "Short format: minutes only")
    }
    static func hoursMinutesLong(_ h: Int, _ m: Int) -> String {
        String(localized: "\(h) hours \(m) minutes", table: "Duration", comment: "Long format: hours and minutes")
    }
    static func minutesOnlyLong(_ m: Int) -> String {
        String(localized: "\(m) minutes", table: "Duration", comment: "Long format: minutes only")
    }
    static func bpmFormat(_ v: String) -> String {
        String(localized: "\(v) BPM", table: "Metrics", comment: "Breaths per minute")
    }

    // MARK: - Insight Templates
    static func insightGoodDuration(_ hours: String) -> String {
        String(localized: "Great job! You got \(hours) hours of sleep, within the recommended range.", table: "Insights")
    }
    static func insightShortSleep(_ hours: String) -> String {
        String(localized: "You only slept \(hours) hours. Aim for 7-9 hours for optimal recovery.", table: "Insights")
    }
    static let insightOversleep = String(localized: "insight.oversleep", defaultValue: "You slept over 10 hours. Oversleeping can indicate poor sleep quality.")
    static let insightLowDeep = String(localized: "insight.lowDeep", defaultValue: "Your deep sleep was below average. Try maintaining a consistent bedtime and cool room temperature.")
    static let insightGoodDeep = String(localized: "insight.goodDeep", defaultValue: "Excellent deep sleep tonight! This is important for physical recovery.")
    static let insightLowREM = String(localized: "insight.lowREM", defaultValue: "REM sleep was low. Avoiding alcohol and reducing stress may help improve REM sleep.")
    static func insightAwakenings(_ count: Int) -> String {
        String(localized: "You had \(count) awakenings. Consider reducing noise and light in your bedroom.", table: "Insights")
    }
    static let insightNoAwakenings = String(localized: "insight.noAwakenings", defaultValue: "No awakenings detected — uninterrupted sleep is excellent for recovery!")
    static func insightTrafficNoise(_ count: Int) -> String {
        String(localized: "Traffic noise disturbed your sleep \(count) times. Consider earplugs or a white noise machine.", table: "Insights")
    }
    static func insightDisturbances(_ count: Int) -> String {
        String(localized: "\(count) disturbances were detected during the night.", table: "Insights")
    }
    static let insightSlowOnset = String(localized: "insight.slowOnset", defaultValue: "It took over 30 minutes to fall asleep. Going to bed earlier or establishing a wind-down routine may help.")
    static let insightFastOnset = String(localized: "insight.fastOnset", defaultValue: "You fell asleep quickly — great sleep onset!")
    static func insightSnoring(_ count: Int) -> String {
        String(localized: "Significant snoring was detected (\(count) events). If persistent, consider consulting a sleep specialist.", table: "Insights")
    }
    static let insightTrackMore = String(localized: "insight.trackMore", defaultValue: "Track more nights to see trends and patterns.")
    static let insightImproving = String(localized: "insight.improving", defaultValue: "Your sleep efficiency is improving! Keep up the good habits.")
    static let insightDeclining = String(localized: "insight.declining", defaultValue: "Sleep efficiency has declined recently. Review your bedtime routine.")
    static let insightConsistent = String(localized: "insight.consistent", defaultValue: "Sleep efficiency has been consistent this period.")
    static func insightGoodScore(_ score: Int) -> String {
        String(localized: "Overall sleep quality is good with an average score of \(score).", table: "Insights")
    }
    static func insightPoorScore(_ score: Int) -> String {
        String(localized: "Average sleep score of \(score) suggests room for improvement. Focus on consistency and duration.", table: "Insights")
    }
}
