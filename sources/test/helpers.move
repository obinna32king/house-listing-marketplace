#[test_only]
module Market::helpers {
    use sui::test_scenario::{Self as ts, next_tx, Scenario};
    use sui::object::{Self, UID};
    use sui::tx_context::TxContext;

    use std::string::{Self};
    use std::vector;

    struct Car has key, store {
        id: UID
    }

    const ADMIN: address = @0xA;

    public fun new_car(ctx: &mut TxContext) : Car {
        let car = Car{id: object::new(ctx)};
        car
    }

    public fun init_test_helper() : Scenario {
       let owner: address = @0xA;
       let scenario_val = ts::begin(owner);
       let scenario = &mut scenario_val;

       scenario_val
    }

}