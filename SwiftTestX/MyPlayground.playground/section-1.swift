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

var a: NSDictionary = NSDictionary()

switch (a["a"], a["b"], a["c"]) {
case (.Some(let xa), .Some(let xb), .Some(let xc)):
    println("xa \(xa) xb\(xb) xc\(xc)")
default:
    println("none")
}






