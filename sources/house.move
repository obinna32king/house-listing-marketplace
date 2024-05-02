module dacademarket::house {

    // Importing required modules
    use sui::dynamic_object_field as ofield;
    use sui::tx_context::{Self, TxContext};
    use sui::object::{Self, ID, UID};
    use sui::coin::{Self, Coin};
    use sui::bag::{Bag, Self};
    use sui::table::{Table, Self};
    use sui::transfer;

    // Error constants
    const EAmountIncorrect: u64 = 0;
    const ENotOwner: u64 = 1;
    const EInvalidListing: u64 = 2;
    const ENoProfit: u64 = 3;

    // House struct: Represents a marketplace for a specific coin type
    // One instance of House accepts only one type of coin for all listings
    struct House<phantom COIN> has key {
        id: UID,
        items: Bag,
        payments: Table<address, Coin<COIN>>
    }

    // create new houselist
    public entry fun create<COIN>(ctx: &mut TxContext) {
        let id = object::new(ctx);
        let items = bag::new(ctx);
        let payments = table::new<address, Coin<COIN>>(ctx);
        transfer::share_object(House<COIN> { 
            id, 
            items,
            payments
        })
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

    /**
     * Public entry function: list
     * Description: Lists an item for sale with a specified asking price.
     * @param house: &mut House<COIN> - Reference to the house list object
     * @param item: T - Item to list
     * @param ask: u64 - Asking price for the item
     * @param ctx: &mut TxContext - Transaction context
     */
    public entry fun list<T: key + store, COIN>(
        house: &mut House<COIN>,
        item: T,
        ask: u64,
        ctx: &mut TxContext
    ) {
        let item_id = object::id(&item);
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
     * @param house: &mut House<COIN> - Reference to the house list object
     * @param item_id: ID - ID of the item to delist
     * @param ctx: &mut TxContext - Transaction context
     * @returns: (bool, T) - A boolean indicating if the delisting was successful, and the item associated with the listing
     */
    fun delist<T: key + store, COIN>(
        house: &mut House<COIN>,
        item_id: ID,
        ctx: &mut TxContext
    ): (bool, T) {
        assert!(bag::contains(&house.items, item_id), EInvalidListing);

        let Listing { id, owner, ask: _ } = bag::remove(&mut house.items, item_id);

        assert!(tx_context::sender(ctx) == owner, ENotOwner);

        let item = ofield::remove(&mut id, true);
        object::delete(id);
        (true, item)
    }

    /**
     * Public entry function: delist_and_take
     * Description: Removes a listing and transfers the associated item to the sender.
     * @param house: &mut House<COIN> - Reference to the house list object
     * @param item_id: ID - ID of the item to delist
     * @param ctx: &mut TxContext - Transaction context
     */
    public entry fun delist_and_take<T: key + store, COIN>(
        house: &mut House<COIN>,
        item_id: ID,
        ctx: &mut TxContext
    ) {
        let (success, item) = delist<T, COIN>(house, item_id, ctx);
        if (success) {
            transfer::public_transfer(item, tx_context::sender(ctx));
        }
    }

    /**
     * Function: buy
     * Description: Purchases an item from the marketplace using a known listing.
     * Payment is done in Coin<COIN>.
     * @param house: &mut House<COIN> - Reference to the house marketplace
     * @param item_id: ID - ID of the item to buy
     * @param paid: Coin<COIN> - Payment made for the item
     * @returns: T - Item associated with the listing
     */
    fun buy<T: key + store, COIN>(
        house: &mut House<COIN>,
        item_id: ID,
        paid: Coin<COIN>,
    ): T {
        let Listing { id, ask, owner } = bag::remove(&mut house.items, item_id);

        assert!(ask == coin::value(&paid), EAmountIncorrect);

        if (table::contains<address, Coin<COIN>>(&house.payments, owner)) {
            let owner_payment = table::borrow_mut<address, Coin<COIN>>(&mut house.payments, owner);
            coin::join(owner_payment, paid);
        } else {
            table::add(&mut house.payments, owner, paid);
        };

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
    public entry fun buy_and_take<T: key + store, COIN>(
        house: &mut House<COIN>,
        item_id: ID,
        paid: Coin<COIN>,
        ctx: &mut TxContext
    ) {
        transfer::public_transfer(
            buy<T, COIN>(house, item_id, paid),
            tx_context::sender(ctx)
        )
    }

    /**
     * Function: take_profits
     * Description: Takes profits from selling items on the marketplace.
     * @param house: &mut House<COIN> - Reference to the house listing marketplace
     * @param ctx: &mut TxContext - Transaction context
     * @returns: (bool, Coin<COIN>) - A boolean indicating if the sender had profits, and the collected profits
     */
    fun take_profits<COIN>(
        house: &mut House<COIN>,
        ctx: &mut TxContext
    ): (bool, Coin<COIN>) {
        let sender = tx_context::sender(ctx);
        if (table::contains<address, Coin<COIN>>(&house.payments, sender)) {
            (true, table::remove<address, Coin<COIN>>(&mut house.payments, sender))
        } else {
            (false, Coin {})
        }
    }

    /**
     * Public entry function: take_profits_and_keep
     * Description: Takes profits from selling items on the marketplace and transfers them to the sender.
     * @param house: &mut House<COIN> - Reference to the house listing marketplace
     * @param ctx: &mut TxContext - Transaction context
     */
    public entry fun take_profits_and_keep<COIN>(
        house: &mut House<COIN>,
        ctx: &mut TxContext
    ) {
        let (has_profit, profits) = take_profits(house, ctx);
        if (has_profit) {
            transfer::public_transfer(profits, tx_context::sender
   (profits, tx_context::sender(ctx));
   } else {
   // Handle the case where the sender has no profits
   }
}
}
