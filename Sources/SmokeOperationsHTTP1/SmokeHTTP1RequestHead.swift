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
//  SmokeHTTP1RequestHead.swift
//  SmokeOperationsHTTP1
//

import Foundation
import NIOHTTP1
import ShapeCoding

/**
 Structure representing an incoming HTTP1 request head.
 */
public struct SmokeHTTP1RequestHead {
    public let httpRequestHead: HTTPRequestHead
    public let query: String
    public let pathShape: Shape
    
    public init(httpRequestHead: HTTPRequestHead,
                query: String,
                pathShape: Shape) {
        self.httpRequestHead = httpRequestHead
        self.query = query
        self.pathShape = pathShape
    }
}
