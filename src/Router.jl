mutable struct _PendingOrder
    ref::OrderRef
    order::Order
end

mutable struct SimulatedOrderRouter <: AbstractOrderRouter
    slippage::SlippageModel
    pending_orders::Vector{_PendingOrder}
    pending_scratch::Vector{_PendingOrder}
    filled_orders::Vector{Fill}
    next_ref::Int
end

function SimulatedOrderRouter(; slippage::SlippageModel = SlippageModel())
    return SimulatedOrderRouter(slippage, _PendingOrder[], _PendingOrder[], Fill[], 1)
end

function submit!(router::SimulatedOrderRouter, order::Order)
    ref = router.next_ref
    router.next_ref += 1
    push!(router.pending_orders, _PendingOrder(ref, order))
    return ref
end

function cancel!(router::SimulatedOrderRouter, ref::OrderRef)
    idx = findfirst(pending -> pending.ref == ref, router.pending_orders)
    idx === nothing && return false
    deleteat!(router.pending_orders, idx)
    return true
end

function replace!(router::SimulatedOrderRouter, ref::OrderRef, order::Order)
    idx = findfirst(pending -> pending.ref == ref, router.pending_orders)
    idx === nothing && return false
    router.pending_orders[idx] = _PendingOrder(ref, order)
    return true
end

fills(router::SimulatedOrderRouter) = copy(router.filled_orders)

function process_event!(router::SimulatedOrderRouter, event::MarketEvent)
    event_mid = _event_mid(event)
    spread = _event_spread(event)
    trade_price = _event_trade_price(event)
    remaining = router.pending_scratch
    empty!(remaining)

    for pending in router.pending_orders
        order = pending.order
        order.symbol == _event_symbol(event) || (push!(remaining, pending); continue)

        if order.order_type === :market
            event_mid === nothing && (push!(remaining, pending); continue)
            fill_price, fee = _market_fill(order, router.slippage, event_mid, spread)
            push!(router.filled_orders,
                Fill(
                    pending.ref, order.symbol, order.side, order.quantity, fill_price, fee,
                    event_time(event)))
            continue
        end

        trade_price === nothing && (push!(remaining, pending); continue)
        if _limit_traded_through(order, trade_price)
            fill_price, fee = _limit_fill(order, router.slippage, spread)
            push!(router.filled_orders,
                Fill(
                    pending.ref, order.symbol, order.side, order.quantity, fill_price, fee,
                    event_time(event)))
        else
            push!(remaining, pending)
        end
    end

    router.pending_orders, router.pending_scratch = remaining, router.pending_orders
    return router
end

function _market_fill(
        order::Order,
        slippage::SlippageModel,
        event_mid::Float64,
        spread::Float64
)
    side_sign = order.side === Buy ? 1.0 : -1.0
    slippage_cost = slippage.fixed_per_leg + slippage.spread_fraction * spread
    return event_mid + side_sign * slippage_cost, slippage.fixed_per_leg * order.quantity
end

function _limit_fill(
        order::Order,
        slippage::SlippageModel,
        spread::Float64
)
    fee = slippage.fixed_per_leg * order.quantity
    return order.limit_price, fee
end

function _limit_traded_through(order::Order, trade_price::Float64)
    order.side === Buy && return trade_price <= order.limit_price
    return trade_price >= order.limit_price
end

_event_symbol(event::QuoteEvent) = event.symbol
_event_symbol(event::TradeEvent) = event.symbol
_event_symbol(event::BarEvent) = event.symbol
_event_symbol(event::ChainEvent) = event.symbol
_event_symbol(event::SessionEvent) = ""

_event_mid(event::QuoteEvent) = (event.bid + event.ask) / 2
_event_mid(event::TradeEvent) = nothing
_event_mid(event::BarEvent) = nothing
_event_mid(event::ChainEvent) = nothing
_event_mid(event::SessionEvent) = nothing

_event_spread(event::QuoteEvent) = max(0.0, event.ask - event.bid)
_event_spread(event::TradeEvent) = 0.0
_event_spread(event::BarEvent) = 0.0
_event_spread(event::ChainEvent) = 0.0
_event_spread(event::SessionEvent) = 0.0

_event_trade_price(event::TradeEvent) = event.price
_event_trade_price(event::BarEvent) = event.close
_event_trade_price(event::QuoteEvent) = nothing
_event_trade_price(event::ChainEvent) = nothing
_event_trade_price(event::SessionEvent) = nothing
