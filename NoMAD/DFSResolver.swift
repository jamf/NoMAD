//
//  DFSResolver.swift
//  NoMAD
//
//  Created by Benedikt Wiesnet, on 08.12.17.
//

import Foundation
import NetFS

extension String {
    //: ### Base64 encoding a string
    func base64Encoded() -> String? {
        if let data = self.data(using: .utf16) {
            return data.base64EncodedString()
        }
        return nil
    }
    
    //: ### Base64 decoding a string
    func base64Decoded() -> String? {
        if let data = Data(base64Encoded: self) {
            return String(data: data, encoding: .utf16)
        }
        return nil
    }
}

class DFSResolver: NSObject {
    
    static func checkAndReplace(url: URL)->String{
        let test = DFSResolver()
        do{
            myLogger.logit(.debug, message: "Try if \(url.absoluteString) is a dfs share!")
            let (result,str) = try test.resolve(dfspath: url.absoluteString)
            myLogger.logit(.debug, message: "Response for  \(url.absoluteString) is: \(result) with \(str ?? "")")
            if(result){
                myLogger.logit(.debug, message: "Replaced Mount: \( test.replace(dfspath: url.absoluteString, sharepath: str!))")
                return test.replace(dfspath: url.absoluteString, sharepath: str!)
            }else{
                return url.absoluteString
            }
            
        }catch {
            myLogger.logit(.base, message: "\(error.localizedDescription)")
            return url.absoluteString
        }
    }
    
    func replace(dfspath: String, sharepath: String)->String{
        var result = sharepath
        var rest: [String] = []
        if(dfspath.contains("://")){
            rest = dfspath.components(separatedBy: "://")[1].components(separatedBy: "/")
        }else{
            rest = dfspath.components(separatedBy: "/")
        }
        
        if(rest.count >= 2){
            rest.remove(at: 1)
            rest.remove(at: 0)
            result+="/"+rest.joined(separator: "/")
        }
        return result
    }
    
    func resolve(dfspath: String) throws ->(Bool,String?){
        let (server,namespace) = splitDFSPath(dfspath: dfspath)
        let base = getBaseDN(server: server)
        let uncRaw = try queryLDAP(server: server,namespace: namespace,base: base)
        let unc = decode(base64: uncRaw)
        if(unc.count > 0){
            return (true,unc[0])
        }
        return (false,nil)
    }
    
    // Splits DFS Addresses, returns server and namespace
    // which is localhost and SorryThereIsNoDFS if input (dfspath) has an invalid format
    func splitDFSPath(dfspath: String)->(String,String){
        var pathWithoutProtocol = ""
        
        if(dfspath.contains("://")){
            pathWithoutProtocol = dfspath.components(separatedBy: "://")[1]
        }else{
            pathWithoutProtocol = dfspath
        }
        
        if(pathWithoutProtocol.contains("/")){
            return (pathWithoutProtocol.components(separatedBy: "/")[0],pathWithoutProtocol.components(separatedBy: "/")[1])
        }
        
        return ("localhost","SorryThereIsNoDFS")
    }
    
    // Transforms Base Adress example.org to DC=example,DC=org,
    // returns empty string when format is not fqdn of server
    func getBaseDN(server: String)->String{
        var result = ""
        let split = server.components(separatedBy: ".")
        if(split.count <= 0){
            return result
        }
        for dc in split {
            result = result+"DC="+dc+","
        }
        result = result.substring(to: result.index(before: result.endIndex))
        return result;
    }
    
    func queryLDAP(server: String, namespace: String, base: String) throws -> String{
        let ldaputils = LDAPServers()
        //ldaputils.staticServer = server
        ldaputils.setDomain(server)
        ldaputils.defaultNamingContext = base
        let tempResult : [[String:String]] = try ldaputils.getLDAPInformation(["(&(objectClass=msDFS-Namespacev2)(cn="+namespace+"))"])
        // Look for "msDFS-TargetListv2"
        if(tempResult.count <= 0){
            return ""
        }else{
            if let result = tempResult[0]["msDFS-TargetListv2"]{
                return result
            }else{
                return ""
            }
        }
    }
    
    func decode(base64: String)->[String] {
        let result = base64.base64Decoded()
        if result == "" {
            return []
        }
        let data = result!.data(using: .utf16)
        let parser2 = XML(data: data!)
        if(parser2.children.count     >= 0 && parser2.children[0].children.count >= 0){
            var response: [String] = []
            for child in parser2.children[0].children {
                if(child.attributes["state"] == "online"){
                    let trim: String = child.text.replacingOccurrences(of: "\\\\", with: "")
                    response.append("smb://"+trim.replacingOccurrences(of: "\\", with: "/"))
                }
            }
            return response
        }else{
            return []
        }
    }
}

//Use XML class for XML document
//Parse using Foundation's XMLParser
class XML:XMLNode {
    var parser:XMLParser
    init(data: Data) {
        self.parser = XMLParser(data: data)
        super.init()
        parser.delegate = self
        parser.parse()
    }
    init?(contentsOf url: URL) {
        guard let parser = XMLParser(contentsOf: url) else { return nil}
        self.parser = parser
        super.init()
        parser.delegate = self
        parser.parse()
    }
}
//Each element of the XML hierarchy is represented by an XMLNode
//<name attribute="attribute_data">text<child></child></name>
class XMLNode:NSObject {
    var name:String?
    var attributes:[String:String] = [:]
    var text = ""
    var children:[XMLNode] = []
    var parent:XMLNode?
    
    override init() {
        
    }
    init(name:String) {
        self.name = name
    }
    init(name:String,value:String) {
        self.name = name
        self.text = value
    }
    //MARK: Update data
    func indexIsValid(index: Int) -> Bool {
        return (index >= 0 && index < children.count)
    }
    subscript(index: Int) -> XMLNode {
        get {
            assert(indexIsValid(index: index), "Index out of range")
            return children[index]
        }
        set {
            assert(indexIsValid(index: index), "Index out of range")
            children[index] = newValue
            newValue.parent = self
        }
    }
    subscript(index: String) -> XMLNode? {
        //if more than one exists, assume the first
        get {
            return children.filter({ $0.name == index }).first
        }
        set {
            guard let newNode = newValue,
                let filteredChild = children.filter({ $0.name == index }).first
                else {return}
            filteredChild.attributes = newNode.attributes
            filteredChild.text = newNode.text
            filteredChild.children = newNode.children
        }
    }
    func addChild(_ node:XMLNode) {
        children.append(node)
        node.parent = self
    }
    func addChild(name:String,value:String) {
        addChild(XMLNode(name: name, value: value))
    }
    func removeChild(at index:Int) {
        children.remove(at: index)
    }
    //MARK: Description properties
    override var description:String {
        if let name = name {
            return "<\(name)\(attributesDescription)>\(text)\(childrenDescription)</\(name)>"
        } else if let first = children.first {
            return "<?xml version=\"1.0\" encoding=\"utf-8\"?>\(first.description)"
        } else {
            return ""
        }
    }
    var attributesDescription:String {
        return attributes.map({" \($0)=\"\($1)\" "}).joined()
    }
    var childrenDescription:String {
        return children.map({ $0.description }).joined()
    }
}
extension XMLNode:XMLParserDelegate {
    public func parser(_ parser: XMLParser, foundCharacters string: String) {
        text += string.trimmingCharacters(in: NSCharacterSet.whitespacesAndNewlines)
    }
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        let childNode = XMLNode()
        childNode.name = elementName
        childNode.parent = self
        childNode.attributes = attributeDict
        parser.delegate = childNode
        
        children.append(childNode)
    }
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        if let parent = parent {
            parser.delegate = parent
        }
    }
}

