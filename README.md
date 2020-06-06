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

To run the example project, clone the repo, and run `pod install` from the Example directory first.


## Requirements

## Installation

Job is available through [CocoaPods](https://cocoapods.org). To install
it, simply add the following line to your Podfile:

```ruby
pod 'Job'
```

## Author

paco89lol@gmail.com, paco89lol@gmail.com

## License

Job is available under the MIT license. See the LICENSE file for more info.
