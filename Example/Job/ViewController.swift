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
        let button = UIButton(frame: .zero)
        button.setTitle("Run Task", for: .normal)
        button.setTitleColor(.black, for: .normal)
        button.addTarget(self, action: #selector(didPressButton(_:)), for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(button)
        button.widthAnchor.constraint(equalToConstant: 120).isActive = true
        button.heightAnchor.constraint(equalToConstant: 40).isActive = true
        button.centerXAnchor.constraint(equalTo: self.view.centerXAnchor).isActive = true
        button.centerYAnchor.constraint(equalTo: self.view.centerYAnchor).isActive = true
        
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @objc func didPressButton(_ sender: Any) {
        runTask()
    }

    func runTask() {
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

