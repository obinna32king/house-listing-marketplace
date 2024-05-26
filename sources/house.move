module dacademarket::house {
    use sui::tx_context::{Self as TxContext, TxContext};
    use sui::object::{Self as Object, ID, UID};
    use sui::coin::{Self as Coin, Coin};
    use sui::bag::{Bag, Self as Bag};
    use sui::table::{Table, Self as Table};
    use sui::transfer;
    use sui::event::{Self as Event, Event};
    use 0x1::Address;

    // Event types
    struct ListingCreated {
        listing_id: ID,
        item_id: ID,
        ask: u64,
        owner: Address,
    }

    struct ListingDelisted {
        listing_id: ID,
        item_id: ID,
        owner: Address,
    }

    struct ItemSold {
        listing_id: ID,
        item_id: ID,
        buyer: Address,
        seller: Address,
        price: u64,
    }

    struct EscrowCreated {
    escrow_id: ID,
    item_id: ID,
    buyer: Address,
    seller: Address,
    price: u64,
}

struct EscrowPaid {
    escrow_id: ID,
    item_id: ID,
    buyer: Address,
    seller: Address,
    amount: u64,
}

struct EscrowReleased {
    escrow_id: ID,
    item_id: ID,
    buyer: Address,
    seller: Address,
    amount: u64,
}

struct DisputeResolved {
    escrow_id: ID,
    item_id: ID,
    buyer: Address,
    seller: Address,
    resolution: Resolution,
}

    // Shared object, one instance of house accepts only 1 type of coin for all listings
    struct House<phantom COIN> {
        id: UID,
        items: Bag,
        payments: Table<Address, Coin<COIN>>,
        escrows: Table<ID, Escrow<COIN>>,
    }
    

    // Struct representing an escrow

    struct Escrow<COIN> {
    id: UID,
    item_id: ID,
    item: Option<T>,
    buyer: Address,
    seller: Address,
    price: u64,
    payment: Option<Coin<COIN>>,
    is_released: bool,
    is_refunded: bool,
    }


    // Create a new house list
    public fun create<COIN>(ctx: &mut TxContext) {
        let id = Object::new(ctx);
        let items = Bag::new(ctx);
        let payments = Table::new<Address, Coin<COIN>>(ctx);
        transfer::share_object(House<COIN> {
            id,
            items,
            payments,
        })
    }

    // Struct representing a listing
    struct Listing {
        id: UID,
        ask: u64,
        owner: Address,
    }

    // List an item for sale
    pub fun list<COIN>(
        house: &mut House<COIN>,
        item: T,
        ask: u64,
        ctx: &mut TxContext,
    ) where T: Object + Copy {
        let item_id = Object::id(&item);
        let listing = Listing {
            id: Object::new(ctx),
            ask,
            owner: TxContext::sender(ctx),
        };

        Bag::add(&mut house.items, item_id, listing);

        Event::emit(ListingCreated {
            listing_id: Object::uid_to_inner(&listing.id),
            item_id,
            ask,
            owner: TxContext::sender(ctx),
        });
    }

    // Delist an item
    pub fun delist<COIN>(
        house: &mut House<COIN>,
        item_id: ID,
        ctx: &mut TxContext,
    ) -> T where T: Object + Copy {
        let Listing {
            id,
            owner,
            ask: _,
        } = Bag::remove(&mut house.items, item_id);

        assert!(TxContext::sender(ctx) == owner, ENotOwner);

        let item = Object::delete(id);

        Event::emit(ListingDelisted {
            listing_id: Object::uid_to_inner(&id),
            item_id,
            owner,
        });

        item
    }

    // Delist an item and transfer it to the owner
    pub fun delist_and_take<COIN>(
        house: &mut House<COIN>,
        item_id: ID,
        ctx: &mut TxContext,
    ) where T: Object + Copy {
        transfer::public_transfer(
            delist(house, item_id, ctx),
            TxContext::sender(ctx),
        )
    }

    // Buy an item
    pub fun buy<COIN>(
        house: &mut House<COIN>,
        item_id: ID,
        paid: Coin<COIN>,
        ctx: &mut TxContext,
    ) -> T where T: Object + Copy {
        let Listing {
            id,
            ask,
            owner,
        } = Bag::remove(&mut house.items, item_id);

        assert!(ask == Coin::value(&paid), EAmountIncorrect);

        if (Table::contains(&house.payments, owner)) {
            Coin::join(
                Table::borrow_mut(&mut house.payments, owner),
                paid,
            )
        } else {
            Table::add(&mut house.payments, owner, paid)
        };

        let item = Object::delete(id);

        Event::emit(ItemSold {
            listing_id: Object::uid_to_inner(&id),
            item_id,
            buyer: TxContext::sender(ctx),
            seller: owner,
            price: ask,
        });

        item
    }

    // Buy an item and transfer it to the buyer
    pub fun buy_and_take<COIN>(
        house: &mut House<COIN>,
        item_id: ID,
        paid: Coin<COIN>,
        ctx: &mut TxContext,
    ) where T: Object + Copy {
        transfer::public_transfer(
            buy(house, item_id, paid, ctx),
            TxContext::sender(ctx),
        )
    }

    // Take profits from selling items
    pub fun take_profits<COIN>(
        house: &mut House<COIN>,
        ctx: &mut TxContext,
    ) -> Option<Coin<COIN>> {
        Table::remove(&mut house.payments, TxContext::sender(ctx))
    }

    // Take profits and transfer them to the sender
    pub fun take_profits_and_keep<COIN>(
        house: &mut House<COIN>,
        ctx: &mut TxContext,
    ) where T: Object + Copy {
        if let Some(profits) = take_profits(house, ctx) {
            transfer::public_transfer(profits, TxContext::sender(ctx))
        }
    }

    // Get the number of items listed by an owner
    pub fun get_listed_item_count<COIN>(
        house: &House<COIN>,
        owner: Address,
    ) -> u64 {
        let mut count = 0;
        Bag::iter(&house.items, |_, listing| {
            if (listing.owner == owner) {
                count = count + 1;
            }
        });
        count
    }

        // Search and filter listings
    pub fun search_listings<COIN>(
        house: &House<COIN>,
        min_price: u64,
        max_price: u64,
        item_type: T,
        seller: Address,
    ) -> Vec<Listing>
    where T: Object + Copy {
        let mut filtered_listings: Vec<Listing> = Vec::new();

        Bag::iter(&house.items, |_, listing| {
            if listing.ask >= min_price && listing.ask <= max_price && listing.owner == seller {
                filtered_listings.push(listing);
            }
        });

        filtered_listings
    }
    // ..

    // Create an escrow for an item
    public fun create_escrow<T: Object + Copy, COIN>(
    house: &mut House<COIN>,
    item: T,
    price: u64,
    buyer: Address,
    ctx: &mut TxContext,
) {
    let item_id = Object::id(&item);
    let escrow_id = Object::new(ctx);
    let seller = TxContext::sender(ctx);

    let escrow = Escrow {
        id: escrow_id,
        item_id,
        item: Some(item),
        buyer,
        seller,
        price,
        payment: None,
        is_released: false,
    };

    Table::add(&mut house.escrows, item_id, escrow);
    Event::emit(EscrowCreated {
        escrow_id: Object::uid_to_inner(&escrow_id),
        item_id,
        buyer,
        seller,
        price,
    });
}

// ..

    // Pay to escrow an escrow

    public fun pay_to_escrow<COIN>(
    house: &mut House<COIN>,
    item_id: ID,
    payment: Coin<COIN>,
    ctx: &mut TxContext,
) {
    let sender = TxContext::sender(ctx);
    let escrow = Table::borrow_mut(&mut house.escrows, item_id);

    assert!(escrow.buyer == sender, "Only the buyer can pay to the escrow.");
    assert!(Coin::value(&payment) == escrow.price, "Incorrect payment amount.");

    escrow.payment = Some(payment);
    Event::emit(EscrowPaid {
        escrow_id: Object::uid_to_inner(&escrow.id),
        item_id,
        buyer: escrow.buyer,
        seller: escrow.seller,
        amount: escrow.price,
    });
}

// ..

    // Release an escrow

    public fun release_escrow<COIN>(
    house: &mut House<COIN>,
    item_id: ID,
    ctx: &mut TxContext,
) where T: Object + Copy {
    let sender = TxContext::sender(ctx);
    let escrow = Table::remove(&mut house.escrows, item_id);

    assert!(escrow.seller == sender, "Only the seller can release the escrow.");
    assert!(escrow.payment.is_some(), "Payment is not made.");

    let item = escrow.item.unwrap();
    Object::delete(Object::id(&item));

    Event::emit(EscrowReleased {
        escrow_id: Object::uid_to_inner(&escrow.id),
        item_id,
        buyer: escrow.buyer,
        seller: escrow.seller,
        amount: escrow.price,
    });
    
    // Transfer the payment to the seller
    transfer::public_transfer(escrow.payment.unwrap(), escrow.seller);
    }

    // disputes resolution

    public fun resolve_dispute<COIN>(
    house: &mut House<COIN>,
    item_id: ID,
    resolution: Resolution,
    ctx: &mut TxContext,
) {
    let sender = TxContext::sender(ctx);
    // Assume a function `is_admin` that checks if the sender is an admin
    assert!(is_admin(sender), "Only admins can resolve disputes.");

    let escrow = Table::borrow_mut(&mut house.escrows, item_id);
    assert!(!escrow.is_released, "Payment has already been released.");

    match resolution {
        Resolution::Refund => {
            let payment = escrow.payment.take().unwrap();
            transfer::public_transfer(payment, escrow.buyer);
            let item = escrow.item.take().unwrap();
            transfer::public_transfer(item, escrow.seller);
        }
        Resolution::Complete => {
            let payment = escrow.payment.take().unwrap();
            if Table::contains(&house.payments, escrow.seller) {
                Coin::join(Table::borrow_mut(&mut house.payments, escrow.seller), payment);
            } else {
                Table::add(&mut house.payments, escrow.seller, payment);
            }
            let item = escrow.item.take().unwrap();
            transfer::public_transfer(item, escrow.buyer);
        }
    }

    escrow.is_released = true;
    Event::emit(DisputeResolved {
        escrow_id: Object::uid_to_inner(&escrow.id),
        item_id,
        buyer: escrow.buyer,
        seller: escrow.seller,
        resolution,
    });
}

enum Resolution {
    Refund,
    Complete,
}

}
