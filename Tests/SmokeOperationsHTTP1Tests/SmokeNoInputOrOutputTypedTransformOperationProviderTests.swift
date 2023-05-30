// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
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
// SmokeNoInputOrOutputTypedTransformOperationProviderTests.swift
// SmokeOperationsHTTP1Tests
//

import XCTest
import Foundation
import SwiftMiddleware
import SmokeOperationsHTTP1
import SmokeOperationsHTTP1Server
@testable import SmokeAsyncHTTP1Server
import ShapeCoding
import NIOPosix
import NIOCore
import NIOHTTP1
import Logging
import AsyncAlgorithms
import SmokeOperations

private extension ExampleContext {
    @Sendable func successOperation(_ input: HTTPServerRequest, outputWriter: TestHTTPServerResponseWriter) async throws {
        let bodyByteBuffer = try await input.body.collect(upTo: TestValues.maxBodySize)
        let bodyAsString = String(buffer: bodyByteBuffer)
        
        XCTAssertEqual(TestValues.id, bodyAsString)
        
        await outputWriter.setStatus(.imATeapot)
        try await outputWriter.commitAndCompleteWith(TestValues.id.data(using: .utf8)!)
    }
    
    @Sendable func successOperation2<OutputWriter: HTTPServerResponseWriterProtocol>(_ input: HTTPServerRequest,
                                                                                     outputWriter: OutputWriter) async throws {
        let bodyByteBuffer = try await input.body.collect(upTo: TestValues.maxBodySize)
        let bodyAsString = String(buffer: bodyByteBuffer)
        
        XCTAssertEqual(TestValues.id, bodyAsString)
        
        await outputWriter.setStatus(.forbidden)
        try await outputWriter.commitAndComplete()
    }
    
    @Sendable func allowedFailureOperation(_ input: HTTPServerRequest, outputWriter: TestHTTPServerResponseWriter) throws {
        throw TestErrors.allowedError
    }
    
    @Sendable func notAllowedFailureOperation(_ input: HTTPServerRequest, outputWriter: TestHTTPServerResponseWriter) throws {
        throw TestErrors.notAllowedError
    }
}

class SmokeNoInputOrOutputTypedTransformOperationProviderTests: XCTestCase {
    let allocator: ByteBufferAllocator = .init()
    
    var eventLoopGroup: EventLoopGroup!
    
    override func setUpWithError() throws {
        self.eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
    }
    
    override func tearDownWithError() throws {
        try self.eventLoopGroup.syncShutdownGracefully()
    }
    
    func testSuccessNoMiddleware() async throws {
        let serverConfiguration: SmokeServerConfiguration<TestOperations> = .init(eventLoopGroup: self.eventLoopGroup)
        var middlewareStack = TestableServerMiddlewareStack<RouterType, TestHTTPServerResponseWriter, ExampleContext>(
            serverName: "TestServer", serverConfiguration: serverConfiguration) { _ in .init() }
        let responseWriter = TestHTTPServerResponseWriter()
        
        middlewareStack.addHandlerForOperationProvider(
            .exampleOperation, httpMethod: .POST, operationProvider: ExampleContext.successOperation,
            allowedErrors: [(TestErrors.allowedError, 404)])
        
        let request = getRequest()
        
        await middlewareStack.handle(request: request, responseWriter: responseWriter)
        
        let bodyParts = await responseWriter.bodyParts
        let writerState = await responseWriter.state
        let status = await responseWriter.status
        
        // the writer should be completed, with the success status and with the response body as expected
        XCTAssertEqual(writerState, HTTPServerResponseWriterState.completed)
        XCTAssertEqual(status, .imATeapot)
        XCTAssertEqual(bodyParts.count, 1)
        
        var dataBuffer = bodyParts[0]
        let bodyAsString = String(data: dataBuffer.readData(length: dataBuffer.readableBytes)!, encoding: .utf8)!
        XCTAssertEqual(TestValues.id, bodyAsString)
    }
   
    func testAllowedFailureNoMiddleware() async throws {
        let serverConfiguration: SmokeServerConfiguration<TestOperations> = .init(eventLoopGroup: self.eventLoopGroup)
        var middlewareStack = TestableServerMiddlewareStack<RouterType, TestHTTPServerResponseWriter, ExampleContext>(
            serverName: "TestServer", serverConfiguration: serverConfiguration) { _ in .init() }
        let responseWriter = TestHTTPServerResponseWriter()
        
        middlewareStack.addHandlerForOperationProvider(
            .exampleOperation, httpMethod: .POST, operationProvider: ExampleContext.allowedFailureOperation,
            allowedErrors: [(TestErrors.allowedError, 404)])
        
        let request = getRequest()
        
        await middlewareStack.handle(request: request, responseWriter: responseWriter)
        
        let bodyParts = await responseWriter.bodyParts
        let writerState = await responseWriter.state
        let status = await responseWriter.status
        
        // the writer should be completed, with the failure status and the error body
        XCTAssertEqual(writerState, HTTPServerResponseWriterState.completed)
        XCTAssertEqual(status, HTTPResponseStatus.notFound)
        XCTAssertEqual(bodyParts.count, 1)
        
        var dataBuffer = bodyParts[0]
        let bodyAsString = String(data: dataBuffer.readData(length: dataBuffer.readableBytes)!, encoding: .utf8)!
        XCTAssertTrue(bodyAsString.contains("\"__type\" : \"Allowed\""))
    }
    
    func testNotAllowedFailureNoMiddleware() async throws {
        let serverConfiguration: SmokeServerConfiguration<TestOperations> = .init(eventLoopGroup: self.eventLoopGroup)
        var middlewareStack = TestableServerMiddlewareStack<RouterType, TestHTTPServerResponseWriter, ExampleContext>(
            serverName: "TestServer", serverConfiguration: serverConfiguration) { _ in .init() }
        let responseWriter = TestHTTPServerResponseWriter()
        
        middlewareStack.addHandlerForOperationProvider(
            .exampleOperation, httpMethod: .POST, operationProvider: ExampleContext.notAllowedFailureOperation,
            allowedErrors: [(TestErrors.allowedError, 404)])
        
        let request = getRequest()
        
        await middlewareStack.handle(request: request, responseWriter: responseWriter)
        
        let bodyParts = await responseWriter.bodyParts
        let writerState = await responseWriter.state
        let status = await responseWriter.status
        
        // the writer should be completed, with the failure status and the error body
        XCTAssertEqual(writerState, HTTPServerResponseWriterState.completed)
        XCTAssertEqual(status, HTTPResponseStatus.internalServerError)
        XCTAssertEqual(bodyParts.count, 1)
        
        var dataBuffer = bodyParts[0]
        let bodyAsString = String(data: dataBuffer.readData(length: dataBuffer.readableBytes)!, encoding: .utf8)!
        XCTAssertTrue(bodyAsString.contains("\"__type\" : \"InternalError\""))
    }
    
    func testSuccessWithMiddleware() async throws {
        let serverConfiguration: SmokeServerConfiguration<TestOperations> = .init(eventLoopGroup: self.eventLoopGroup)
        var middlewareStack = TestableServerMiddlewareStack<RouterType, TestHTTPServerResponseWriter, ExampleContext>(
            serverName: "TestServer", serverConfiguration: serverConfiguration) { _ in .init() }
        let responseWriter = TestHTTPServerResponseWriter()
        
        let originalMiddlewareFlag = AtomicBoolean()
        let transformedMiddlewareFlag = AtomicBoolean()
        
        let middleware = MiddlewareStack {
            TestOriginalOuterMiddleware(flag: originalMiddlewareFlag)
            
            TestTransformingOuterMiddleware()
            
            TestTransformedOuterMiddleware(flag: transformedMiddlewareFlag)
        }
        
        // successOperation2 uses the transformed output writer
        middlewareStack.addHandlerForOperationProvider(
            .exampleOperation, httpMethod: .POST, operationProvider: ExampleContext.successOperation2,
            allowedErrors: [(TestErrors.allowedError, 404)],
            middleware: middleware)
        
        let request = getRequest()
        
        await middlewareStack.handle(request: request, responseWriter: responseWriter)
        
        let bodyParts = await responseWriter.bodyParts
        let writerState = await responseWriter.state
        let status = await responseWriter.status
        
        let originalMiddlewareFlagValue = await originalMiddlewareFlag.value
        let transformedMiddlewareFlagValue = await transformedMiddlewareFlag.value
        
        // the writer should be completed, with the forbidden status and with no response body as expected
        XCTAssertEqual(writerState, HTTPServerResponseWriterState.completed)
        XCTAssertEqual(status, .forbidden)
        XCTAssertEqual(bodyParts.count, 0)
        
        XCTAssertTrue(originalMiddlewareFlagValue)
        XCTAssertTrue(transformedMiddlewareFlagValue)
    }
    
    private func getRequest() -> HTTPServerRequest {
        let byteBuffer = TestValues.id.data(using: .utf8)!.asByteBuffer(allocator: self.allocator)
        
        let bodyChannel = AsyncThrowingChannel<ByteBuffer, Error>()
        Task {
            await bodyChannel.send(byteBuffer)
            bodyChannel.finish()
        }
        var request = HTTPServerRequest(method: .POST,
                                        uri: TestOperations.exampleOperation.operationPath,
                                        bodyChannel: bodyChannel)
        request.headers.add(name: "theHeader", value: TestValues.header)
        
        return request
    }
}
