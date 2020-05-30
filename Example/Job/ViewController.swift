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
        var time = 1
        
        jobqueue = JobQueue<NoDependency>(label: "http", dependency: nil, isGuaranteedComplete: true, timeout: 0)
        let job1 = Job<NoDependency>(label: "Job1") { (dependency, observable) in
            print("job1")
            observable.onSuccess()
        }
        let job2 = Job<NoDependency>(label: "Job2", retry: 1) { (dependency, observable) in
            print("job2")
            if time == 1 {
                time = 0
                observable.onError(error: nil)
            } else {
                observable.onSuccess()
            }
            
        }
        jobqueue.addJob(job1)
        jobqueue.addJob(job2)
        
        jobqueue.run { (queue, error) in
            print("completion \(error)")
        }
        
    }
}

