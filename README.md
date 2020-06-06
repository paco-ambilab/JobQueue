# Job

[![CI Status](https://img.shields.io/travis/paco89lol@gmail.com/Job.svg?style=flat)](https://travis-ci.org/paco89lol@gmail.com/Job)
[![Version](https://img.shields.io/cocoapods/v/Job.svg?style=flat)](https://cocoapods.org/pods/Job)
[![License](https://img.shields.io/cocoapods/l/Job.svg?style=flat)](https://cocoapods.org/pods/Job)
[![Platform](https://img.shields.io/cocoapods/p/Job.svg?style=flat)](https://cocoapods.org/pods/Job)
[![Build](https://github.com/paco-ambilab/JobQueue/workflows/Swift/badge.svg)](https://github.com/Tundaware/JobQueue/actions?query=workflow%3ASwift)

## Description

JobQueue is the way to avoid nested callbacks(Callback Hell). It is similar to PromiseKit. The main difference is this framework prefers not to pass or return a value between jobs/tasks. Those values cause complexity of maintaining due to one job/task change causing the change of the other job/tasks. To simplify it, we prefer to have a data dependency(Environment variable) in JobQueue, and jobs who are in the same JobQueue will share that environment variable.

`JobQueue` contains a list of  `Job`s and run them with sequence. It also provides features including:
- [X] timeout
- [X] time measurement
- [X] log delegate
- [X] retain self for extending the `JobQueue` lifecycle

`Job` contains a callback to execute the instruction. It also provides features including:
- [X] timeout
- [X] time measurement
- [X] retry

you can treat Job is a data class to storing the detail of job and allow JobQueue to make it runnable.

## Example

```swift
class MyDependency: JobQueueDependency {
    var jobName: String = ""
}
JobQueue(label: "TestMeasurement", dependency: MyDependency())
    .addJob(Job<MyDependency>(label: "Job 1", block: { (dependency, result) in
        dependency?.jobName = "Job 1"
        print("run Job 1")
        result.onSuccess()
})).addJob(Job<MyDependency>(label: "Job 2", block: { (dependency, result) in
    dependency?.jobName = "Job 2"
    print("run Job 2")
    result.onSuccess()
})).addJob(Job<MyDependency>(label: "Job 3", block: { (dependency, result) in
    dependency?.jobName = "Job 3"
    print("run Job 3")
    result.onSuccess()
})).run { (queue, error) in
    let dependency = queue.dependency as! MyDependency
    print("Last job name:\(dependency.jobName)")
}
```

### Job

```swift
let timeout = 2
let retryTime = 3
Job<NoDependency>(label: "A Normal Job", timeout: TimeInterval(timeout), retry: retryTime, block: { (dependency, result) in
    // mark as complete
    result.onSuccess()
})

```

### Log Record

![image](https://github.com/paco-ambilab/JobQueue/blob/master/Screenshot/Screenshot%202020-06-06%20at%207.35.26%20PM.png)


### Customizable Log and Redirect Log to Log server

```swift

class YourLogService: JobQueueLoggerDelegate {

    init() {
        JobQueueLogger.shared.delegate = self
    }
    
    // JobQueueLoggerDelegate
    
    func jobQueueLogger(_ logger: JobQueueLogger, logForJobQueue: String) {
        let message = logForJobQueue
        // here to upload message to server 
    }
    
    //Optional 
    //func jobQueueLogger(_ logger: JobQueueLogger, onStart jobQueue: JobQueuePresentable) -> String {}
    
    //func jobQueueLogger(_ logger: JobQueueLogger, onComplete jobQueue: JobQueuePresentable, error: Error?) -> String {}
    
    //func jobQueueLogger(_ logger: JobQueueLogger, onStart job: JobPresentable, jobQueue: JobQueuePresentable) -> String {}
    
    //func jobQueueLogger(_ logger: JobQueueLogger, onRetry job: JobPresentable, jobQueue: JobQueuePresentable) -> String {}
    
    //func jobQueueLogger(_ logger: JobQueueLogger, onComplete job: JobPresentable, jobQueue: JobQueuePresentable,  error: Error?) -> String {}
    
}


```


To run the example project, clone the repo, and run `pod install` from the Example directory first.

## Requirements

## Installation

Job is available through [CocoaPods](https://cocoapods.org). To install
it, simply add the following line to your Podfile:

```ruby
pod 'Job', :git => 'https://github.com/paco-ambilab/JobQueue.git'
```

## Author

paco89lol@gmail.com, paco89lol@gmail.com

## License

Job is available under the MIT license. See the LICENSE file for more info.
