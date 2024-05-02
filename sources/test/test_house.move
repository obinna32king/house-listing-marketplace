#[test_only]
module Market::test_house {
    use sui::test_scenario::{Self as ts, next_tx, Scenario, ctx};
    use sui::coin::{Self, Coin, mint_for_testing};
    use sui::sui::SUI;
    use sui::tx_context::TxContext;
    use sui::object::UID;
    use sui::test_utils::{assert_eq};
    use sui::clock::{Self, Clock};
    use sui::transfer::{Self};

    use std::string::{Self, String};

    use Market::house::{Self, House, HouseCap, Listing};
    use Market::helpers::{Self, Car, init_test_helper};

    const ADMIN: address = @0xA;
    const TEST_ADDRESS1: address = @0xB;
    const TEST_ADDRESS2: address = @0xC;


    #[test]
    public fun test_list_delist() {

        let scenario_test = init_test_helper();
        let scenario = &mut scenario_test;

        next_tx(scenario, TEST_ADDRESS1);
        {
            let cap = house::create<SUI>(ts::ctx(scenario));
            transfer::public_transfer(cap, ADMIN);
        };

        next_tx(scenario, TEST_ADDRESS1);
        {
            let car = helpers::new_car(ts::ctx(scenario));
            transfer::public_transfer(car, TEST_ADDRESS1);
        };

        next_tx(scenario, TEST_ADDRESS1);
        {
            let house = ts::take_shared<House<SUI>>(scenario);
            let item = ts::take_from_sender<Car>(scenario);

            house::list(&mut house, item, 1000, ts::ctx(scenario));

            ts::return_shared(house);
        };

        next_tx(scenario, TEST_ADDRESS1);
        {
            let house = ts::take_shared<House<SUI>>(scenario);
            let item_id = house::get_car_id(&house);

            house::delist_and_take<Car, SUI>(&mut house, item_id, ts::ctx(scenario));

            ts::return_shared(house);
        };
    
         ts::end(scenario_test);
    }

    #[test]
    public fun test_list_purchase_withdraw() {

        let scenario_test = init_test_helper();
        let scenario = &mut scenario_test;

        next_tx(scenario, TEST_ADDRESS1);
        {
            let cap = house::create<SUI>(ts::ctx(scenario));
            transfer::public_transfer(cap, TEST_ADDRESS1);  
        };

        next_tx(scenario, TEST_ADDRESS1);
        {
            let car = helpers::new_car(ts::ctx(scenario));
            transfer::public_transfer(car, TEST_ADDRESS1);
        };

        next_tx(scenario, TEST_ADDRESS1);
        {
            let house = ts::take_shared<House<SUI>>(scenario);
            let item = ts::take_from_sender<Car>(scenario);

            house::list(&mut house, item, 1000, ts::ctx(scenario));

            ts::return_shared(house);
        };

        next_tx(scenario, TEST_ADDRESS2);
        {
            let house = ts::take_shared<House<SUI>>(scenario);
            let item_id = house::get_car_id(&house);
            let coin_ = mint_for_testing<SUI>(1000, ts::ctx(scenario));

            house::buy_and_take<Car, SUI>(&mut house, item_id, coin_, ts::ctx(scenario));

            ts::return_shared(house);
        };

        next_tx(scenario, TEST_ADDRESS1);
        {
            let house = ts::take_shared<House<SUI>>(scenario);
            let cap = ts::take_from_sender<HouseCap>(scenario);
            let coin = house::take_profits<SUI>(&cap, &mut house, ts::ctx(scenario));

            transfer::public_transfer(coin, TEST_ADDRESS1);

            ts::return_shared(house);
            ts::return_to_sender(scenario, cap);
        };
    
         ts::end(scenario_test);
    }

}