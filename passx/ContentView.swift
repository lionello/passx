//
//  ContentView.swift
//  passx
//
//  Created by Lionello Lunesu on 2021-12-28.
//

import SwiftUI

struct ContentView: View {
    let myWindow:NSWindow?
    
    @State
    private var query: String = "zc.qq.com"
    
    var body: some View {
        TextField("Query", text: $query)
            .font(.largeTitle)
            .padding()
            .onSubmit {
                do {
                    if let pw = try (NSApplication.shared.delegate as! AppDelegate).pass.getLogin(entry: query) {
                        self.myWindow?.close()
                        NSApplication.shared.hide(nil)
                        
                        Paste().paste(pw)
                    }
                } catch {
                    //ignore
                }
            }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(myWindow: nil)
    }
}

extension NSTextField {
    open override var focusRingType: NSFocusRingType {
        get { .none }
        set { }
    }
}

