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
// Validatable.swift
// SmokeOperations
//

import Foundation

/**
 Protocol that provides a method to validate an instance.
 */
public protocol Validatable {
    /**
     Called to validate the current instance.
     Throws an error if validation fails.
     */
    func validate() throws
}

public typealias ValidatableCodable = Validatable & Codable
