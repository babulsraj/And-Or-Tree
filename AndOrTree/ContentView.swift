//
//  ContentView.swift
//  AndOrTree
//
//  Created by MoEngage Raj on 02/12/23.
//

import SwiftUI

///nodoc
struct ContentView: View {
    let evaluator = MoEngageTriggerEvaluator()
    var body: some View {
        VStack {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundColor(.accentColor)
            Text("Hello, world!")
            Button("start") {
                start()
            }
            Spacer()
                .frame(height: 50)
            Button("traverse") {
                traverse()
            }
        }
        .padding()
    }
    
    func parseJson() -> [String:Any]? {
        if let path = Bundle.main.path(forResource: "filters2", ofType: "json") {
            do {
                  let data = try Data(contentsOf: URL(fileURLWithPath: path), options: .mappedIfSafe)
                  let jsonResult = try JSONSerialization.jsonObject(with: data, options: .mutableLeaves)
                  if let jsonResult = jsonResult as? Dictionary<String, Any> {
                            return jsonResult
                  }
              } catch {
                   return nil
              }
        }
        
        return nil
    }

     func start() {
        if let json = parseJson() {
          
            let paths = evaluator.createCampaignPaths(for: [json])

            print(paths)
        }
     }
    
    func traverse() {
        evaluator.traverseTree()
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
