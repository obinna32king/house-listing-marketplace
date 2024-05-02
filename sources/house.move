module Market::house {

   // Importing required modules

    use sui::dynamic_object_field as ofield;
    use sui::tx_context::{Self, TxContext};
    use sui::object::{Self, ID, UID};
    use sui::coin::{Self, Coin};
    use sui::bag::{Bag, Self};
    use sui::table::{Table, Self};
    use sui::transfer;
    use sui::sui::SUI;
    use sui::balance::{Self, Balance};

    use std::vector::{Self};


    // Error constants

    const EAmountIncorrect: u64 = 0;
    const ENotOwner: u64 = 1;
    const EInvalidCap: u64 = 2;

    // shared object, one instance of house accepts only 1 type of coin for all listings
    struct House has key {
        id: UID,
        items: Bag,
        payments: Balance<SUI>,
        car_id: vector<ID> // For local test Delete me !! 
    }

    struct HouseCap has key, store {
        id: UID,
        house_id: ID
    }

    /**
    * Struct: Listing
    * Description: Represents a listing for an item.
    */
    struct Listing has key, store {
        id: UID,
        ask: u64,
        owner: address
    }
    
    // create new houselist
    public fun create(ctx: &mut TxContext) : HouseCap {
        let id = object::new(ctx);
        let inner_ = object::uid_to_inner(&id);
        let items = bag::new(ctx);
        transfer::share_object(House { 
            id, 
            items,
            payments: balance::zero(),
            car_id: vector::empty()
        });
        let cap = HouseCap {
            id: object::new(ctx),
            house_id: inner_
        };
        cap

    }

/**
 * Public entry function: list
 * Description: Lists an item for sale with a specified asking price.
 * @param houselist: &mut houselist<COIN> - Reference to the house list object
 * @param item: T - Item to list
 * @param ask: u64 - Asking price for the item
 * @param ctx: &mut TxContext - Transaction context
 */
    public entry fun list<T: key + store>(
        house: &mut House,
        item: T,
        ask: u64,
        ctx: &mut TxContext
    ) {
        let item_id = object::id(&item);
        vector::push_back(&mut house.car_id, item_id); // for access car id Delete me !! 
        let listing = Listing {
            id: object::new(ctx),
            ask: ask,
            owner: tx_context::sender(ctx),
        };

        ofield::add(&mut listing.id, true, item);
        bag::add(&mut house.items, item_id, listing)
    }

    /**
 * Function: delist
 * Description: Removes a listing and returns the item associated with it.
 * @param houselist: &mut houselist<COIN> - Reference to the house list object
 * @param item_id: ID - ID of the item to delist
 * @param ctx: &mut TxContext - Transaction context
 * @returns: T - Item associated with the listing
 */
    fun delist<T: key + store, COIN>(
        house: &mut House,
        item_id: ID,
        ctx: &mut TxContext
    ): T {
        let Listing { id, owner, ask: _ } = bag::remove(&mut house.items, item_id);

        assert!(tx_context::sender(ctx) == owner, ENotOwner);

        let item = ofield::remove(&mut id, true);
        object::delete(id);
        item
    }

    /**
     * Public entry function: buy_and_take
     * Description: Buys an item from the marketplace and transfers it to the sender.
     * @param house: &mut House<COIN> - Reference to the house listing marketplace
     * @param item_id: ID - ID of the item to buy
     * @param paid: Coin<COIN> - Payment made for the item
     * @param ctx: &mut TxContext - Transaction context
     */
    public entry fun delist_and_take<T: key + store>(
        house: &mut House,
        item_id: ID,
        ctx: &mut TxContext
    ) {
        let item = delist<T, SUI>(house, item_id, ctx);
        transfer::public_transfer(item, tx_context::sender(ctx));
    }

     /**
     * Function: buy
     * Description: Purchases an item from the marketplace using a known listing.
     * Payment is done in Coin<COIN>.
     * If conditions are correct, the owner of the item gets the payment and the buyer receives the item.
     * @param House: &mut House<COIN> - Reference to the house marketplace
     * @param item_id: ID - ID of the item to buy
     * @param paid: Coin<COIN> - Payment made for the item
     * @returns: T - Item associated with the listing
     */
    fun buy<T: key + store>(
        house: &mut House,
        item_id: ID,
        paid: Coin<SUI>,
    ): T {
        let Listing { id, ask, owner } = bag::remove(&mut house.items, item_id);
        assert!(ask == coin::value(&paid), EAmountIncorrect);
        coin::put(&mut house.payments, paid);


        let item = ofield::remove(&mut id, true);
        object::delete(id);
        item
    }

    
    public entry fun buy_and_take<T: key + store>(
        house: &mut House,
        item_id: ID,
        paid: Coin<SUI>,
        ctx: &mut TxContext
    ) {
        transfer::public_transfer(
            buy<T>(house, item_id, paid),
            tx_context::sender(ctx)
        )
    }

    /**
     * Function: take_profits
     * Description: Takes profits from selling items on the marketplace.
     * @param house: &mut House<COIN> - Reference to the house listing marketplace
     * @param ctx: &mut TxContext - Transaction context
     * @returns: Coin<COIN> - Profits collected
     */
    public fun  take_profits(
        cap: &HouseCap,
        house: &mut House,
        ctx: &mut TxContext
    ): Coin<SUI> {
        assert!(object::id(house) == cap.house_id, EInvalidCap);
        let balance_ = balance::withdraw_all(&mut house.payments);
        let coin_ = coin::from_balance(balance_, ctx);
        coin_
    }

    // For tests
    public fun get_car_id(house: &House) : ID {
        let id_ = vector::borrow(&house.car_id, 0);
        *id_
    }

}
