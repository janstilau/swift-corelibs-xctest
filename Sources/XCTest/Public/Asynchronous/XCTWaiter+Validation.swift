protocol XCTWaiterValidatableExpectation: Equatable {
    var isFulfilled: Bool { get }
    var fulfillmentToken: UInt64 { get }
    var isInverted: Bool { get }
}

extension XCTWaiter {
    struct ValidatableXCTestExpectation: XCTWaiterValidatableExpectation {
        let expectation: XCTestExpectation
        
        var isFulfilled: Bool {
            return expectation.queue_isFulfilled
        }
        
        var fulfillmentToken: UInt64 {
            return expectation.queue_fulfillmentToken
        }
        
        var isInverted: Bool {
            return expectation.queue_isInverted
        }
    }
}

extension XCTWaiter {
    enum ValidationResult<ExpectationType: XCTWaiterValidatableExpectation> {
        case complete
        case fulfilledInvertedExpectation(invertedExpectation: ExpectationType)
        case violatedOrderingConstraints(expectation: ExpectationType, requiredExpectation: ExpectationType)
        case timedOut(unfulfilledExpectations: [ExpectationType])
        case incomplete
    }
    
    // 在这里, 核验 waiter 所记录的 expections 是否已经达到了 complete 的状态.
    static func validateExpectations<ExpectationType: XCTWaiterValidatableExpectation>(_ expectations: [ExpectationType], dueToTimeout didTimeOut: Bool, enforceOrder: Bool) -> ValidationResult<ExpectationType> {
        var unfulfilledExpectations = [ExpectationType]()
        var fulfilledExpectations = [ExpectationType]()
        
        for expectation in expectations {
            if expectation.isFulfilled {
                // Check for any fulfilled inverse expectations. If they were fulfilled before wait was called,
                // this is where we'd catch that.
                if expectation.isInverted {
                    return .fulfilledInvertedExpectation(invertedExpectation: expectation)
                } else {
                    fulfilledExpectations.append(expectation)
                }
            } else {
                unfulfilledExpectations.append(expectation)
            }
        }
        
        if enforceOrder {
            fulfilledExpectations.sort { $0.fulfillmentToken < $1.fulfillmentToken }
            let nonInvertedExpectations = expectations.filter { !$0.isInverted }
            
            assert(fulfilledExpectations.count <= nonInvertedExpectations.count, "Internal error: number of fulfilledExpectations (\(fulfilledExpectations.count)) must not exceed number of non-inverted expectations (\(nonInvertedExpectations.count))")
            
            for (fulfilledExpectation, nonInvertedExpectation) in zip(fulfilledExpectations, nonInvertedExpectations) where fulfilledExpectation != nonInvertedExpectation {
                return .violatedOrderingConstraints(expectation: fulfilledExpectation, requiredExpectation: nonInvertedExpectation)
            }
        }
        
        if unfulfilledExpectations.isEmpty {
            return .complete
        } else if didTimeOut {
            // If we've timed out, our new state is just based on whether or not we have any remaining unfulfilled, non-inverted expectations.
            let nonInvertedUnfilledExpectations = unfulfilledExpectations.filter { !$0.isInverted }
            if nonInvertedUnfilledExpectations.isEmpty {
                return .complete
            } else {
                return .timedOut(unfulfilledExpectations: nonInvertedUnfilledExpectations)
            }
        }
        
        return .incomplete
    }
}
