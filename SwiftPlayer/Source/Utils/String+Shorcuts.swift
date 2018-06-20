//
//  String+Shorcuts.swift
//  SwiftPlayer
//
//  Created by zhongzhendong on 2018/6/20.
//  Copyright © 2018年 zhongzhendong. All rights reserved.
//

import Foundation

extension String {
    
    func isMatch(regex: String, options: NSRegularExpression.Options) throws -> Bool {
        let exp = try NSRegularExpression(pattern: regex, options: options)
        let matchCount = exp.numberOfMatches(in: self, options: NSRegularExpression.MatchingOptions.anchored, range: NSMakeRange(0, self.count))
        return matchCount > 0
    }
    
    func isValidURL() -> Bool {
        let regEx = "((https|http)://)((\\w|-)+)(([.]|[/])((\\w|-)+))+"
        do {
            let result = try isMatch(regex: regEx, options: .anchorsMatchLines)
            return result
        } catch {
            return false
        }
    }
}
