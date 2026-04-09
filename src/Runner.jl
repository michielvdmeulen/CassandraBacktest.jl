struct BacktestConfig{
    F <: AbstractMarketFeed,
    R <: AbstractOrderRouter,
    H <: Tuple
}
    feed::F
    router::R
    start_time::DateTime
    end_time::DateTime
    handlers::H
end

function BacktestConfig(;
        feed::AbstractMarketFeed,
        router::AbstractOrderRouter,
        start_time::DateTime,
        end_time::DateTime,
        handlers::AbstractVector{<:Function} = Function[]
)
    start_time <= end_time || throw(ArgumentError("start_time must not exceed end_time"))
    return BacktestConfig(feed, router, start_time, end_time, Tuple(handlers))
end

struct BacktestResult
    fills::Vector{Fill}
    equity_curve::Vector{Tuple{DateTime, Float64}}
    events_processed::Int
    elapsed_ns::Int64
end

mutable struct _RunnerState
    cash::Float64
    positions::Dict{String, Int}
    last_event::Union{Nothing, MarketEvent}
end

function run!(config::BacktestConfig)
    started_ns = time_ns()
    state = _RunnerState(0.0, Dict{String, Int}(), nothing)
    equity_curve = Tuple{DateTime, Float64}[]
    events_processed = 0

    while !is_exhausted(config.feed)
        event = next_event!(config.feed)
        event === nothing && continue
        timestamp = event_time(event)
        timestamp < config.start_time && continue
        timestamp > config.end_time && break

        for handler in config.handlers
            handler(event, state, config.router)
        end

        if config.router isa SimulatedOrderRouter
            existing_fill_count = length(config.router.filled_orders)
            process_event!(config.router, event)
            _apply_new_fills!(state, config.router.filled_orders, existing_fill_count + 1)
        end

        events_processed += 1
        push!(equity_curve, (timestamp, state.cash))
        state.last_event = event
    end

    elapsed = time_ns() - started_ns
    final_fills = fills(config.router)
    return BacktestResult(final_fills, equity_curve, events_processed, elapsed)
end

function _apply_new_fills!(
        state::_RunnerState,
        all_fills::Vector{Fill},
        from_index::Int
)
    from_index > length(all_fills) && return state
    positions = state.positions
    for idx in from_index:length(all_fills)
        fill = all_fills[idx]
        direction = fill.side === Buy ? 1 : -1
        positions[fill.symbol] = get(positions, fill.symbol, 0) + direction * fill.quantity
        cash_delta = direction == 1 ? -(fill.quantity * fill.price + fill.fees) :
                     (fill.quantity * fill.price - fill.fees)
        state.cash += cash_delta
    end
    return state
end
