/**
 * Copyright IBM Corporation 2015
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 **/

import Foundation
import Alamofire
import AlamofireObjectMapper
import ObjectMapper

public class Dialog: WatsonService {
    
    // MARK: Content Operations
    
    /**
     Get the content for each node associated with the Dialog application.
    
     Depending on the Dialog design, each node can either be an input/output
     pair or just a single node.
    
     - Parameters:
         - dialogID: The Dialog application identifier.
         - completionHandler: A function invoked with the response from Watson.
     */
    public func getContent(dialogID: String,
        completionHandler: ([Node]?, NSError?) -> Void) {
        
        // construct request
        let request = WatsonRequest(
            method: .GET,
            serviceURL: Constants.serviceURL,
            endpoint: Constants.content(dialogID),
            accept: .JSON)
        
        // execute request
        Alamofire.request(request)
            .authenticate(user: user, password: password)
            .responseArray("items") { (response: Response<[Node], NSError>) in
                validate(response, serviceError: DialogError(),
                    completionHandler: completionHandler)
        }
    }
    
    /**
     Update the content for specific nodes of the Dialog application.
     
     - Parameters:
        - dialogID: The Dialog application identifier.
        - nodes: The specified nodes and updated content.
        - completionHandler: A function invoked with the response from Watson.
     */
    public func updateContent(dialogID: DialogID, nodes: [Node],
        completionHandler: NSError? -> Void) {
            
        // construct request
        let request = WatsonRequest(
            method: .PUT,
            serviceURL: Constants.serviceURL,
            endpoint: Constants.content(dialogID),
            contentType: .JSON,
            messageBody: Mapper().toJSONData(nodes, header: "items"))
        
        // execute request
        Alamofire.request(request)
            .authenticate(user: user, password: password)
            .responseData { response in
                validate(response, serviceError: DialogError(),
                    completionHandler: completionHandler)
        }
    }
    
    /**
     List the Dialog applications associated with the service instance.

     - Parameters:
        - completionHandler: A function invoked with the response from Watson.
     */
    public func getDialogs(completionHandler: ([DialogModel]?, NSError?) -> Void) {
        
        // construct request
        let request = WatsonRequest(
            method: .GET,
            serviceURL: Constants.serviceURL,
            endpoint: Constants.dialogs,
            accept: .JSON)
        
        // execute request
        Alamofire.request(request)
            .authenticate(user: user, password: password)
            .responseArray("dialogs") { (response: Response<[DialogModel], NSError>) in
                validate(response, serviceError: DialogError(),
                    completionHandler: completionHandler)
        }
    }
    
    /**
     Create a dialog application by uploading an existing Dialog file to the
     service instance. The returned Dialog application identifier can be used
     for subsequent calls to the API.

     The file content type is determined by the file extension (.mct for
     encrypted Dialog account file, .json for Watson Dialog document JSON
     format, and .xml for Watson Dialog document XML format).

     - Parameters:
        - name: The desired name of the Dialog application instance.
        - fileURL: The URL to a file that will be uploaded and used to create
                the dialog application. (Must contain an extension of .mct
                for encrypted Dialog account file, .json for Watson Dialog
                document JSON format, or .xml for Watson Dialog document XML
                format.)
        - completionHandler: A function invoked with the response from Watson.
     */
    public func createDialog(name: String, fileURL: NSURL,
        completionHandler: (DialogID?, NSError?) -> Void) {
            
        // construct request
        let request = WatsonRequest(
            method: .POST,
            serviceURL: Constants.serviceURL,
            endpoint: Constants.dialogs,
            accept: .JSON)
        
        // execute request
        Alamofire.upload(request,
            multipartFormData: { multipartFormData in
                // encode the name and file as form data
                let nameData = name.dataUsingEncoding(NSUTF8StringEncoding)!
                multipartFormData.appendBodyPart(data: nameData, name: "name")
                multipartFormData.appendBodyPart(fileURL: fileURL, name: "file")
            },
            encodingCompletion: { encodingResult in
                // was the encoding successful?
                switch encodingResult {
                case .Success(let upload, _, _):
                    // execute encoded request
                    upload.authenticate(user: self.user, password: self.password)
                    upload.responseObject {
                        (response: Response<DialogIDModel, NSError>) in
                        let unwrapID = {
                            (dialogID: DialogIDModel?, error: NSError?) in
                            completionHandler(dialogID?.id, error) }
                        validate(response, successCode: 201,
                            serviceError: DialogError(),
                            completionHandler: unwrapID)
                    }
                case .Failure:
                    // construct and return error
                    let nsError = NSError(
                        domain: "com.alamofire.error",
                        code: -6008,
                        userInfo: [NSLocalizedDescriptionKey:
                            "Unable to encode data as multipart form."])
                    completionHandler(nil, nsError)
                }
        })
    }
    
    /**
     Delete a Dialog application associated with the service instance. This
     permanently removes all associated data.
    
     - Parameters:
        - dialogID: The Dialog application identifier.
        - completionHandler: A function invoked with the response from Watson.
     */
    public func deleteDialog(dialogID: DialogID, completionHandler: NSError? -> Void) {
        
        // construct request
        let request = WatsonRequest(
            method: .DELETE,
            serviceURL: Constants.serviceURL,
            endpoint: Constants.dialogID(dialogID))
        
        // execute request
        Alamofire.request(request)
            .authenticate(user: user, password: password)
            .responseData { response in
                validate(response, serviceError: DialogError(),
                    completionHandler: completionHandler)
        }
    }
    
    /**
     Download the Dialog file associated with the given Dialog application.
     
     - Parameters:
        - dialogID: The Dialog application identifier.
        - format: The format of the file. The format can be either OctetStream
                (.mct file), Watson Dialog document JSON format (.json file),
                or Watson Dialog document XML format (.xml file).
        - completionHandler: A function invoked with the response from Watson.
     */
    public func getDialogFile(dialogID: DialogID, format: MediaType? = nil,
        completionHandler: (NSURL?, NSError?) -> Void) {
        
        // construct request
        let request = WatsonRequest(
            method: .GET,
            serviceURL: Constants.serviceURL,
            endpoint: Constants.dialogID(dialogID),
            accept: format)
        
        // construct Alamofire request
        var fileURL: NSURL?
        let r = Alamofire.download(request) { (temporaryURL, response) in
            // specify download destination
            let manager = NSFileManager.defaultManager()
            let directoryURL = manager.URLsForDirectory(.DocumentDirectory,
                inDomains: .UserDomainMask)[0]
            let pathComponent = response.suggestedFilename
            fileURL = directoryURL.URLByAppendingPathComponent(pathComponent!)
            return fileURL!
        }
            
        // execute request
        r.authenticate(user: user, password: password)
         .response { _, response, _, error in
            var data: NSData? = nil
            if let file = fileURL?.path { data = NSData(contentsOfFile: file) }
            let includeFileURL = { (error: NSError?) in completionHandler(fileURL, error) }
            validate(response, data: data, error: error, serviceError: DialogError(),
                completionHandler: includeFileURL)
        }
    }
    
    /**
     Update an existing Dialog application by uploading a Dialog file.
     
     - Parameters:
        - dialogID: The Dialog application identifier.
        - fileURL: The URL to a file that will be uploaded and used to define
                the Dialog application's operation. (Must contain an extension
                of .mct for encrypted Dialog account file, .json for Watson
                Dialog document JSON format, or .xml for Watson Dialog document
                XML format.)
        - completionHandler: A function invoked with the response from Watson.
     */
    public func updateDialog(dialogID: DialogID, fileURL: NSURL,
        fileType: MediaType, completionHandler: NSError? -> Void) {

        // construct request
        let request = WatsonRequest(
            method: .PUT,
            serviceURL: Constants.serviceURL,
            endpoint: Constants.dialogID(dialogID),
            contentType: fileType)
        
        // execute request
        Alamofire.upload(request, file: fileURL)
            .authenticate(user: user, password: password)
            .responseData { response in
                validate(response, serviceError: DialogError(),
                    completionHandler: completionHandler)
        }
    }
    
    // MARK: Conversation Operations
    
    /**
     Obtain recorded conversation session history for a specified date range.
     
     - Parameters
        - dialogID: The Dialog application identifier.
        - dateFrom: The start date of the desired conversation session history.
        - dateTo: The end date of the desired conversation session history.
        - offset: The offset starting point in the conversation result list (default: 0).
        - limit: The maximum number of conversations to retrieve (default: 10,000).
        - completionHandler: A function invoked with the response from Watson.
     */
    public func getConversation(dialogID: DialogID, dateFrom: NSDate,
        dateTo: NSDate, offset: Int? = nil, limit: Int? = nil,
        completionHandler: ([Conversation]?, NSError?) -> Void) {
        
        // format date range as strings
        let formatter = NSDateFormatter()
        formatter.timeZone = NSTimeZone(abbreviation: "UTC")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let dateFromString = formatter.stringFromDate(dateFrom)
        let dateToString = formatter.stringFromDate(dateTo)
            
        // construct url query parameters
        var urlParams = [NSURLQueryItem]()
        urlParams.append(NSURLQueryItem(name: "date_from", value: dateFromString))
        urlParams.append(NSURLQueryItem(name: "date_to", value: dateToString))
        if let offset = offset {
            urlParams.append(NSURLQueryItem(name: "offset", value: "\(offset)"))
        }
        if let limit = limit {
            urlParams.append(NSURLQueryItem(name: "limit", value: "\(limit)"))
        }
        
        // construct request
        let request = WatsonRequest(
            method: .GET,
            serviceURL: Constants.serviceURL,
            endpoint: Constants.conversation(dialogID),
            accept: .JSON,
            urlParams: urlParams)
        
        // execute request
        Alamofire.request(request)
            .authenticate(user: user, password: password)
            .responseArray("conversations") {
                (response: Response<[Conversation], NSError>) in
                validate(response, serviceError: DialogError(),
                    completionHandler: completionHandler)
            }
    }
    
    /**
     Start a new conversation or obtain a response for a submitted input message.
    
     - Parameters
        - dialogID: The Dialog application identifier.
        - conversationID: The conversation identifier. If not specified, then a
                new conversation will be started.
        - clientID: A client identifier generated by the Dialog service. If not
                specified, then a new client identifier will be issued.
        - input: The user input message to send for processing. This parameter
                is optional when conversationID is not specified.
        - completionHandler: A function invoked with the response from Watson.
     */
    public func converse(dialogID: DialogID, conversationID: Int? = nil,
        clientID: Int? = nil, input: String? = nil,
        completionHandler: (ConversationResponse?, NSError?) -> Void) {
            
        // construct url query parameters
        var urlParams = [NSURLQueryItem]()
        if let conversationID = conversationID {
            let query = NSURLQueryItem(name: "conversation_id", value: "\(conversationID)")
            urlParams.append(query)
        }
        if let clientID = clientID {
            let query = NSURLQueryItem(name: "client_id", value: "\(clientID)")
            urlParams.append(query)
        }
        if let input = input {
            let query = NSURLQueryItem(name: "input", value: input)
            urlParams.append(query)
        }
        
        // construct request
        let request = WatsonRequest(
            method: .POST,
            serviceURL: Constants.serviceURL,
            endpoint: Constants.conversation(dialogID),
            accept: .JSON,
            urlParams: urlParams)
        
        // execute request
        Alamofire.request(request)
            .authenticate(user: user, password: password)
            .responseObject { (response: Response<ConversationResponse, NSError>) in
                validate(response, successCode: 201, serviceError: DialogError(),
                    completionHandler: completionHandler)
            }
    }
    
    // MARK: Profile Operations
    
    /**
     Get the values for a client's profile variables.
    
     - Parameters:
        - dialogID: The Dialog application identifier.
        - clientID: A client identifier generated by the Dialog service.
        - names: The names of the profile variables to retrieve. If nil, then all
                profile variables will be retrieved.
        - completionHandler: A function invoked with the response from Watson.
     */
    public func getProfile(dialogID: DialogID, clientID: Int, names: [String]? = nil,
        completionHandler: ([Parameter]?, NSError?) -> Void) {
    
        // construct url query parameters
        var urlParams = [NSURLQueryItem]()
        urlParams.append(NSURLQueryItem(name: "client_id", value: "\(clientID)"))
        if let names = names {
            for name in names {
                urlParams.append(NSURLQueryItem(name: "name", value: name))
            }
        }
            
        // construct request
        let request = WatsonRequest(
            method: .GET,
            serviceURL: Constants.serviceURL,
            endpoint: Constants.profile(dialogID),
            accept: .JSON,
            urlParams: urlParams)
        
        // execute request
        Alamofire.request(request)
            .authenticate(user: user, password: password)
            .responseArray("name_values") { (response: Response<[Parameter], NSError>) in
                validate(response, serviceError: DialogError(),
                    completionHandler: completionHandler)
            }
    }

    /**
     Set the values for a client's profile variables.
    
     - Parameters:
        - dialogID: The Dialog application identifier.
        - clientID: A client identifier generated by the Dialog service. If not
                specified, then a new client identifier will be issued.
        - parameters: A dictionary of profile variables. The profile variables
                must already be explicitly defined in the Dialog application.
        - completionHandler: A function invoked with the response from Watson.
     */
    public func updateProfile(dialogID: DialogID, clientID: Int?,
        parameters: [String: String], completionHandler: NSError? -> Void) {
    
        // construct profile (for use as messageBody)
        let profile = Profile(clientID: clientID, parameters: parameters)
            
        // construct request
        let request = WatsonRequest(
            method: .PUT,
            serviceURL: Constants.serviceURL,
            endpoint: Constants.profile(dialogID),
            messageBody: Mapper().toJSONData(profile))
        
        // execute request
        Alamofire.request(request)
            .authenticate(user: user, password: password)
            .responseData { response in
                validate(response, serviceError: DialogError(),
                    completionHandler: completionHandler)
            }
    }
}