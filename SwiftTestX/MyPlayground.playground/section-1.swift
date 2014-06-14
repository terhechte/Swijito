// Playground - noun: a place where people can play

import Cocoa

var str = "Hello, playground"

func secretMethod() -> String? {
    return "Yes"
}

var result: String? = secretMethod()
switch result {
case .None:
    println("is nothing")
case let a:
    println("is a value")
}





