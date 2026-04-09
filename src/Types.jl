@enum Side::UInt8 Buy Sell

struct Order
    symbol::String
    side::Side
    quantity::Int
    order_type::Symbol
    limit_price::Union{Nothing, Float64}
    submitted_at::DateTime
end

function Order(;
        symbol,
        side::Side,
        quantity::Integer,
        order_type::Symbol,
        limit_price = nothing,
        submitted_at::DateTime
)
    quantity > 0 || throw(ArgumentError("quantity must be positive"))
    order_type in (:market, :limit) ||
        throw(ArgumentError("order_type must be :market or :limit"))
    if order_type === :limit
        limit_price === nothing && throw(ArgumentError("limit orders require limit_price"))
    else
        limit_price === nothing ||
            throw(ArgumentError("market orders cannot set limit_price"))
    end
    return Order(
        String(symbol),
        side,
        Int(quantity),
        order_type,
        limit_price === nothing ? nothing : Float64(limit_price),
        submitted_at
    )
end

const OrderRef = Int

struct Fill
    ref::OrderRef
    symbol::String
    side::Side
    quantity::Int
    price::Float64
    fees::Float64
    timestamp::DateTime
end

struct SlippageModel
    fixed_per_leg::Float64
    spread_fraction::Float64
end

function SlippageModel(; fixed_per_leg::Real = 0.0, spread_fraction::Real = 0.0)
    fixed_per_leg >= 0 || throw(ArgumentError("fixed_per_leg must be nonnegative"))
    spread_fraction >= 0 ||
        throw(ArgumentError("spread_fraction must be nonnegative"))
    return SlippageModel(Float64(fixed_per_leg), Float64(spread_fraction))
end

abstract type MarketEvent end

struct QuoteEvent <: MarketEvent
    symbol::String
    bid::Float64
    ask::Float64
    timestamp::DateTime
end

struct TradeEvent <: MarketEvent
    symbol::String
    price::Float64
    size::Float64
    timestamp::DateTime
end

struct BarEvent <: MarketEvent
    symbol::String
    open::Float64
    high::Float64
    low::Float64
    close::Float64
    volume::Float64
    timestamp::DateTime
end

struct ChainEvent <: MarketEvent
    symbol::String
    chain_state::Any
    timestamp::DateTime
end

struct SessionEvent <: MarketEvent
    session::Symbol
    timestamp::DateTime
end

event_time(event::MarketEvent) = event.timestamp
