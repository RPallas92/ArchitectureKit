//
//  AsyncResult.swift
//  FunctionalSwiftArchitecture
//
//  Created by Pallas, Ricardo on 12/5/17.
//  Copyright © 2017 Pallas, Ricardo. All rights reserved.
//

import FunctionalKit

typealias AsyncResult<E,A> = Reader<E, Future<Result<SystemError, A>>>

extension AsyncResult where ParameterType: FutureType, ParameterType.ParameterType: ResultType,
    ParameterType.ParameterType.ErrorType == SystemError {
    
    typealias ValueType = ParameterType.ParameterType.ParameterType

    func runT<H>(_ environment:EnvironmentType, _ callback: @escaping (Result<SystemError, H>) -> ()) where ValueType == H {
        let future = self.run(environment)
        future.run { result in
            result.fold(
                onSuccess: { callback(Result.success($0))},
                onFailure: { callback(Result.failure($0))}
            )
        }
    }
    
    func mapTT<H>(_ transform: @escaping (ValueType) -> H) -> AsyncResult<EnvironmentType,H> {
        return self.map { future in
            future.map { result in
                result.map(transform)
            }
        }
    }
    
    func flatMapTT<H>(_ transform: @escaping (ValueType) -> AsyncResult<EnvironmentType,H>) -> AsyncResult<EnvironmentType,H> {
        return AsyncResult<EnvironmentType,H>.ask.flatMap { context -> AsyncResult<EnvironmentType,H> in

            self.flatMap { future -> AsyncResult<EnvironmentType,H> in
                let newFuture = Future<Result<SystemError, H>>.unfold { callback -> () in
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
                                callback(Result<SystemError,H>.failure(error))
                            }
                        )
                    }
                }
                return AsyncResult<EnvironmentType,H>.pure(newFuture)
            }
        }
    }
    
    static func pureTT<H>(_ value:H) -> AsyncResult<EnvironmentType,H> where H == ValueType {
        let result = Result<SystemError, H>.pure(value)
        let future = Future.pure(result)
        return AsyncResult<EnvironmentType, H>.pure(future)
    }
    
    
    func handleErrorWith(_ transform: @escaping (SystemError) -> AsyncResult<EnvironmentType,ValueType>) -> AsyncResult<EnvironmentType,ValueType> {
        
        return AsyncResult<EnvironmentType,ValueType>.ask.flatMap { context -> AsyncResult<EnvironmentType,ValueType> in
            
            self.flatMap { future -> AsyncResult<EnvironmentType,ValueType> in
                let newFuture = Future<Result<SystemError, ValueType>>.unfold { callback -> () in
                    future.run { result -> () in
                        result.fold(
                            onSuccess: { value in
                                callback(Result<SystemError,ValueType>.success(value))
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
                return AsyncResult<EnvironmentType,ValueType>.pure(newFuture)
            }
        }
        
    }
    
}
