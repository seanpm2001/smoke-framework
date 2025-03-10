// Copyright 2018-2022 Amazon.com, Inc. or its affiliates. All Rights Reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License").
// You may not use this file except in compliance with the License.
// A copy of the License is located at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// or in the "license" file accompanying this file. This file is distributed
// on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either
// express or implied. See the License for the specific language governing
// permissions and limitations under the License.
//
// TestConfiguration.swift
// SmokeOperationsTests
//

import Foundation
import SmokeOperations
import NIOHTTP1
import Logging
import SmokeInvocation
import NIO
@testable import SmokeOperationsHTTP1
import XCTest

enum TestOperations: String, OperationIdentity {
    case exampleOperation
    case exampleOperationWithToken
    case exampleGetOperation
    case exampleGetOperationWithToken
    case exampleNoBodyOperation
    case exampleNoBodyOperationWithToken
    case badOperation
    case badOperationWithToken
    case badOperationVoidResponse
    case badOperationVoidResponseWithToken
    case badOperationWithThrow
    case badOperationWithThrowWithToken
    case badOperationVoidResponseWithThrow
    case badOperationVoidResponseWithThrowWithToken
    
    var description: String {
        return rawValue
    }
    
    var operationPath: String {
        switch self {
        case .exampleOperation:
            return "exampleoperation"
        case .exampleOperationWithToken:
            return "exampleoperation/{theToken}"
        case .exampleGetOperation:
            return "examplegetoperation"
        case .exampleGetOperationWithToken:
            return "examplegetoperation/{theToken}"
        case .exampleNoBodyOperation:
            return "examplenobodyoperation"
        case .exampleNoBodyOperationWithToken:
            return "examplenobodyoperation/{theToken}"
        case .badOperation:
            return "badoperation"
        case .badOperationWithToken:
            return "badoperation/{theToken}"
        case .badOperationVoidResponse:
            return "badoperationvoidresponse"
        case .badOperationVoidResponseWithToken:
            return "badoperationvoidresponse/{theToken}"
        case .badOperationWithThrow:
            return "badoperationwiththrow"
        case .badOperationWithThrowWithToken:
            return "badoperationwiththrow/{theToken}"
        case .badOperationVoidResponseWithThrow:
            return "badoperationvoidresponsewiththrow"
        case .badOperationVoidResponseWithThrowWithToken:
            return "badoperationvoidresponsewiththrow/{theToken}"
        }
    }
}

typealias TestJSONPayloadHTTP1OperationDelegate = GenericJSONPayloadHTTP1OperationDelegate<TestHttpResponseHandler, TestInvocationReporting>

struct ExampleContext {
}

let serializedInput = """
    {
      "theID" : "123456789012"
    }
    """

let serializedAlternateInput = """
    {
      "theID" : "888888888888"
    }
    """

let serializedInvalidInput = """
    {
      "theID" : "1789012"
    }
    """

struct OperationResponse {
    let status: HTTPResponseStatus
    let responseComponents: HTTP1ServerResponseComponents
}

struct TestInvocationReporting: InvocationReporting {
    var logger: Logger = Logger(label: "test")
    
    var internalRequestId: String = "internalRequestId"
}

class TestHttpResponseHandler: HTTP1ResponseHandler {
    let continuation: CheckedContinuation<OperationResponse, Never>
    
    init(continuation: CheckedContinuation<OperationResponse, Never>) {
        self.continuation = continuation
    }
    
    func complete(invocationContext: SmokeInvocationContext<TestInvocationReporting>, status: HTTPResponseStatus,
                  responseComponents: HTTP1ServerResponseComponents) {
        let response = OperationResponse(status: status,
                                         responseComponents: responseComponents)
        self.continuation.resume(returning: response)
    }
    
    func completeInEventLoop(invocationContext: SmokeInvocationContext<TestInvocationReporting>, status: HTTPResponseStatus,
                             responseComponents: HTTP1ServerResponseComponents) {
        complete(invocationContext: invocationContext, status: status, responseComponents: responseComponents)
    }
    
    func completeSilentlyInEventLoop(invocationContext: SmokeInvocationContext<TestInvocationReporting>, status: HTTPResponseStatus,
                                     responseComponents: HTTP1ServerResponseComponents) {
        complete(invocationContext: invocationContext, status: status, responseComponents: responseComponents)
    }
    
    func executeInEventLoop(invocationContext: SmokeInvocationContext<TestInvocationReporting>, execute: @escaping () -> ()) {
        execute()
    }
}

public enum MyError: Swift.Error {
    case theError(reason: String)
    
    enum CodingKeys: String, CodingKey {
        case reason = "Reason"
    }
}

extension MyError: Encodable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        switch self {
        case .theError(reason: let reason):
            try container.encode(reason, forKey: .reason)
        }
    }
}

extension MyError: CustomStringConvertible {
    public var description: String {
        return "TheError"
    }
}

let allowedErrors = [(MyError.theError(reason: "MyError"), 400)]

struct ErrorResponse: Codable {
    let type: String
    let reason: String?
    
    enum CodingKeys: String, CodingKey {
        case type = "__type"
        case reason = "Reason"
    }
}

struct ExampleInput: Codable, Validatable, Equatable {
    let theID: String
    
    func validate() throws {
        if theID.count != 12 {
            throw SmokeOperationsError.validationError(reason: "ID not the correct length.")
        }
    }
}

struct ExampleQueryInput: Codable {
    let theParameter: String
}

struct ExamplePathInput: Codable {
    let theToken: String
}

struct ExampleBodyInput: Codable {
    let theID: String
}

struct ExampleHeaderInput: Codable {
    let theHeader: String
}

struct ExampleHTTP1Input: OperationHTTP1InputProtocol, Validatable, Equatable {
    typealias QueryType = ExampleQueryInput
    typealias PathType = ExamplePathInput
    typealias BodyType = ExampleBodyInput
    typealias HeadersType = ExampleHeaderInput
    
    let theID: String
    let theToken: String
    let theParameter: String
    let theHeader: String
    
    func validate() throws {
        if theID.count != 12 {
            throw SmokeOperationsError.validationError(reason: "ID not the correct length.")
        }
    }
    
    static func compose(
            queryDecodableProvider: () throws -> ExampleQueryInput,
            pathDecodableProvider: () throws -> ExamplePathInput,
            bodyDecodableProvider: () throws -> ExampleBodyInput,
            headersDecodableProvider: () throws -> ExampleHeaderInput) throws -> ExampleHTTP1Input {
        return ExampleHTTP1Input(theID: try bodyDecodableProvider().theID,
                                 theToken: try pathDecodableProvider().theToken,
                                 theParameter: try queryDecodableProvider().theParameter,
                                 theHeader: try headersDecodableProvider().theHeader)
    }
}

extension ExampleHTTP1Input {
    func validateForTest() {
        XCTAssertEqual("headerValue", theHeader)
        XCTAssertEqual("muchParameter", theParameter)
        XCTAssertEqual("suchToken", theToken)
    }
}

enum BodyColor: String, Codable {
    case yellow = "YELLOW"
    case blue = "BLUE"
}

struct TestInvocationStrategy: InvocationStrategy {
    func invoke(handler: @escaping () -> ()) {
        handler()
    }
}

struct OutputAttributes: Codable, Validatable, Equatable {
    let bodyColor: BodyColor
    let isGreat: Bool
    
    func validate() throws {
        if case .yellow = bodyColor {
            throw SmokeOperationsError.validationError(reason: "The body color is yellow.")
        }
    }
}

struct OutputBodyAttributes: Codable, Equatable {
    let bodyColor: BodyColor
    let isGreat: Bool
}

struct OutputHeaderAttributes: Codable {
    let theHeader: String
}

struct OutputHTTP1Attributes: OperationHTTP1OutputProtocol, Validatable, Equatable {
    typealias BodyType = OutputBodyAttributes
    typealias AdditionalHeadersType = OutputHeaderAttributes
    
    let bodyColor: BodyColor
    let isGreat: Bool
    let theHeader: String
    
    var bodyEncodable: OutputBodyAttributes? {
        return OutputBodyAttributes(bodyColor: bodyColor, isGreat: isGreat)
    }
    
    var additionalHeadersEncodable: OutputHeaderAttributes? {
        return OutputHeaderAttributes(theHeader: theHeader)
    }
    
    func validate() throws {
        if case .yellow = bodyColor {
            throw SmokeOperationsError.validationError(reason: "The body color is yellow.")
        }
    }
}

func verifyPathOutput<SelectorType>(uri: String, body: Data,
                                    handlerSelector: SelectorType,
                                    additionalHeaders: [(String, String)] = []) async -> OperationResponse
where SelectorType: SmokeHTTP1HandlerSelector, SelectorType.ContextType == ExampleContext,
    SmokeHTTP1RequestHead == SelectorType.DefaultOperationDelegateType.RequestHeadType,
    TestInvocationReporting == SelectorType.DefaultOperationDelegateType.InvocationReportingType,
    SelectorType.DefaultOperationDelegateType.ResponseHandlerType == TestHttpResponseHandler,
    SelectorType.OperationIdentifer == TestOperations {
    let handler = StandardHTTP1OperationRequestHandler<SelectorType>(
        handlerSelector: handlerSelector,
        context: ExampleContext(), serverName: "Server", reportingConfiguration: SmokeReportingConfiguration<TestOperations>())
    
    var httpRequestHead = HTTPRequestHead(version: HTTPVersion(major: 1, minor: 1),
                                          method: .POST,
                                          uri: uri)
    additionalHeaders.forEach { header in
        httpRequestHead.headers.add(name: header.0, value: header.1)
    }
            
    func invocationReportingProvider(logger: Logger) -> TestInvocationReporting {
        return TestInvocationReporting()
    }
        
    return await withCheckedContinuation { continuation in
        let responseHandler = TestHttpResponseHandler(continuation: continuation)
        
        handler.handle(requestHead: httpRequestHead, body: body,
                       responseHandler: responseHandler,
                       invocationStrategy: TestInvocationStrategy(), requestLogger: Logger(label: "Test"),
                       internalRequestId: "internalRequestId",
                       invocationReportingProvider: invocationReportingProvider, reportRequest: { })
    }
}

func verifyErrorResponse<SelectorType>(uri: String,
                                       handlerSelector: SelectorType,
                                       additionalHeaders: [(String, String)] = []) async throws
where SelectorType: SmokeHTTP1HandlerSelector, SelectorType.ContextType == ExampleContext,
    SmokeHTTP1RequestHead == SelectorType.DefaultOperationDelegateType.RequestHeadType,
    TestHttpResponseHandler == SelectorType.DefaultOperationDelegateType.ResponseHandlerType,
    TestInvocationReporting == SelectorType.DefaultOperationDelegateType.InvocationReportingType,
    SelectorType.OperationIdentifer == TestOperations {
    let response = await verifyPathOutput(uri: uri,
                                          body: serializedAlternateInput.data(using: .utf8)!,
                                          handlerSelector: handlerSelector,
                                          additionalHeaders: additionalHeaders)
    
    
    XCTAssertEqual(response.status.code, 400)
    let body = response.responseComponents.body!
    let output = try JSONDecoder.getFrameworkDecoder().decode(ErrorResponse.self,
                                                              from: body.data)
    
    XCTAssertEqual("TheError", output.type)
}
