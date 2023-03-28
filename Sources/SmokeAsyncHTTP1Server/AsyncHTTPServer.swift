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
// AsyncHTTPServer.swift
// SmokeAsyncHTTP1Server
//

import Foundation
import NIO
import NIOHTTP1
import NIOExtras
import Logging
import ServiceLifecycle

public struct ServerDefaults {
    static let defaultHost = "0.0.0.0"
    public static let defaultPort = 8080
}

/**
 A basic non-blocking HTTP server that handles a request with an
 optional body and returns a response with an optional body.
 */
public struct AsyncHTTPServer: ServiceLifecycle.Service {
    let port: Int
    
    let handler: @Sendable (HTTPServerRequest) async -> HTTPServerResponse
    let defaultLogger: Logger
    
    let eventLoopGroup: EventLoopGroup
    let ownEventLoopGroup: Bool
    
    /**
     Enumeration specifying how the event loop is provided for a channel established by this client.
     */
    public enum EventLoopProvider {
        /// The client will create a new EventLoopGroup to be used for channels created from
        /// this client. The EventLoopGroup will be closed when this client is closed.
        case spawnNewThreads
        /// The client will use the provided EventLoopGroup for channels created from
        /// this client. This EventLoopGroup will not be closed when this client is closed.
        case use(EventLoopGroup)
    }
    
    /**
     Initializer.
 
     - Parameters:
        - handler: the HTTPRequestHandler to handle incoming requests.
        - port: Optionally the localhost port for the server to listen on.
                If not specified, defaults to 8080.
        - eventLoopProvider: Provides the event loop to be used by the server.
                             If not specified, the server will create a new multi-threaded event loop
                             with the number of threads specified by `System.coreCount`.
     */
    public init(handler: @Sendable @escaping (HTTPServerRequest) async -> HTTPServerResponse,
                port: Int = ServerDefaults.defaultPort,
                defaultLogger: Logger = Logger(label: "com.amazon.SmokeFramework.SmokeAsyncHTTPServer.AsyncHTTPServer"),
                eventLoopProvider: EventLoopProvider = .spawnNewThreads) {
        self.port = port
        self.handler = handler
        self.defaultLogger = defaultLogger
        
        switch eventLoopProvider {
        case .spawnNewThreads:
            self.eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
            self.ownEventLoopGroup = true
        case .use(let existingEventLoopGroup):
            self.eventLoopGroup = existingEventLoopGroup
            self.ownEventLoopGroup = false
        }
    }
    
    public func run() async throws {
        let (quiesce, channel) = try self.start()
        let quiesceShutdownPromise = self.eventLoopGroup.next().makePromise(of: Void.self)
        
        try await withShutdownGracefulHandler {
            try await channel.closeFuture.get()
        } onGracefulShutdown: {
            quiesce.initiateShutdown(promise: quiesceShutdownPromise)
        }
        
        try await self.shutdown(quiesceShutdownPromise: quiesceShutdownPromise)
    }
    
    private func start() throws -> (ServerQuiescingHelper, Channel) {
        let quiesce = ServerQuiescingHelper(group: self.eventLoopGroup)
        
        defaultLogger.info("AsyncHTTPServer starting.",
                           metadata: ["port": "\(self.port)"])
        
        let currentHandler = handler
        
        // create a ServerBootstrap with a HTTP Server pipeline that delegates
        // to a HTTPChannelInboundHandler
        let bootstrap = ServerBootstrap(group: eventLoopGroup)
            .serverChannelOption(ChannelOptions.backlog, value: 256)
            .serverChannelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR), value: 1)
            .serverChannelInitializer { channel in
                channel.pipeline.addHandler(quiesce.makeServerChannelHandler(channel: channel))
            }
            .childChannelInitializer { channel in
                channel.pipeline.configureHTTPServerPipeline().flatMap {
                    channel.pipeline.addHandler(HTTP1RequestChannelHandler(handler: currentHandler))
                }
            }
            .childChannelOption(ChannelOptions.socket(IPPROTO_TCP, TCP_NODELAY), value: 1)
            .childChannelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR), value: 1)
            .childChannelOption(ChannelOptions.maxMessagesPerRead, value: 1)
            .childChannelOption(ChannelOptions.allowRemoteHalfClosure, value: true)
        
        let channel = try bootstrap.bind(host: ServerDefaults.defaultHost, port: port).wait()
        defaultLogger.info("AsyncHTTPServer started.",
                           metadata: ["port": "\(self.port)"])
        
        return (quiesce, channel)
    }
    
    private func shutdown(quiesceShutdownPromise: EventLoopPromise<Void>) async throws {
        try await quiesceShutdownPromise.futureResult.get()
        
        do {
            if self.ownEventLoopGroup {
                try await self.eventLoopGroup.shutdownGracefully()
            }
        } catch {
            self.defaultLogger.error("Server unable to shutdown cleanly following full shutdown.",
                                     metadata: ["cause": "\(String(describing: error))"])
        }
        
        self.defaultLogger.info("AsyncHTTPServer shutdown.")
    }
}