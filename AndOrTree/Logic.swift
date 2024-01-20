//
//  Logic.swift
//  AndOrTree
//
//  Created by Babul Raj on 02/12/23.
//

import Foundation


class Tracker {
    let sq = DispatchQueue(label:"hahah")
    let sema = DispatchSemaphore(value: 1)
    let sema1 = DispatchSemaphore(value: 1)
    func addEvent(event:String) {
        sq.async {
            self.sema.wait()
            print(event)
            
            if event.contains("f") {
                self.flush {
                    self.sema.signal()
                }
            } else {
                self.sema.signal()
            }
        }
    }
    
    func flushFromOutside(name:String) {
        print(name, " called")
        sq.async {
            self.sema.wait()
            print(name, " started")
            self.flush {
                print(name, " ended")
                self.sema.signal()
            }
        }
    }
    
    func flush(completion:@escaping ()->()) {
        
        //sq.async {
           // self.sema.wait()
            DispatchQueue(label: "com.raywenderlich.worker", attributes: .concurrent).async {
                for i in 1...10 {
                    print(i)
                }
                
                sleep(1)
                completion()
            }
        //}
    }
}
