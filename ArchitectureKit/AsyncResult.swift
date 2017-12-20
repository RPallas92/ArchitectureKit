//
//  AsyncResult.swift
//  FunctionalSwiftArchitecture
//
//  Created by Pallas, Ricardo on 12/5/17.
//  Copyright © 2017 Pallas, Ricardo. All rights reserved.
//

import FunctionalKit

public typealias AsyncResult<E,A,Err> = Reader<E, Future<Result<Err, A>>> where Err: Error

public extension AsyncResult where ParameterType: FutureType, ParameterType.ParameterType: ResultType {
    
    typealias ValueType = ParameterType.ParameterType.ParameterType
    typealias ErrorType = ParameterType.ParameterType.ErrorType

    func runT<H>(_ environment:EnvironmentType, _ callback: @escaping (Result<ErrorType, H>) -> ()) where ValueType == H {
        let future = self.run(environment)
        future.run { result in
            result.fold(
                onSuccess: { callback(Result.success($0))},
                onFailure: { callback(Result.failure($0))}
            )
        }
    }
    
    static func unfoldTT(_ from: @escaping (EnvironmentType, @escaping(Result<ErrorType,ValueType>)->())->()) -> AsyncResult<EnvironmentType, ValueType, ErrorType> {
        return AsyncResult.unfold { context in
            return Future<Result<ErrorType, ValueType>>.unfold { continuation in
                from(context, continuation)
            }
            
        }
    }
    
    func mapTT<H>(_ transform: @escaping (ValueType) -> H) -> AsyncResult<EnvironmentType,H, ErrorType> {
        return self.map { future in
            future.map { result in
                result.map(transform)
            }
        }
    }
    
    func flatMapTT<H>(_ transform: @escaping (ValueType) -> AsyncResult<EnvironmentType,H, ErrorType>) -> AsyncResult<EnvironmentType,H, ErrorType> {
        return AsyncResult<EnvironmentType,H, ErrorType>.ask.flatMap { context -> AsyncResult<EnvironmentType,H, ErrorType> in

            self.flatMap { future -> AsyncResult<EnvironmentType,H, ErrorType> in
                let newFuture = Future<Result<ErrorType, H>>.unfold { callback -> () in
                    future.run { result -> () in
                        result.fold(
                            onSuccess: { value in
                                let newReader = transform(value)
                                let newFuture = newReader.run(context)
                                newFuture.run { newResult -> () in
                                    callback(newResult)
                                }
                            },
                            onFailure: { error in
                                callback(Result<ErrorType,H>.failure(error))
                            }
                        )
                    }
                }
                return AsyncResult<EnvironmentType,H, ErrorType>.pure(newFuture)
            }
        }
    }
    
    static func pureTT<H>(_ value:H) -> AsyncResult<EnvironmentType,H, ErrorType> where H == ValueType {
        let result = Result<ErrorType,H>.pure(value)
        let future = Future.pure(result)
        return AsyncResult<EnvironmentType,H, ErrorType>.pure(future)
    }
    
    
    func handleErrorWith(_ transform: @escaping (ErrorType) -> AsyncResult<EnvironmentType,ValueType, ErrorType>) -> AsyncResult<EnvironmentType,ValueType, ErrorType> {
        
        return AsyncResult<EnvironmentType,ValueType, ErrorType>.ask.flatMap { context -> AsyncResult<EnvironmentType,ValueType, ErrorType> in
            
            self.flatMap { future -> AsyncResult<EnvironmentType,ValueType, ErrorType> in
                let newFuture = Future<Result<ErrorType, ValueType>>.unfold { callback -> () in
                    future.run { result -> () in
                        result.fold(
                            onSuccess: { value in
                                callback(Result<ErrorType,ValueType>.success(value))
                        },
                        onFailure: { jokeError in
                                let newReader = transform(jokeError)
                                let newFuture = newReader.run(context)
                                newFuture.run { newResult -> () in
                                    callback(newResult)
                                }
                        })
                    }
                }
                return AsyncResult<EnvironmentType,ValueType, ErrorType>.pure(newFuture)
            }
        }
        
    }
    
}
