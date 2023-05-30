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
//  VoidResponseWriter.swift
//  SmokeOperationsHTTP1
//

import NIOHTTP1
import SmokeAsyncHTTP1Server

public struct VoidResponseWriter<WrappedWriter: HTTPServerResponseWriterProtocol>: TypedOutputWriterProtocol {
    
    private let status: HTTPResponseStatus
    private let wrappedWriter: WrappedWriter
    
    public init(status: HTTPResponseStatus,
                wrappedWriter: WrappedWriter) {
        self.status = status
        self.wrappedWriter = wrappedWriter
    }
    
    public func write(_ new: Void) async throws {
        await wrappedWriter.setStatus(self.status)
        try await wrappedWriter.commit()
        try await wrappedWriter.complete()
    }
}