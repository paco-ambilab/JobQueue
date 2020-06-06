//
//  ViewController.swift
//  Job
//
//  Created by paco89lol@gmail.com on 05/24/2020.
//  Copyright (c) 2020 paco89lol@gmail.com. All rights reserved.
//

import UIKit
import Job

class ViewController: UIViewController {

    var jobqueue: JobQueue<NoDependency>!
    override func viewDidLoad() {
        super.viewDidLoad()
        getUser()
        // Do any additional setup after loading the view, typically from a nib.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    func getUser() {
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
        
    }
}

