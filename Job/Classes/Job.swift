//
//  Job.swift
//  AmbiKit
//
//  Created by Paco on 30/1/2020.
//  Copyright © 2020 Paco. All rights reserved.
//

import Foundation

public enum JobError: Error {
    case invalid
    case customError(error: Error?)
    case canceled
    case timeout
}

private protocol JobDelegate: class {
    
    func job(onStart Job: JobPresentable)
    func job(job: JobPresentable, onCompleteWith error: JobError?)
    
}

public protocol JobObservable {
    
    func onSuccess()
    
    func onError(error: JobError?)
    
}

public protocol JobPresentable {
    var id: String { get }
    var label: String { get }
    var error: JobError? { get set }
    var isRetryJob: Bool { get set }
    func run(onDispatchQueue dispatchQueue: DispatchQueue, dependency: JobQueueDependency?)
    func forceCancel()
    func cloneForRetry() -> JobPresentable
    func shouldRetry() -> Bool
    var executionTime: TimeInterval? { get }
}

public class Job<Dependency: JobQueueDependency>: JobPresentable, JobObservable, TimeoutTimerDelegate, CustomStringConvertible {
    
    public var description: String {
        return "Job{id=\(id), name=\(label), error=\(error?.localizedDescription ?? ""), timeoutDuration=\(timeoutTimer.timeout), retry=\(isRetryJob), timeMeasurement=\(timeMeasurement)}"
    }
    
    public let id: String
    
    public let label: String
    
    public var error: JobError?
    
    private(set) var isRunning: Bool = false
    
    private(set) var isCompleted: Bool = false
    
    private let block: ((Dependency? , JobObservable) -> Void)
    
    let timeMeasurement = TimeMeasurement()
    
    public var executionTime: TimeInterval? {
        get {
            return timeMeasurement.diff
        }
    }
    
    let timeoutTimer: TimeoutTimer
    
    let retryer: JobQueueRetryer
    
    public var isRetryJob: Bool = false
    
    fileprivate weak var delegate: JobDelegate?
    
    private let lock = NSLock()
    
    public init(label: String, timeout: TimeInterval = 0, retry: Int = 0, block: @escaping ((Dependency?, JobObservable) -> Void)) {
        self.id = UUID().uuidString
        self.label = label
        timeoutTimer = TimeoutTimer(timeout: timeout)
        retryer = JobQueueRetryer(retry: retry)
        self.block = block
        timeoutTimer.delegate = self
    }
    
    public func run(onDispatchQueue dispatchQueue: DispatchQueue, dependency: JobQueueDependency?) {
        onStart()
        var _dependency: Dependency?
        if dependency != nil {
            _dependency = (dependency as? Dependency)
            guard _dependency != nil else {
                onFailInValidation()
                return
            }
        }
        _run(onDispatchQueue: dispatchQueue, dependency: _dependency)
    }
    
    public func forceCancel() {
        onCancel()
    }
    
    public func cloneForRetry() -> JobPresentable {
        return _cloneForRetry()
    }
    
    public func shouldRetry() -> Bool {
        return retryer.shouldRetry
    }
    
    private func _run(onDispatchQueue dispatchQueue: DispatchQueue, dependency: Dependency?) {
        dispatchQueue.async { [weak self] in
            if let weakSelf = self {
                weakSelf.block(dependency, weakSelf)
            }
        }
    }

    private func _cloneForRetry() -> Job<Dependency> {
        let job = Job<Dependency>(label: label, timeout: timeoutTimer.timeout, retry: retryer.retry - 1, block: block)
        job.isRetryJob = true
        job.delegate = delegate
        return job
    }
    
    /// triggered by JobQueue
    func onStart() {
        timeoutTimer.start()
        timeMeasurement.start()
        delegate?.job(onStart: self)
    }
    
    /// triggered by JobQueue
    func onCancel() {
        if isCompleted { return }
        isCompleted = true
        timeoutTimer.invalid()
        timeMeasurement.end()
        delegate?.job(job: self, onCompleteWith: JobError.canceled)
    }
    
    /// triggered by Job
    func onFailInValidation() {
        if isCompleted { return }
        isCompleted = true
        timeoutTimer.invalid()
        timeMeasurement.end()
        delegate?.job(job: self, onCompleteWith: JobError.invalid)
    }
    
    /// triggered by user
    /// JobObservable
    public func onSuccess() {
        if isCompleted { return }
        isCompleted = true
        timeoutTimer.invalid()
        timeMeasurement.end()
        delegate?.job(job: self, onCompleteWith: nil)
    }
    
    public func onError(error: JobError?) {
        if isCompleted { return }
        isCompleted = true
        timeoutTimer.invalid()
        timeMeasurement.end()
        self.error = JobError.customError(error: error)
        delegate?.job(job: self, onCompleteWith: self.error)
    }
    
    /// triggered by time
    //TimeoutTimerDelegate
    func onTimeout(_ timer: Timer) {
        if isCompleted { return }
        isCompleted = true
        timeoutTimer.invalid()
        timeMeasurement.end()
        delegate?.job(job: self, onCompleteWith: JobError.timeout)
    }

}

public protocol JobQueueDependency: class {
    
}

public class NoDependency: JobQueueDependency {
    
}

public protocol JobQueueInteractable: JobQueuePresentable {
    
    func verifyJobQueue(jobQueue: JobQueueInteractable) -> Bool
    func startJobQueue(jobQueue: JobQueueInteractable) -> Bool
    func findNextJob(jobQueue: JobQueueInteractable) -> Bool
    func verifyJob(jobQueue: JobQueueInteractable) -> Bool
    func prepareToRunJob(jobQueue: JobQueueInteractable) -> Bool
    func runJob(jobQueue: JobQueueInteractable) -> Bool
    func retryJob(jobQueue: JobQueueInteractable) -> Bool
    func onCompleteJob(jobQueue: JobQueueInteractable)
    func endJobQueue(jobQueue: JobQueueInteractable)
    func onTimeOut(jobQueue: JobQueueInteractable)
    func onForceCancel(jobQueue: JobQueueInteractable)
}

public enum JobQueueEvent {
    
    case initJobQueue
    case verifyJobQueue
    
    case startJobQueue
    
    case findNextJob
    case prepareToRunJob
    case verifyJob
    case runJob
    case retryJob
    case onCompleteJob
    case endJobQueue
    case onForceCancel
    case onTimeOut
}

public protocol JobQueuePresentable: class {
    
    var id: String { get }
    var label: String { get }
    var error: JobError? { get set }
    var jobQueueLog: JobQueueLog { get }
    var currentJob: JobPresentable? { get }
    var jobs: [JobPresentable] { get }
    var dependency: Any? { get }
    var event: JobQueueEvent { get }
    var isRunning: Bool { get }
    var isGuaranteedComplete: Bool { get }
    var executionTime: TimeInterval? { get }
}

public final class JobQueue<Dependency: JobQueueDependency>: JobQueuePresentable, JobQueueInteractable, JobDelegate, TimeoutTimerDelegate, CustomStringConvertible {
    
    public var description: String {
        return "JobQueue{id=\(id), name=\(label), timeoutTimer=\(timeoutTimer), timeMeasurement=\(timeMeasurement)"
    }
    
    public var currentJob: JobPresentable?
    
    public let id: String
    
    public let label: String
    
    public var jobs: [JobPresentable] {
        get {
            return _jobs
        }
    }
    
    fileprivate(set) var _jobs = [Job<Dependency>]()
    
    public var dependency: Any? {
        get {
            return _dependency
        }
        set {
            _dependency = newValue as? Dependency
        }
    }
    
    fileprivate(set) var _dependency: Dependency?
    
    public var isRunning: Bool = false
    
    var isCompleted: Bool = false
    
    public var event: JobQueueEvent {
        get {
            return _event
        }
    }
    
    fileprivate(set) var _event: JobQueueEvent = .initJobQueue
    
    public var error: JobError?
    
    fileprivate(set) var dispatchQueue: DispatchQueue
    
    fileprivate let timeoutTimer: TimeoutTimer
    
    public var executionTime: TimeInterval? {
        get {
            return timeMeasurement.diff
        }
    }
    
    fileprivate let timeMeasurement = TimeMeasurement()
    
    // Guarantee Complete
    
    fileprivate(set) var retainSelf: JobQueue?
    
    fileprivate(set) public var isGuaranteedComplete: Bool = false
    
    // Guarantee Complete End
    
    fileprivate(set) var logger: JobQueueLogger?
    
    public let jobQueueLog: JobQueueLog
    
    fileprivate(set) var completionHandler: ((JobQueue, JobError?) -> Void) = { _,_ in }
    
    fileprivate(set) var completionQueue: DispatchQueue?
    
    fileprivate let lock = NSLock()
    
    public init(label: String? = nil, dependency: Dependency? = nil, isGuaranteedComplete: Bool = false, timeout: TimeInterval = 0) {
        let uuid = UUID().uuidString
        self.id = uuid
        let _label = label ?? uuid
        self.label = _label
        self._dependency = dependency
        self.isGuaranteedComplete = isGuaranteedComplete
        timeoutTimer = TimeoutTimer(timeout: timeout)
        jobQueueLog = JobQueueLog(id: id, label: _label)
        logger = JobQueueLogger.shared
        dispatchQueue = .global()
        timeoutTimer.delegate = self
    }
    
    @discardableResult public func addJob(_ job: Job<Dependency>) -> JobQueue<Dependency> {
        lock.lock(); defer { lock.unlock() }
        if isRunning == true {
            fatalError("JobQueue is running. addJob() is not allow")
        }
        if isCompleted == true {
            fatalError("JobQueue is completed. addJob() is not allow")
        }
        job.delegate = self
        _jobs.append(job)
        return self
    }
    
    public func run(completion: @escaping ((JobQueue, JobError?) -> Void)) {
        if isGuaranteedComplete {
            retainSelf = self
        }
        completionHandler = completion
        dispatchEvent(event: .verifyJobQueue, jobQueue: self)
    }
    
    ///start: JobDelegate
    func job(onStart job: JobPresentable) {
    }
    
    func job(job: JobPresentable, onCompleteWith error: JobError?) {
        dispatchEvent(event: .onCompleteJob, jobQueue: self)
    }
    
    ///end: JobDelegate
    
    /// start: TimeoutTimerDelegate
    func onTimeout(_ timer: Timer) {
        dispatchEvent(event: .onTimeOut, jobQueue: self)
    }
    /// end: TimeoutTimerDelegate
    
    public func forceCancel(jobQueue: JobQueueInteractable) {
        dispatchEvent(event: .onForceCancel, jobQueue: jobQueue)
    }
    
    fileprivate func dispatchEvent(event: JobQueueEvent, jobQueue: JobQueueInteractable) {
        switch event {
        case .initJobQueue: break
        case .verifyJobQueue:
            if !jobQueue.verifyJobQueue(jobQueue: jobQueue) {
                dispatchEvent(event: .endJobQueue, jobQueue: jobQueue)
            } else {
                dispatchEvent(event: .startJobQueue, jobQueue: jobQueue)
            }
        case .startJobQueue:
            if !jobQueue.startJobQueue(jobQueue: jobQueue) {
                dispatchEvent(event: .endJobQueue, jobQueue: jobQueue)
            } else {
                dispatchEvent(event: .findNextJob, jobQueue: jobQueue)
            }
        case .findNextJob:
            let result = jobQueue.findNextJob(jobQueue: jobQueue)
            if !result {
                dispatchEvent(event: .endJobQueue, jobQueue: jobQueue)
            } else {
                dispatchEvent(event: .verifyJob, jobQueue: jobQueue)
            }
        case .verifyJob:
            if !jobQueue.verifyJob(jobQueue: jobQueue) {
                dispatchEvent(event: .endJobQueue, jobQueue: jobQueue)
            } else {
                dispatchEvent(event: .prepareToRunJob, jobQueue: jobQueue)
            }
        case .prepareToRunJob:
            if !jobQueue.prepareToRunJob(jobQueue: jobQueue) {
                dispatchEvent(event: .endJobQueue, jobQueue: jobQueue)
            } else {
                dispatchEvent(event: .runJob, jobQueue: jobQueue)
            }
        case .runJob: //wait JobQueueStatus change to .completeJob
            if !jobQueue.runJob(jobQueue: jobQueue) {
                dispatchEvent(event: .endJobQueue, jobQueue: jobQueue)
            }
        case .retryJob: //wait JobQueueStatus change to .completeJob
            if !jobQueue.retryJob(jobQueue: jobQueue) {
                dispatchEvent(event: .endJobQueue, jobQueue: jobQueue)
            }
        case .onCompleteJob:
            onCompleteJob(jobQueue: jobQueue)
            if jobQueue.currentJob!.error != nil {
                if jobQueue.currentJob!.shouldRetry() {
                    dispatchEvent(event: .retryJob, jobQueue: jobQueue)
                } else {
                    dispatchEvent(event: .endJobQueue, jobQueue: jobQueue)
                }
                return
            }
            dispatchEvent(event: .findNextJob, jobQueue: jobQueue)
        case .endJobQueue:
            jobQueue.endJobQueue(jobQueue: jobQueue)
        case .onTimeOut:
            jobQueue.onTimeOut(jobQueue: jobQueue)
            dispatchEvent(event: .endJobQueue, jobQueue: jobQueue)
        case .onForceCancel:
            jobQueue.onForceCancel(jobQueue: jobQueue)
            dispatchEvent(event: .endJobQueue, jobQueue: jobQueue)
        }
    }
    
    //JobQueueInteractable
    
    public func verifyJobQueue(jobQueue: JobQueueInteractable) -> Bool {
        if isRunning == true {
            error = .invalid
            return false
        }
        return true
    }

    public func startJobQueue(jobQueue: JobQueueInteractable) -> Bool {
        if isRunning == true {
            return false
        }
        
        if jobs.count == 0 {
            return false
        }
        
        isRunning = true
        timeoutTimer.start()
        timeMeasurement.start()
        logger?.onStart(jobQueue: jobQueue)
        return true
    }

    public func findNextJob(jobQueue: JobQueueInteractable) -> Bool {
        lock.lock(); defer { lock.unlock()}
        guard let job = _jobs.first else {
            currentJob = nil
            return false
        }
        currentJob = job
        _jobs.removeFirst()
        return true
    }
    public func verifyJob(jobQueue: JobQueueInteractable) -> Bool {
        
        guard error == nil else {
            return false
        }
        
        guard let job = currentJob else {
            return false
        }
        
        guard job.error == nil else {
            return false
        }
        
        return true
        
    }
    public func prepareToRunJob(jobQueue: JobQueueInteractable) -> Bool {
        return true
    }
    public func runJob(jobQueue: JobQueueInteractable) -> Bool {
        guard let job = currentJob else {
            return false
        }
        logger?.onStart(job: job, jobQueue: jobQueue)
        job.run(onDispatchQueue: dispatchQueue, dependency: _dependency)
        return true
    }
    public func retryJob(jobQueue: JobQueueInteractable) -> Bool {
        guard let job = currentJob else {
            return false
        }
        let retryJob = job.cloneForRetry()
        currentJob = retryJob
        logger?.onRetry(job: job, jobQueue: jobQueue)
        retryJob.run(onDispatchQueue: dispatchQueue, dependency: _dependency)
        return true
    }
    public func onCompleteJob(jobQueue: JobQueueInteractable) {
        guard let job = currentJob else {
            return
        }
        if job.error != nil && job.shouldRetry() {
            error = nil
        } else {
            error = job.error
        }
        logger?.onComplete(job: job, jobQueue: jobQueue, error: job.error)
    }
    public func endJobQueue(jobQueue: JobQueueInteractable) {
        lock.lock(); defer { lock.unlock()}
        guard isCompleted == false else {
            return
        }
        isCompleted = true
        isRunning = false
        timeoutTimer.invalid()
        timeMeasurement.end()
        logger?.onComplete(jobQueue: jobQueue, error: jobQueue.error)
        completionHandler(self, error)
        retainSelf = nil
    }
    public func onTimeOut(jobQueue: JobQueueInteractable) {
        lock.lock(); defer { lock.unlock()}
        for job in _jobs {
            job.delegate = nil
        }
        _jobs.removeAll()
        if let job = currentJob {
            job.forceCancel()
        }
        error = .timeout
    }
    public func onForceCancel(jobQueue: JobQueueInteractable) {
        lock.lock(); defer { lock.unlock()}
        for job in _jobs {
            job.delegate = nil
        }
        _jobs.removeAll()
        if let job = currentJob {
            job.forceCancel()
        }
        error = .canceled
    }
}

/// start: TimeMeasurement logic

class TimeMeasurement: CustomStringConvertible {
    
    var description: String {
        return "TimeMeasurement{startTime=\(startTime ?? 0.0), endTime=\(endTime ?? 0.0), diff=\(diff ?? 0.0)}"
    }

    typealias Block = (() -> Void)
    
    var diff: Double? {
        return _diff
    }
    
    private var _diff: CFAbsoluteTime?
    
    private var startTime: CFAbsoluteTime?
    
    private var endTime: CFAbsoluteTime?

    init() {}

    func start() {
        startTime = CFAbsoluteTimeGetCurrent()
    }

    func end() {
        guard let startTime = startTime else {
            return
        }
        endTime = CFAbsoluteTimeGetCurrent()
        _diff = endTime! - startTime
    }
    
    @discardableResult func reset() -> TimeMeasurement {
        _diff = nil
        startTime = nil
        endTime = nil
        return self
    }

}

/// end: TimeMeasurement logic

/// start: Timer for timeout logic

class TimeoutTimer: CustomStringConvertible {
    
    var description: String {
        return "TimeoutTimer{timer=\(String(describing: timer)), timeout=\(timeout)}"
    }
    
    var timer: Timer?
    
    private var onTimeout: ((Timer) -> Void)!
    
    var timeout: TimeInterval
    
    fileprivate weak var delegate: TimeoutTimerDelegate?
    
    init(timeout: TimeInterval) {
        self.timeout = timeout
    }
    
    func start() {
        if timeout == 0 {
            return
        }
        onTimeout = { [weak self] timer in
            self?.delegate?.onTimeout(timer)
        }
        DispatchQueue.main.async {
            self.timer = Timer(timeInterval: self.timeout, target: self, selector: #selector(TimeoutTimer.onTimeout(timer:)), userInfo: nil, repeats: false)
            RunLoop.current.add(self.timer!, forMode: RunLoopMode.commonModes)
        }
    }
    
    func restart(timeout: TimeInterval? = nil) {
        timer?.invalidate()
        timer = nil
        if let timeout = timeout {
            self.timeout = timeout
        }
        start()
    }
    
    func invalid() {
        timer?.invalidate()
    }
    
    func reset() {
        invalid()
        delegate = nil
    }
    
    @objc func onTimeout(timer: Timer) {
        onTimeout(timer)
    }

}

private protocol TimeoutTimerDelegate: class {
    
    func onTimeout(_ timer: Timer)
    
}

/// end: Timer for timeout logic

/// start: Retry logic

class JobQueueRetryer: CustomStringConvertible {
    
    var description: String {
        return "JobQueueRetryer{retry=\(retry), current=\(_current), shouldRetry=\(shouldRetry)}"
    }
    
    var shouldRetry: Bool {
        return _current < retry
    }
    
    let retry: Int
    
    var current: Int {
        return _current
    }
    
    private var _current: Int = 0
    
    private let lock = NSLock()
    
    init(retry: Int) {
        self.retry = retry
    }
    
    func markRetryOnce() {
        lock.lock(); defer { lock.unlock() }
        _current += 1
    }
    
    func reset() {
        lock.lock(); defer { lock.unlock() }
        _current = 0
    }
}

/// end: Retry logic

/// start: Log logic

public class JobQueueLog {
    
    let id: String
    
    let label: String
    
    var logs: [String] = []
    
    init(id: String, label: String) {
        self.id = id
        self.label = label
    }
}

class JobQueueLogger: JobQueueLoggerDelegate {
    
    static let shared: JobQueueLogger = JobQueueLogger()
    
#if DEBUG
    static var isShowLogInConsole: Bool = true
#else
    static var isShowLogInConsole: Bool = false
#endif
    
    weak var delegate: JobQueueLoggerDelegate?

    private let lock = NSLock()
    
    init() {
        delegate = self
    }
    
    private func log(_ jobQueueLog: JobQueueLog, message: String) {
        jobQueueLog.logs.append(message)
        delegate?.jobQueueLogger(self, logForJobQueue: message)
        if JobQueueLogger.isShowLogInConsole {
            print(message)
        }
    }
    
    func onStart(jobQueue: JobQueuePresentable) {
        if let message = delegate?.jobQueueLogger(self, onStart: jobQueue) {
            log(jobQueue.jobQueueLog, message: message)
        }
    }
    
    func onComplete(jobQueue: JobQueuePresentable, error: Error?) {
        if let message = delegate?.jobQueueLogger(self, onComplete: jobQueue, error: error) {
            log(jobQueue.jobQueueLog, message: message)
        }
    }
    
    func onStart(job: JobPresentable, jobQueue: JobQueuePresentable) {
        if let message = delegate?.jobQueueLogger(self, onStart: job, jobQueue: jobQueue) {
            log(jobQueue.jobQueueLog, message: message)
        }
    }
    
    func onRetry(job: JobPresentable, jobQueue: JobQueuePresentable) {
        if let message = delegate?.jobQueueLogger(self, onRetry: job, jobQueue: jobQueue) {
            log(jobQueue.jobQueueLog, message: message)
        }
    }
    
    func onComplete(job: JobPresentable, jobQueue: JobQueuePresentable, error: Error?) {
        if let message = delegate?.jobQueueLogger(self, onComplete: job, jobQueue: jobQueue, error: error) {
            log(jobQueue.jobQueueLog, message: message)
        }
    }
    
    // MARK: - JobQueueLoggerDelegate
    /// Redirect log to your log service
    func jobQueueLogger(_ logger: JobQueueLogger, logForJobQueue: String) {
        
    }
}

protocol JobQueueLoggerDelegate: class {
    
    func jobQueueLogger(_ logger: JobQueueLogger, logForJobQueue: String)
    
    func jobQueueLogger(_ logger: JobQueueLogger, onStart jobQueue: JobQueuePresentable) -> String
    
    func jobQueueLogger(_ logger: JobQueueLogger, onComplete jobQueue: JobQueuePresentable, error: Error?) -> String
    
    func jobQueueLogger(_ logger: JobQueueLogger, onStart job: JobPresentable, jobQueue: JobQueuePresentable) -> String
    
    func jobQueueLogger(_ logger: JobQueueLogger, onRetry job: JobPresentable, jobQueue: JobQueuePresentable) -> String
    
    func jobQueueLogger(_ logger: JobQueueLogger, onComplete job: JobPresentable, jobQueue: JobQueuePresentable,  error: Error?) -> String
}

extension JobQueueLoggerDelegate {
    
    func jobQueueLogger(_ logger: JobQueueLogger, onStart jobQueue: JobQueuePresentable) -> String {
        return "JobQueue(\(jobQueue.label)) - start"
    }
    
    func jobQueueLogger(_ logger: JobQueueLogger, onComplete jobQueue: JobQueuePresentable, error: Error?) -> String {
        return "JobQueue(\(jobQueue.label)) Error=\(String(describing: error)) - complete executionTime:\(jobQueue.executionTime ?? 0.0)"
    }
    
    func jobQueueLogger(_ logger: JobQueueLogger, onStart job: JobPresentable, jobQueue: JobQueuePresentable) -> String {
        return "JobQueue(\(jobQueue.label)) Job=(\(job.label)) - start "
    }
    
    func jobQueueLogger(_ logger: JobQueueLogger, onRetry job: JobPresentable, jobQueue: JobQueuePresentable) -> String {
        return "JobQueue(\(jobQueue.label)) Job=(\(job.label)) - retry"
    }
    
    func jobQueueLogger(_ logger: JobQueueLogger, onComplete job: JobPresentable, jobQueue: JobQueuePresentable,  error: Error?) -> String {
        return "JobQueue(\(jobQueue.label)) Job=(\(job.label)) Error=\(String(describing: error)) - complete executionTime:\(job.executionTime ?? 0.0)"
    }
}

/// end: Log logic
