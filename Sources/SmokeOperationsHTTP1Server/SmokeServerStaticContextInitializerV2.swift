// Copyright 2018-2021 Amazon.com, Inc. or its affiliates. All Rights Reserved.
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
// SmokeServerStaticContextInitializerV2.swift
// SmokeOperationsHTTP1Server
//

import Foundation
import SmokeOperationsHTTP1
import SmokeHTTP1

public protocol SmokeServerStaticContextInitializerV2: SmokeStaticContextInitializerV2 {
    
    var port: Int { get }
    var shutdownOnSignal: SmokeHTTP1Server.ShutdownOnSignal { get }
    var eventLoopProvider: SmokeHTTP1Server.EventLoopProvider { get }
}

public extension SmokeServerStaticContextInitializerV2 {
    var port: Int {
        return ServerDefaults.defaultPort
    }
    
    var shutdownOnSignal: SmokeHTTP1Server.ShutdownOnSignal {
        return .sigint
    }
    
    var eventLoopProvider: SmokeHTTP1Server.EventLoopProvider {
        return .spawnNewThreads
    }
}