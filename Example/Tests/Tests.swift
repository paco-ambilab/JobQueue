import XCTest
import Job

class Tests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testRetainSelf() {
        
        let expectation = XCTestExpectation(description: "")
        JobQueue(label: "RetainSelf", dependency: NoDependency(), isGuaranteedComplete: true, timeout: 0).addJob(Job<NoDependency>(label: "Job 1", block: { (dependency, result) in
            result.onSuccess()
        })).run { (queue, error) in
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5)
    }
    
    func testNoRetainSelf() {
        
        let expectation = XCTestExpectation(description: "")
        expectation.isInverted = true
        JobQueue(label: "RetainSelf", dependency: NoDependency(), isGuaranteedComplete: false, timeout: 0).addJob(Job<NoDependency>(label: "Job 1", block: { (dependency, result) in
            result.onSuccess()
        })).run { (queue, error) in
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5)
    }
    
    func testTimeoutForJob() {
        let expectation = XCTestExpectation(description: "")
        let timeout = 2
        
        JobQueue(label: "TestTimeoutForJob", dependency: NoDependency()).addJob(Job<NoDependency>(label: "A Timeout Job", timeout:  TimeInterval(timeout), block: { (dependency, result) in
            DispatchQueue.main.asyncAfter(deadline: .now()+10, execute: {
                result.onSuccess()
            })
        })).run { (queue, error) in
            XCTAssertEqual(error!, JobError.timeout)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 5)
    }
    
    func testNoTimeoutForJob() {
        let expectation = XCTestExpectation(description: "")
        JobQueue(label: "testNoTimeoutForJob", dependency: NoDependency()).addJob(Job<NoDependency>(label: "A Normal Job", timeout: 0, block: { (dependency, result) in
            DispatchQueue.main.asyncAfter(deadline: .now()+2, execute: {
                result.onSuccess()
            })
        })).run { (queue, error) in
            XCTAssertEqual(error, nil)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 5)
    }
    
    func testTimoutForJobQueue() {
        let expectation = XCTestExpectation(description: "")
        let timeout = 2
        JobQueue(label: "testTimoutForJobQueue", dependency: NoDependency(), timeout: TimeInterval(timeout)).addJob(Job<NoDependency>(label: "A Normal Job", block: { (dependency, result) in
            DispatchQueue.main.asyncAfter(deadline: .now()+5, execute: {
                result.onSuccess()
            })
        })).run { (queue, error) in
            XCTAssertEqual(error!, JobError.timeout)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 5)
    }
    
    func testNoTimeoutForJobQueue() {
        let expectation = XCTestExpectation(description: "")
        JobQueue(label: "testTimoutForJobQueue", dependency: NoDependency()).addJob(Job<NoDependency>(label: "A Normal Job", block: { (dependency, result) in
            DispatchQueue.main.asyncAfter(deadline: .now()+3, execute: {
                result.onSuccess()
            })
        })).run { (queue, error) in
            XCTAssertEqual(error, nil)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 5)
    }
    
    func testCancelJobQueue() {
        let expectation = XCTestExpectation(description: "")
        let jobQueue = JobQueue(label: "testTimoutForJobQueue", dependency: NoDependency()).addJob(Job<NoDependency>(label: "A Normal Job", block: { (dependency, result) in
            DispatchQueue.main.asyncAfter(deadline: .now()+3, execute: {
                result.onSuccess()
            })
        })).run { (queue, error) in
            XCTAssertEqual(error!, JobError.canceled)
            expectation.fulfill()
        }
        jobQueue.forceCancel()
        wait(for: [expectation], timeout: 5)
    }
    
    func testRetryForJobWithSuccess() {
        let expectation = XCTestExpectation(description: "")
        let retryTime = 3
        var count = 0
        JobQueue(label: "testTimoutForJobQueue", dependency: NoDependency()).addJob(Job<NoDependency>(label: "A Normal Job", retry: retryTime, block: { (dependency, result) in
            if count == retryTime {
                result.onSuccess()
            } else {
                count += 1
                result.onError(error: nil)
            }
        })).run { (queue, error) in
            XCTAssertEqual(error, nil)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 5)
    }
    
    func testRetryForJobWithFailure() {
        let expectation = XCTestExpectation(description: "")
        let retryTime = 3
        var count = 0
        JobQueue(label: "testTimoutForJobQueue", dependency: NoDependency()).addJob(Job<NoDependency>(label: "A Normal Job", retry: retryTime, block: { (dependency, result) in
            if count == retryTime+1 {
                result.onSuccess()
            } else {
                count += 1
                result.onError(error: nil)
            }
        })).run { (queue, error) in
            XCTAssertEqual(error!, JobError.customError(error: nil))
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 5)
    }
    
    func testRetryForJobWithJobQueueTimeout() {
        let expectation = XCTestExpectation(description: "")
        let timeout = 2
        let retryTime = 3
        var count = 0
        JobQueue(label: "testTimoutForJobQueue", dependency: NoDependency(), timeout: TimeInterval(timeout)).addJob(Job<NoDependency>(label: "A Normal Job", retry: retryTime, block: { (dependency, result) in
            if count == retryTime+1 {
                DispatchQueue.main.asyncAfter(deadline: .now()+1, execute: {
                    result.onSuccess()
                })
                
            } else {
                count += 1
                DispatchQueue.main.asyncAfter(deadline: .now()+1, execute: {
                    result.onError(error: nil)
                })
            }
        })).run { (queue, error) in
            XCTAssertEqual(error!, JobError.timeout)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 10)
    }
    
}
