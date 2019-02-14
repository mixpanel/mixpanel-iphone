//
//  SelectorEvaluator.swift
//  Mixpanel
//
//  Created by Madhu Palani on 3/12/19.
//  Copyright © 2019 Mixpanel. All rights reserved.
//
//  This file is a copy of <github link with commit>
//

import Foundation

extension DateFormatter {
    static func formatterForJSONDate() -> DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }
}

public typealias Properties = [String: Any]

public class SelectorEvaluator: NSObject {
    // Key words
    static let OPERATOR_KEY = "operator"
    static let CHILDREN_KEY = "children"
    static let PROPERTY_KEY = "property"
    static let VALUE_KEY = "value"
    static let EVENT_KEY = "event"
    static let LITERAL_KEY = "literal"
    static let WINDOW_KEY = "window"
    static let UNIT_KEY = "unit"
    static let HOUR_KEY = "hour"
    static let DAY_KEY = "day"
    static let WEEK_KEY = "week"
    static let MONTH_KEY = "month"
    // Typecast operators
    static let BOOLEAN_OPERATOR = "boolean"
    static let DATETIME_OPERATOR = "datetime"
    static let LIST_OPERATOR = "list"
    static let NUMBER_OPERATOR = "number"
    static let STRING_OPERATOR = "string"
    // Binary operators
    static let AND_OPERATOR = "and"
    static let OR_OPERATOR = "or"
    static let IN_OPERATOR = "in"
    static let NOT_IN_OPERATOR = "not in"
    static let PLUS_OPERATOR = "+"
    static let MINUS_OPERATOR = "-"
    static let MUL_OPERATOR = "*"
    static let DIV_OPERATOR = "/"
    static let MOD_OPERATOR = "%"
    static let EQUALS_OPERATOR = "=="
    static let NOT_EQUALS_OPERATOR = "!="
    static let GREATER_THAN_OPERATOR = ">"
    static let GREATER_THAN_EQUAL_OPERATOR = ">="
    static let LESS_THAN_OPERATOR = "<"
    static let LESS_THAN_EQUAL_OPERATOR = "<="
    // Unary operators
    static let NOT_OPERATOR = "not"
    static let DEFINED_OPERATOR = "defined"
    static let NOT_DEFINED_OPERATOR = "not defined"
    // Special words
    static let NOW_LITERAL = "now"
    
    // private const
    private static let LEFT = 0
    private static let RIGHT = 1
    
    // For testing purposes
    class func getCurrentDate() -> Date {
        return Date();
    }
    
    class func toNumber(value: Any?) -> Double? {
        if let val = value {
            switch val {
            case let bool as Bool:
                return bool ? 1 : 0
            case let date as Date:
                return date.timeIntervalSince1970 > 0 ? date.timeIntervalSince1970 : nil
            case let num as NSNumber:
                return num.doubleValue
            case let str as String:
                if let int = Int(str) {
                    return Double(int)
                }
                if let double = Double(str) {
                    return double
                }
                return 0.0
            default:
                return nil
            }
        }
        return nil
    }
    
    class func toBoolean(value: Any?) -> Bool {
        if let val = value {
            switch val {
            case let bool as Bool:
                return bool
            case let num as NSNumber:
                return num.doubleValue != 0 ? true : false
            case let str as String:
                return str.count > 0 ? true : false
            case let arr as [Any?]:
                return arr.count > 0 ? true : false
            case let dict as [String: Any]:
                return dict.count > 0 ? true : false
            case let date as Date:
                return date.timeIntervalSince1970 > 0 ? true : false
            default:
                return false
            }
        }
        return false
    }
    
    class func evaluateNumber(node: [String: Any], properties: Properties?) -> Double? {
        guard let op = node[OPERATOR_KEY] as? String, op == NUMBER_OPERATOR else {
            return nil
        }
        guard let children = node[CHILDREN_KEY] as? [[String: Any]], children.count == 1 else {
            return nil
        }
        
        return toNumber(value: evaluateNode(node: children[LEFT], properties: properties))
    }
    
    class func evaluateBoolean(node: [String: Any], properties: Properties?) -> Bool? {
        guard let op = node[OPERATOR_KEY] as? String, op == BOOLEAN_OPERATOR else {
            return nil
        }
        guard let children = node[CHILDREN_KEY] as? [[String: Any]], children.count == 1 else {
            return nil
        }
        
        return toBoolean(value: evaluateNode(node: children[LEFT], properties: properties))
    }
    
    class func evaluateDateTime(node: [String: Any], properties: Properties?) -> Date? {
        guard let op = node[OPERATOR_KEY] as? String, op == DATETIME_OPERATOR else {
            return nil
        }
        guard let children = node[CHILDREN_KEY] as? [[String: Any]], children.count == 1 else {
            return nil
        }
        
        if let value = evaluateNode(node: children[LEFT], properties: properties) {
            switch value {
            case _ as Bool:
                return nil
            case let num as NSNumber:
                return Date(timeIntervalSince1970: num.doubleValue)
            case let str as String:
                let dateFormatter = DateFormatter.formatterForJSONDate()
                if let date = dateFormatter.date(from: str) {
                    return date
                }
                return nil
            case let date as Date:
                return date
            default:
                return nil
            }
        }
        return nil
    }
    
    class func evaluateList(node: [String: Any], properties: Properties?) -> [Any]? {
        guard let op = node[OPERATOR_KEY] as? String, op == LIST_OPERATOR else {
            return nil
        }
        guard let children = node[CHILDREN_KEY] as? [[String: Any]], children.count == 1 else {
            return nil
        }
        
        if let value = evaluateNode(node: children[LEFT], properties: properties) as? [Any] {
            return value
        }
        return nil
    }
    
    private class func jsonStringify(value: Any) -> String? {
        guard let jsonData = try? JSONSerialization.data(withJSONObject: value) else {
            return nil
        }
        return String(data: jsonData, encoding: .utf8)
    }
    
    class func evaluateString(node: [String: Any], properties: Properties?) -> String? {
        guard let op = node[OPERATOR_KEY] as? String, op == STRING_OPERATOR else {
            return nil
        }
        guard let children = node[CHILDREN_KEY] as? [[String: Any]], children.count == 1 else {
            return nil
        }
        
        if let value = evaluateNode(node: children[LEFT], properties: properties) {
            switch value {
            case let bool as Bool:
                return String(bool)
            case let dt as Date:
                return DateFormatter.formatterForJSONDate().string(from: dt)
            case let num as NSNumber:
                return num.stringValue
            case let arr as [Any]:
                return jsonStringify(value: arr)
            case let obj as [String: Any]:
                return jsonStringify(value: obj)
            default:
                return nil
            }
        }
        return nil
    }
    
    class func evaluateAnd(node: [String: Any], properties: Properties?) -> Bool? {
        guard let op = node[OPERATOR_KEY] as? String, op == AND_OPERATOR else {
            return nil
        }
        guard let children = node[CHILDREN_KEY] as? [[String: Any]], children.count == 2 else {
            return nil
        }
        
        return toBoolean(value: evaluateNode(node: children[LEFT], properties: properties)) && toBoolean(value: evaluateNode(node: children[RIGHT], properties: properties))
    }
    
    class func evaluateOr(node: [String: Any], properties: Properties?) -> Bool? {
        guard let op = node[OPERATOR_KEY] as? String, op == OR_OPERATOR else {
            return nil
        }
        guard let children = node[CHILDREN_KEY] as? [[String: Any]], children.count == 2 else {
            return nil
        }
        
        return toBoolean(value: evaluateNode(node: children[LEFT], properties: properties)) || toBoolean(value: evaluateNode(node: children[RIGHT], properties: properties))
    }
    
    class func evaluateIn(node: [String: Any], properties: Properties?) -> Bool? {
        let inOperators = [IN_OPERATOR, NOT_IN_OPERATOR]
        guard let op = node[OPERATOR_KEY] as? String, inOperators.contains(op) else {
            return nil
        }
        guard let children = node[CHILDREN_KEY] as? [[String: Any]], children.count == 2 else {
            return nil
        }
        
        let l = evaluateNode(node: children[LEFT], properties: properties)
        let r = evaluateNode(node: children[RIGHT], properties: properties)
        var b = false
        
        switch (l, r) {
        case (let lStr as String, let rStr as String):
            b = rStr.contains(lStr)
            break
        case (_, let rArr as [Any]):
            if let l = l {
                b = NSSet(array: rArr).contains(l)
            }
            break
        default:
            b = false
        }
        
        return op == IN_OPERATOR ? b : !b
    }
    
    class func evaluatePlus(node: [String: Any], properties: Properties?) -> Any? {
        guard let op = node[OPERATOR_KEY] as? String, op == PLUS_OPERATOR else {
            return nil
        }
        guard let children = node[CHILDREN_KEY] as? [[String: Any]], children.count == 2 else {
            return nil
        }
        
        let l = evaluateNode(node: children[LEFT], properties: properties)
        let r = evaluateNode(node: children[RIGHT], properties: properties)
        
        switch (l, r) {
        case (let lStr as String, let rStr as String):
            return "\(lStr)\(rStr)"
        case (let lNum as NSNumber, let rNum as NSNumber):
            return lNum.doubleValue + rNum.doubleValue
        default:
            return nil
        }
    }
    
    class func evaluateArithmetic(node: [String: Any], properties: Properties?) -> Double? {
        let arithmeticOperators = [MINUS_OPERATOR, MUL_OPERATOR, DIV_OPERATOR, MOD_OPERATOR]
        guard let op = node[OPERATOR_KEY] as? String, arithmeticOperators.contains(op) else {
            return nil
        }
        guard let children = node[CHILDREN_KEY] as? [[String: Any]], children.count == 2 else {
            return nil
        }
        
        let l = evaluateNode(node: children[LEFT], properties: properties)
        let r = evaluateNode(node: children[RIGHT], properties: properties)
        
        switch (l, r) {
        case (let lNum as NSNumber, let rNum as NSNumber):
            let ld = lNum.doubleValue
            let rd = rNum.doubleValue
            switch op {
            case MINUS_OPERATOR:
                return ld - rd
            case MUL_OPERATOR:
                return ld * rd
            case DIV_OPERATOR:
                return rd != 0 ? ld / rd : nil
            case MOD_OPERATOR:
                if (rd == 0) {
                    return nil
                }
                if (ld == 0) {
                    return 0
                }
                if ((ld < 0 && rd > 0) || (ld > 0 && rd < 0)) {
                    return -(floor(ld/rd) * rd - ld)
                }
                return ld.truncatingRemainder(dividingBy: rd)
            default:
                return nil
            }
        default:
            return nil
        }
    }
    
    private class func equals(l: Any?, r: Any?) -> Bool {
        switch (l, r) {
        case (nil, nil):
            return true
        case (let lBool as Bool, let rBool as Bool):
            return lBool == rBool
        case (let lNum as NSNumber, let rNum as NSNumber):
            return lNum.isEqual(to: rNum)
        case (let lStr as String, let rStr as String):
            return lStr == rStr
        case (let lDate as Date, let rDate as Date):
            return lDate == rDate
        case (let lDict as [String: Any], let rDict as [String: Any]):
            return NSDictionary(dictionary: lDict).isEqual(to: rDict)
        case (let lArr as [Any], let rArr as [Any]):
            return NSArray(array: lArr).isEqual(to: rArr)
        default:
            return false
        }
    }
    
    class func evaluateEquality(node: [String: Any], properties: Properties?) -> Bool? {
        let supportedOperators = [EQUALS_OPERATOR, NOT_EQUALS_OPERATOR]
        guard let op = node[OPERATOR_KEY] as? String, supportedOperators.contains(op) else {
            return nil
        }
        guard let children = node[CHILDREN_KEY] as? [[String: Any]], children.count == 2 else {
            return nil
        }
        
        let l = evaluateNode(node: children[LEFT], properties: properties)
        let r = evaluateNode(node: children[RIGHT], properties: properties)
        let b = equals(l: l, r: r)
        
        return op == NOT_EQUALS_OPERATOR ? !b : b
    }
    
    private class func compareDoubles(ld: Double, rd: Double, op: String) -> Bool? {
        switch(op) {
        case GREATER_THAN_OPERATOR:
            return ld > rd
        case GREATER_THAN_EQUAL_OPERATOR:
            return ld >= rd
        case LESS_THAN_OPERATOR:
            return ld < rd
        case LESS_THAN_EQUAL_OPERATOR:
            return ld <= rd
        default:
            return nil
        }
    }
    
    class func evaluateComparison(node: [String: Any], properties: Properties?) -> Bool? {
        let supportedOperators = [GREATER_THAN_OPERATOR, GREATER_THAN_EQUAL_OPERATOR, LESS_THAN_OPERATOR, LESS_THAN_EQUAL_OPERATOR]
        guard let op = node[OPERATOR_KEY] as? String, supportedOperators.contains(op) else {
            return nil
        }
        guard let children = node[CHILDREN_KEY] as? [[String: Any]], children.count == 2 else {
            return nil
        }
        
        let l = evaluateNode(node: children[LEFT], properties: properties)
        let r = evaluateNode(node: children[RIGHT], properties: properties)
        switch (l, r) {
        case (let lNum as NSNumber, let rNum as NSNumber):
            return compareDoubles(ld: lNum.doubleValue, rd: rNum.doubleValue, op: op)
        case (let lDate as Date, let rDate as Date):
            return compareDoubles(ld: lDate.timeIntervalSince1970, rd: rDate.timeIntervalSince1970, op: op)
        case (let lStr as String, let rStr as String):
            switch op {
            case GREATER_THAN_OPERATOR:
                return lStr.lowercased() > rStr.lowercased()
            case GREATER_THAN_EQUAL_OPERATOR:
                return lStr.lowercased() >= rStr.lowercased()
            case LESS_THAN_OPERATOR:
                return lStr.lowercased() < rStr.lowercased()
            case LESS_THAN_EQUAL_OPERATOR:
                return lStr.lowercased() <= rStr.lowercased()
            default:
                return nil
            }
        default:
            return nil
        }
    }
    
    class func evaluateDefined(node: [String: Any], properties: Properties?) -> Bool? {
        let supportedOperators = [DEFINED_OPERATOR, NOT_DEFINED_OPERATOR]
        guard let op = node[OPERATOR_KEY] as? String, supportedOperators.contains(op) else {
            return nil
        }
        guard let children = node[CHILDREN_KEY] as? [[String: Any]], children.count == 1 else {
            return nil
        }
        
        let b = evaluateNode(node: children[LEFT], properties: properties) != nil ? true : false
        return op == DEFINED_OPERATOR ? b : !b
    }
    
    class func evaluateNot(node: [String: Any], properties: Properties?) -> Bool? {
        guard let op = node[OPERATOR_KEY] as? String, op == NOT_OPERATOR else {
            return nil
        }
        guard let children = node[CHILDREN_KEY] as? [[String: Any]], children.count == 1 else {
            return nil
        }
        
        let v = evaluateNode(node: children[LEFT], properties: properties)
        switch (v) {
        case let b as Bool:
            return !b
        case nil:
            return true
        default:
            return nil
        }
    }
    
    class func evaluateWindow(value: [String: Any]) -> Date? {
        guard let window = value[WINDOW_KEY] as? [String: Any] else {
            return nil
        }
        
        guard let value = window[VALUE_KEY] as? NSNumber else {
            return nil
        }
        
        guard let unit = window[UNIT_KEY] as? String else {
            return nil
        }
        let date = getCurrentDate()
        switch unit {
        case HOUR_KEY:
            return date.addingTimeInterval(-1 * value.doubleValue * 60 * 60)
        case DAY_KEY:
            return date.addingTimeInterval(-1 * value.doubleValue * 24 * 60 * 60)
        case WEEK_KEY:
            return date.addingTimeInterval(-1 * value.doubleValue * 7 * 24 * 60 * 60)
        case MONTH_KEY:
            return date.addingTimeInterval(-1 * value.doubleValue * 30 * 24 * 60 * 60)
        default:
            return nil
        }
    }
    
    class func evaluateOperand(node: [String: Any], properties: Properties?) -> Any? {
        guard let property = node[PROPERTY_KEY] as? String else {
            return nil
        }
        
        guard let value = node[VALUE_KEY] else {
            return nil
        }
        
        switch property {
        case EVENT_KEY:
            guard let valueStr = value as? String else {
                return nil
            }
            return properties?[valueStr]
        case LITERAL_KEY:
            switch value {
            case let valueStr as String:
                if valueStr == NOW_LITERAL {
                    return getCurrentDate()
                }
                return valueStr
            case let valueObj as [String: Any]:
                return evaluateWindow(value: valueObj)
            default:
                return value
            }
        default:
            return nil
        }
    }
    
    class func evaluateOperator(node: [String: Any], properties: Properties?) -> Any? {
        guard let op = node[OPERATOR_KEY] as? String else {
            return nil
        }
        
        switch op {
        case AND_OPERATOR:
            return evaluateAnd(node: node, properties: properties)
        case OR_OPERATOR:
            return evaluateOr(node: node, properties: properties)
        case IN_OPERATOR, NOT_IN_OPERATOR:
            return evaluateIn(node: node, properties: properties)
        case PLUS_OPERATOR:
            return evaluatePlus(node: node, properties: properties)
        case MINUS_OPERATOR, MUL_OPERATOR, MOD_OPERATOR, DIV_OPERATOR:
            return evaluateArithmetic(node: node, properties: properties)
        case EQUALS_OPERATOR, NOT_EQUALS_OPERATOR:
            return evaluateEquality(node: node, properties: properties)
        case GREATER_THAN_OPERATOR, GREATER_THAN_EQUAL_OPERATOR, LESS_THAN_OPERATOR, LESS_THAN_EQUAL_OPERATOR:
            return evaluateComparison(node: node, properties: properties)
        case BOOLEAN_OPERATOR:
            return evaluateBoolean(node: node, properties: properties)
        case STRING_OPERATOR:
            return evaluateString(node: node, properties: properties)
        case LIST_OPERATOR:
            return evaluateList(node: node, properties: properties)
        case NUMBER_OPERATOR:
            return evaluateNumber(node: node, properties: properties)
        case DATETIME_OPERATOR:
            return evaluateDateTime(node: node, properties: properties)
        case DEFINED_OPERATOR, NOT_DEFINED_OPERATOR:
            return evaluateDefined(node: node, properties: properties)
        case NOT_OPERATOR:
            return evaluateNot(node: node, properties: properties)
        default:
            return nil
        }
    }
    
    class func evaluateNode(node: [String: Any], properties: Properties?) -> Any? {
        if let _ = node[PROPERTY_KEY] {
            return evaluateOperand(node: node, properties: properties)
        }
        
        return evaluateOperator(node: node, properties: properties)
    }
    
    @objc public class func evaluate(selector: [String: Any], properties: Properties?) -> Bool {
        if let value = SelectorEvaluator.evaluateOperator(node: selector, properties: properties) {
            return SelectorEvaluator.toBoolean(value: value)
        }
        return false
    }
}
