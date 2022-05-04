// Copyright 2018-2020 Amazon.com, Inc. or its affiliates. All Rights Reserved.
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
// LambdaHTTP1ProxyRequestHandler.swift
// SmokeOperationsHTTP1LambdaProxy
//

import Foundation
import NIO
import NIOHTTP1
import Logging
import SmokeInvocation
import AWSLambdaRuntime

/**
 Protocol that specifies a handler for a HttpRequest.
 */
public protocol LambdaHTTP1ProxyRequestHandler {
    associatedtype ResponseHandlerType: LambdaHTTP1ProxyResponseHandler
    
    /**
     Handles an incoming request.
 
     - Parameters:
        - requestHead: the parameters specified in the head of the HTTP request.
        - body: the body of the request, if any.
        - responseHandler: a handler that can be used to respond to the request.
        - invocationStrategy: the invocationStrategy to use for this request.
     */
    func handle(requestHead: HTTPRequestHead, context: Lambda.Context, body: Data?, responseHandler: ResponseHandlerType,
                invocationStrategy: InvocationStrategy, requestLogger: Logger, internalRequestId: String)
}
