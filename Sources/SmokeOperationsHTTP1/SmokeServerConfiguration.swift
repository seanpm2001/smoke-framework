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
// SmokeServerConfiguration.swift
// SmokeOperationsHTTP1
//

import NIO
import SmokeOperations
import Logging
import UnixSignals
import SmokeAsyncHTTP1Server

public struct SmokeServerConfiguration<OperationIdentifer: OperationIdentity> {
    public var defaultLogger: Logger
    public var reportingConfiguration: SmokeReportingConfiguration<OperationIdentifer>
    public var port: Int
    public var shutdownOnSignals: [UnixSignal]
    public var eventLoopGroupStatus: (group: EventLoopGroup, owned: Bool)
    
    public init(port: Int = ServerDefaults.defaultPort,
                defaultLogger: Logger = Logger(label: "application.initialization"),
                reportingConfiguration: SmokeReportingConfiguration<OperationIdentifer> = .init(),
                eventLoopGroup: EventLoopGroup,
                shutdownOnSignals: [UnixSignal] = [.sigint, .sigterm]) {
        self.port = port
        self.defaultLogger = defaultLogger
        self.reportingConfiguration = reportingConfiguration
        self.eventLoopGroupStatus = (group: eventLoopGroup, owned: false)
        self.shutdownOnSignals = shutdownOnSignals
    }
    
    public init(port: Int = ServerDefaults.defaultPort,
                defaultLogger: Logger = Logger(label: "application.initialization"),
                reportingConfiguration: SmokeReportingConfiguration<OperationIdentifer> = .init(),
                shutdownOnSignals: [UnixSignal] = [.sigint, .sigterm]) {
        let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
        
        self.port = port
        self.defaultLogger = defaultLogger
        self.reportingConfiguration = reportingConfiguration
        self.eventLoopGroupStatus = (group: eventLoopGroup, owned: true)
        self.shutdownOnSignals = shutdownOnSignals
    }
    
    public var eventLoopGroup: EventLoopGroup {
        get {
            return self.eventLoopGroupStatus.group
        }
        set(newEventLoopGroup) {
            self.eventLoopGroupStatus = (group: newEventLoopGroup, owned: true)
        }
    }
}