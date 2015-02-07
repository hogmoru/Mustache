//
//  MustacheBox.swift
//
//  Created by Gwendal Roué on 08/11/2014.
//  Copyright (c) 2014 Gwendal Roué. All rights reserved.
//

import Foundation


// =============================================================================
// MARK: - Core rendering types

public enum ContentType {
    case Text
    case HTML
}

public struct Rendering {
    public var string: String
    public var contentType: ContentType
    
    public init(_ string: String, _ contentType: ContentType = .Text) {
        self.string = string
        self.contentType = contentType
    }
}

public struct RenderingInfo {
    public let tag: Tag
    public var context: Context
    let enumerationItem: Bool
    
    func renderingInfoBySettingEnumerationItem() -> RenderingInfo {
        return RenderingInfo(tag: tag, context: context, enumerationItem: true)
    }
}


// =============================================================================
// MARK: - Core function types

public typealias SubscriptFunction = (key: String) -> MustacheBox?
public typealias FilterFunction = (box: MustacheBox, partialApplication: Bool, error: NSErrorPointer) -> MustacheBox?
public typealias RenderFunction = (info: RenderingInfo, error: NSErrorPointer) -> Rendering?
public typealias WillRenderFunction = (tag: Tag, box: MustacheBox) -> MustacheBox
public typealias DidRenderFunction = (tag: Tag, box: MustacheBox, string: String?) -> Void


// =============================================================================
// MARK: - MustacheBox

public struct MustacheBox {
    public let isEmpty: Bool
    public let value: Any?
    public let mustacheBool: Bool
    public let objectForKeyedSubscript: SubscriptFunction?
    public let render: RenderFunction
    public let filter: FilterFunction?
    public let willRender: WillRenderFunction?
    public let didRender: DidRenderFunction?
    
    private init(mustacheBool: Bool? = nil, value: Any? = nil, objectForKeyedSubscript: SubscriptFunction? = nil, filter: FilterFunction? = nil, render: RenderFunction? = nil, willRender: WillRenderFunction? = nil, didRender: DidRenderFunction? = nil) {
        let empty = (value == nil) && (objectForKeyedSubscript == nil) && (render == nil) && (filter == nil) && (willRender == nil) && (didRender == nil)
        self.isEmpty = empty
        self.value = value
        self.mustacheBool = mustacheBool ?? !empty
        self.objectForKeyedSubscript = objectForKeyedSubscript
        self.filter = filter
        self.willRender = willRender
        self.didRender = didRender
        if let render = render {
            self.render = render
        } else {
            // Avoid compiler error: variable 'self.render' captured by a closure before being initialized
            self.render = { (info: RenderingInfo, error: NSErrorPointer) -> Rendering? in return nil }
            self.render = { (info: RenderingInfo, error: NSErrorPointer) -> Rendering? in
                switch info.tag.type {
                case .Variable:
                    if let value = value {
                        return Rendering("\(value)")
                    } else {
                        return Rendering("")
                    }
                case .Section:
                    return info.tag.render(info.context.extendedContext(self), error: error)
                }
            }
        }
    }
}

public func Box(mustacheBool: Bool? = nil, value: Any? = nil, objectForKeyedSubscript: SubscriptFunction? = nil, filter: FilterFunction? = nil, render: RenderFunction? = nil, willRender: WillRenderFunction? = nil, didRender: DidRenderFunction? = nil) -> MustacheBox {
    return MustacheBox(mustacheBool: mustacheBool, value: value, objectForKeyedSubscript: objectForKeyedSubscript, filter: filter, render: render, willRender: willRender, didRender: didRender)
}



// =============================================================================
// MARK: - MustacheBox derivation

extension MustacheBox {
    private func boxWithRenderFunction(render: RenderFunction) -> MustacheBox {
        return MustacheBox(
            value: value,
            mustacheBool: mustacheBool,
            objectForKeyedSubscript: objectForKeyedSubscript,
            render: render,
            filter: filter,
            willRender: willRender,
            didRender: didRender)
    }
}

public func Box(box: MustacheBox, # render: RenderFunction) -> MustacheBox {
    return box.boxWithRenderFunction(render)
}


// =============================================================================
// MARK: - Value unwrapping

extension MustacheBox {
    
    public var intValue: Int? {
        if let int = value as? Int {
            return int
        } else if let double = value as? Double {
            return Int(double)
        } else {
            return nil
        }
    }
    
    public var doubleValue: Double? {
        if let int = value as? Int {
            return Double(int)
        } else if let double = value as? Double {
            return double
        } else {
            return nil
        }
    }
    
    public var stringValue: String? {
        if value is NSNull {
            return nil
        } else if let value = value {
            return "\(value)"
        } else {
            return nil
        }
    }
}


// =============================================================================
// MARK: - DebugPrintable

extension MustacheBox: DebugPrintable {
    
    public var debugDescription: String {
        if let value = value {
            return "MustacheBox(\(value))"  // remove "Optional" from the output
        } else {
            return "MustacheBox(nil)"
        }
    }
}


// =============================================================================
// MARK: - Key extraction

extension MustacheBox {
    
    subscript(key: String) -> MustacheBox {
        if let objectForKeyedSubscript = objectForKeyedSubscript {
            if let box = objectForKeyedSubscript(key: key) {
                return box
            }
        }
        return Box()
    }
}


// =============================================================================
// MARK: - Boxing of Core Mustache functions

public func Box(objectForKeyedSubscript: SubscriptFunction) -> MustacheBox {
    return MustacheBox(objectForKeyedSubscript: objectForKeyedSubscript)
}

public func Box(filter: FilterFunction) -> MustacheBox {
    return MustacheBox(filter: filter)
}

public func Box(render: RenderFunction) -> MustacheBox {
    return MustacheBox(render: render)
}

public func Box(willRender: WillRenderFunction) -> MustacheBox {
    return MustacheBox(willRender: willRender)
}

public func Box(didRender: DidRenderFunction) -> MustacheBox {
    return MustacheBox(didRender: didRender)
}


// =============================================================================
// MARK: - Boxing of Swift scalar types

public protocol MustacheBoxable {
    var mustacheBox: MustacheBox { get }
}

public func Box(boxable: MustacheBoxable?) -> MustacheBox {
    if let boxable = boxable {
        return boxable.mustacheBox
    } else {
        return Box()
    }
}

extension MustacheBox: MustacheBoxable {
    public var mustacheBox: MustacheBox {
        return self
    }
}

extension Bool: MustacheBoxable {
    public var mustacheBox: MustacheBox {
        let render = { (info: RenderingInfo, error: NSErrorPointer) -> Rendering? in
            switch info.tag.type {
            case .Variable:
                return Rendering("\(self)")
            case .Section:
                if info.enumerationItem {
                    return info.tag.render(info.context.extendedContext(Box(self)), error: error)
                } else {
                    return info.tag.render(info.context, error: error)
                }
            }
        }
        return MustacheBox(
            value: self,
            mustacheBool: self,
            render: render)
    }
}

extension Int: MustacheBoxable {
    public var mustacheBox: MustacheBox {
        let render = { (info: RenderingInfo, error: NSErrorPointer) -> Rendering? in
            switch info.tag.type {
            case .Variable:
                return Rendering("\(self)")
            case .Section:
                if info.enumerationItem {
                    return info.tag.render(info.context.extendedContext(Box(self)), error: error)
                } else {
                    return info.tag.render(info.context, error: error)
                }
            }
        }
        return MustacheBox(
            value: self,
            mustacheBool: (self != 0),
            render: render)
    }
}

extension Double: MustacheBoxable {
    public var mustacheBox: MustacheBox {
        let render = { (info: RenderingInfo, error: NSErrorPointer) -> Rendering? in
            switch info.tag.type {
            case .Variable:
                return Rendering("\(self)")
            case .Section:
                if info.enumerationItem {
                    return info.tag.render(info.context.extendedContext(Box(self)), error: error)
                } else {
                    return info.tag.render(info.context, error: error)
                }
            }
        }
        return MustacheBox(
            value: self,
            mustacheBool: (self != 0.0),
            render: render)
    }
}

extension String: MustacheBoxable {
    public var mustacheBox: MustacheBox {
        let objectForKeyedSubscript = { (key: String) -> MustacheBox? in
            switch key {
            case "length":
                return Box(countElements(self))
            default:
                return nil
            }
        }
        let render = { (info: RenderingInfo, error: NSErrorPointer) -> Rendering? in
            switch info.tag.type {
            case .Variable:
                return Rendering("\(self)")
            case .Section:
                return info.tag.render(info.context.extendedContext(Box(self)), error: error)
            }
        }
        return MustacheBox(
            value: self,
            mustacheBool: (countElements(self) > 0),
            objectForKeyedSubscript: objectForKeyedSubscript,
            render: render)
    }
}


// =============================================================================
// MARK: - Boxing of Swift sequences

public func Box<S: SequenceType where S.Generator.Element: MustacheBoxable>(sequence: S?) -> MustacheBox {
    if let sequence = sequence {
        // We don't box the original sequence, but an Array<MustacheBox>.
        //
        // Why? By boxing an Array<MustacheBox>, we allow user code to recognize
        // and process all boxed arrays. See EachFilter for an example.
        return Box(map(sequence) { Box($0) })
    } else {
        return Box()
    }
}

private func renderSequenceFunction<S: SequenceType where S.Generator.Element: MustacheBoxable>(sequence: S) -> RenderFunction {
    return { (info: RenderingInfo, error: NSErrorPointer) -> Rendering? in
        if info.enumerationItem {
            return info.tag.render(info.context.extendedContext(Box(sequence)), error: error)
        } else {
            var buffer = ""
            var contentType: ContentType?
            let enumerationRenderingInfo = info.renderingInfoBySettingEnumerationItem()
            for item in sequence {
                let box = Box(item)
                if let boxRendering = box.render(info: enumerationRenderingInfo, error: error) {
                    if contentType == nil {
                        contentType = boxRendering.contentType
                        buffer += boxRendering.string
                    } else if contentType == boxRendering.contentType {
                        buffer += boxRendering.string
                    } else {
                        if error != nil {
                            error.memory = NSError(domain: GRMustacheErrorDomain, code: GRMustacheErrorCodeRenderingError, userInfo: [NSLocalizedDescriptionKey: "Content type mismatch"])
                        }
                        return nil
                    }
                } else {
                    return nil
                }
            }
            
            if let contentType = contentType {
                return Rendering(buffer, contentType)
            } else {
                return info.tag.render(info.context, error: error)
            }
        }
    }
}

public func Box(array: [MustacheBox]?) -> MustacheBox {
    if let array = array {
        let count = countElements(array)
        return MustacheBox(
            value: array,
            mustacheBool: (count > 0),
            objectForKeyedSubscript: { (key: String) -> MustacheBox? in
                switch key {
                case "count":
                    return Box(count)
                case "firstObject":
                    if count > 0 {
                        return Box(array[0])
                    } else {
                        return Box()
                    }
                case "lastObject":
                    if count > 0 {
                        return Box(array[count-1])
                    } else {
                        return Box()
                    }
                default:
                    return Box()
                }
            },
            render: renderSequenceFunction(array))
    } else {
        return Box()
    }
}


// =============================================================================
// MARK: - Boxing of Swift dictionaries

public func Box<T: MustacheBoxable>(dictionary: [String: T]?) -> MustacheBox {
    if let dictionary = dictionary {
        
        var boxDictionary: [String: MustacheBox] = [:]
        for (key, item) in dictionary {
            boxDictionary[key] = Box(item)
        }
        
        return MustacheBox(
            // We don't box the original dictionary, but a
            // Dictionary<String, MustacheBox>.
            //
            // Why?
            //
            // By boxing a Dictionary<String, MustacheBox>, we allow user code to
            // recognize and process all boxed dictionaries. See EachFilter for
            // an example.
            value: boxDictionary,
            mustacheBool: true,
            objectForKeyedSubscript: { (key: String) -> MustacheBox? in
                return boxDictionary[key]
            },
            render: { (info: RenderingInfo, error: NSErrorPointer) -> Rendering? in
                switch info.tag.type {
                case .Variable:
                    return Rendering("\(boxDictionary)")
                case .Section:
                    return info.tag.render(info.context.extendedContext(Box(dictionary)), error: error)
                }
            }
        )
    } else {
        return Box()
    }
}


// =============================================================================
// MARK: - Boxing of Objective-C types

// The MustacheBoxable protocol can not be used by Objc classes, because MustacheBox is
// not compatible with ObjC. So let's define another protocol.
@objc public protocol ObjCMustacheBoxable {
    // Can not return a MustacheBox, because MustacheBox is not compatible with ObjC.
    // So let's return an ObjC object which wraps a MustacheBox.
    var mustacheBox: ObjCMustacheBox { get }
}

// The ObjC object which wraps a MustacheBox (see ObjCMustacheBoxable)
public class ObjCMustacheBox: NSObject {
    let box: MustacheBox
    init(_ box: MustacheBox) {
        self.box = box
    }
}

public func Box(boxable: ObjCMustacheBoxable?) -> MustacheBox {
    if let boxable = boxable {
        return boxable.mustacheBox.box
    } else {
        return Box()
    }
}

public func BoxAnyObject(object: AnyObject?) -> MustacheBox {
    if let object: AnyObject = object {
        if let boxable = object as? ObjCMustacheBoxable {
            return Box(boxable)
        } else {
            // This code path will only run if object is not a NSObject
            // instance, since NSObject conforms to ObjCMustacheBoxable.
            //
            // This may mean that the class of object is NSProxy or any other
            // Objective-C class that does not derive from NSObject.
            //
            // This may also mean that object is an instance of a pure Swift
            // class.
            //
            // Objective-C objects and containers can contain pure Swift
            // instances. For example, given the following array:
            //
            //     class C: MustacheBoxable { ... }
            //     var array = NSMutableArray()
            //     array.addObject(C())
            //
            // GRMustache *can not* known that the array contains a valid
            // boxable value, because NSArray exposes its contents as AnyObject,
            // and AnyObject can not be tested for MustacheBoxable conformance:
            //
            // https://developer.apple.com/library/prerelease/ios/documentation/Swift/Conceptual/Swift_Programming_Language/Protocols.html#//apple_ref/doc/uid/TP40014097-CH25-XID_363
            // > you need to mark your protocols with the @objc attribute if you want to be able to check for protocol conformance.
            //
            // So GRMustache, when given an AnyObject, generally assumes that it
            // is an Objective-C value, even when it is wrong, and ends up here.
            //
            // As a conclusion: let's apologize.
            //
            // TODO: document caveat with something like:
            //
            // If GRMustache.BoxAnyObject was called from your own code, check
            // the type of the value you provide. If not, it is likely that an
            // Objective-C collection like NSArray, NSDictionary, NSSet or any
            // other Objective-C object contains a value that is not an
            // Objective-C object. GRMustache does not support such mixing of
            // Objective-C and Swift values.
            NSLog("Mustache.BoxAnyObject(): value `\(object)` does not conform to the ObjCMustacheBoxable protocol, and is discarded.")
            return Box()
        }
    } else {
        return Box()
    }
}

/**
Conform to the GRMustacheSafeKeyAccess protocol in order to filter the keys that
can be accessed by GRMustache templates.
*/
@objc public protocol GRMustacheSafeKeyAccess {

    /**
    List the name of the keys GRMustache.swift can access on this class using
    the `valueForKey:` method.

    When objects do not respond to this method, only declared properties can be
    accessed. All properties of Core Data NSManagedObjects are also accessible,
    even without property declaration.

    This method is not used for objects responding to objectForKeyedSubscript:.
    For those objects, all keys are accessible from templates.

    @return The set of accessible keys on the class.
    */
    class func safeMustacheKeys() -> NSSet
}

extension NSObject: ObjCMustacheBoxable {
    public var mustacheBox: ObjCMustacheBox {
        if let enumerable = self as? NSFastEnumeration
        {
            // Enumerable
            
            if respondsToSelector("objectForKeyedSubscript:")
            {
                // Dictionary-like enumerable
                //
                // We don't box the original enumerable, but a
                // Dictionary<String, MustacheBox>.
                //
                // Why?
                //
                // By boxing a Dictionary<String, MustacheBox>, we allow user code to
                // recognize and process all boxed dictionaries. See EachFilter for
                // an example.
                
                var dictionary: [String: MustacheBox] = [:]
                let generator = NSFastGenerator(enumerable)
                while let key = generator.next() as? String {
                    let item = (self as AnyObject)[key] // Cast to AnyObject so that we can access subscript notation.
                    dictionary[key] = BoxAnyObject(item)
                }
                return ObjCMustacheBox(Box(dictionary))
            }
            else
            {
                // Array-like enumerable
                //
                // We don't box the original enumerable, but an Array<MustacheBox>.
                //
                // Why? By boxing an Array<MustacheBox>, we allow user code to recognize
                // and process all boxed arrays. See EachFilter for an example.
                
                return ObjCMustacheBox(Box(map(GeneratorSequence(NSFastGenerator(enumerable))) { BoxAnyObject($0) }))
            }
        }
        else
        {
            // Generic NSObject
            
            return ObjCMustacheBox(MustacheBox(
                value: self,
                mustacheBool: true,
                objectForKeyedSubscript: { (key: String) -> MustacheBox? in
                    if self.respondsToSelector("objectForKeyedSubscript:")
                    {
                        // Use objectForKeyedSubscript: first (see https://github.com/groue/GRMustache/issues/66:)
                        return BoxAnyObject((self as AnyObject)[key]) // Cast to AnyObject so that we can access subscript notation.
                    }
                    else if GRMustacheKeyAccess.isSafeMustacheKey(key, forObject: self)
                    {
                        // Use valueForKey: for safe keys
                        return BoxAnyObject(self.valueForKey(key))
                    }
                    else
                    {
                        // Missing key
                        return Box()
                    }
                },
                render: { (info: RenderingInfo, error: NSErrorPointer) -> Rendering? in
                    switch info.tag.type {
                    case .Variable:
                        return Rendering("\(self)")
                    case .Section:
                        return info.tag.render(info.context.extendedContext(Box(self)), error: error)
                    }
            }))
        }
    }
}

extension NSNull: ObjCMustacheBoxable {
    public override var mustacheBox: ObjCMustacheBox {
        return ObjCMustacheBox(MustacheBox(
            value: self,
            mustacheBool: false,
            render: { (info: RenderingInfo, error: NSErrorPointer) -> Rendering? in
                switch info.tag.type {
                case .Variable:
                    return Rendering("")
                case .Section:
                    if info.enumerationItem {
                        return info.tag.render(info.context.extendedContext(Box(self)), error: error)
                    } else {
                        return info.tag.render(info.context, error: error)
                    }
                }
        }))
    }
}

extension NSNumber: ObjCMustacheBoxable {
    public override var mustacheBox: ObjCMustacheBox {
        let objCType = String.fromCString(self.objCType)!
        switch objCType {
        case "c", "i", "s", "l", "q", "C", "I", "S", "L", "Q":
            return ObjCMustacheBox(Box(Int(longLongValue)))
        case "f", "d":
            return ObjCMustacheBox(Box(doubleValue))
        case "B":
            return ObjCMustacheBox(Box(boolValue))
        default:
            NSLog("GRMustache support for NSNumber of type \(objCType) is not implemented yet: value is discarded.")
            return ObjCMustacheBox(Box())
        }
    }
}

extension NSString: ObjCMustacheBoxable {
    public override var mustacheBox: ObjCMustacheBox {
        return ObjCMustacheBox(Box(self as String))
    }
}

extension NSSet: ObjCMustacheBoxable {
    public override var mustacheBox: ObjCMustacheBox {
        return ObjCMustacheBox(MustacheBox(
            value: self,
            mustacheBool: (self.count > 0),
            objectForKeyedSubscript: { (key: String) -> MustacheBox? in
                switch key {
                case "count":
                    return Box(self.count)
                case "anyObject":
                    return BoxAnyObject(self.anyObject())
                default:
                    return nil
                }
            },
            render: renderSequenceFunction(map(GeneratorSequence(NSFastGenerator(self))) { BoxAnyObject($0) })))
    }
}