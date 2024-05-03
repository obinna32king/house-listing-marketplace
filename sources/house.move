module dacademarket::house {
    use sui::dynamic_object_field as ofield;
    use sui::tx_context::{Self, TxContext};
    use sui::object::{Self, ID, UID};
    use sui::coin::{Self, Coin};
    use sui::bag::{Bag, Self};
    use sui::table::{Table, Self};
    use sui::transfer;
    use sui::event::{Self, Event};

    // Error constants
    const EAmountIncorrect: u64 = 0;
    const ENotOwner: u64 = 1;

    // Event types
    struct ListingCreated has copy, drop {
        listing_id: ID,
        item_id: ID,
        ask: u64,
        owner: address,
    }

    struct ListingDelisted has copy, drop {
        listing_id: ID,
        item_id: ID,
        owner: address,
    }

    struct ItemSold has copy, drop {
        listing_id: ID,
        item_id: ID,
        buyer: address,
        seller: address,
        price: u64,
    }

    // Shared object, one instance of house accepts only 1 type of coin for all listings
    struct House<phantom COIN> has key {
        id: UID,
        items: Bag,
        payments: Table<address, Coin<COIN>>,
    }

    // Create a new house list
    public entry fun create<COIN>(ctx: &mut TxContext) {
        let id = object::new(ctx);
        let items = bag::new(ctx);
        let payments = table::new<address, Coin<COIN>>(ctx);
        transfer::share_object(House<COIN> {
            id,
            items,
            payments,
        })
    }

    // Struct representing a listing
    struct Listing has key, store {
        id: UID,
        ask: u64,
        owner: address,
    }

    // List an item for sale
    public entry fun list<T: key + store, COIN>(
        house: &mut House<COIN>,
        item: T,
        ask: u64,
        ctx: &mut TxContext,
    ) {
        let item_id = object::id(&item);
        let listing = Listing {
            id: object::new(ctx),
            ask,
            owner: tx_context::sender(ctx),
        };

        ofield::add(&mut listing.id, true, item);
        bag::add(&mut house.items, item_id, listing);

        event::emit(ListingCreated {
            listing_id: object::uid_to_inner(&listing.id),
            item_id,
            ask,
            owner: tx_context::sender(ctx),
        });
    }

    // Delist an item
    fun delist<T: key + store, COIN>(
        house: &mut House<COIN>,
        item_id: ID,
        ctx: &mut TxContext,
    ): T {
        let Listing {
            id,
            owner,
            ask: _,
        } = bag::remove(&mut house.items, item_id);

        assert!(tx_context::sender(ctx) == owner, ENotOwner);

        let item = ofield::remove(&mut id, true);
        object::delete(id);

        event::emit(ListingDelisted {
            listing_id: object::uid_to_inner(&id),
            item_id,
            owner,
        });

        item
    }

    // Delist an item and transfer it to the owner
    public entry fun delist_and_take<T: key + store, COIN>(
        house: &mut House<COIN>,
        item_id: ID,
        ctx: &mut TxContext,
    ) {
        let item = delist<T, COIN>(house, item_id, ctx);
        transfer::public_transfer(item, tx_context::sender(ctx));
    }

    // Buy an item
    fun buy<T: key + store, COIN>(
        house: &mut House<COIN>,
        item_id: ID,
        paid: Coin<COIN>,
        ctx: &mut TxContext,
    ): T {
        let Listing {
            id,
            ask,
            owner,
        } = bag::remove(&mut house.items, item_id);

        assert!(ask == coin::value(&paid), EAmountIncorrect);

        if (table::contains(&house.payments, owner)) {
            coin::join(
                table::borrow_mut(&mut house.payments, owner),
                paid,
            )
        } else {
            table::add(&mut house.payments, owner, paid)
        };

        let item = ofield::remove(&mut id, true);
        object::delete(id);

        event::emit(ItemSold {
            listing_id: object::uid_to_inner(&id),
            item_id,
            buyer: tx_context::sender(ctx),
            seller: owner,
            price: ask,
        });

        item
    }

    // Buy an item and transfer it to the buyer
    public entry fun buy_and_take<T: key + store, COIN>(
        house: &mut House<COIN>,
        item_id: ID,
        paid: Coin<COIN>,
        ctx: &mut TxContext,
    ) {
        transfer::public_transfer(
            buy<T, COIN>(house, item_id, paid, ctx),
            tx_context::sender(ctx),
        )
    }

    // Take profits from selling items
    fun take_profits<COIN>(
        house: &mut House<COIN>,
        ctx: &mut TxContext,
    ): Option<Coin<COIN>> {
        table::remove(&mut house.payments, tx_context::sender(ctx))
    }

    // Take profits and transfer them to the sender
    public entry fun take_profits_and_keep<COIN>(
        house: &mut House<COIN>,
        ctx: &mut TxContext,
    ) {
        if let Some(profits) = take_profits(house, ctx) {
            transfer::public_transfer(profits, tx_context::sender(ctx))
        }
    }

    // Get the number of items listed by an owner
    public fun get_listed_item_count<COIN>(
        house: &House<COIN>,
        owner: address,
    ): u64 {
        let count = 0;
        bag::iter(&house.items, |_, listing| {
            if (listing.owner == owner) {
                count = count + 1;
            }
        });
        count
    }
}