struct BacktestConfig
    feed::AbstractMarketFeed
    router::AbstractOrderRouter
    start_time::DateTime
    end_time::DateTime
    handlers::Vector{Function}
end

function BacktestConfig(;
        feed::AbstractMarketFeed,
        router::AbstractOrderRouter,
        start_time::DateTime,
        end_time::DateTime,
        handlers::AbstractVector{<:Function} = Function[]
)
    start_time <= end_time || throw(ArgumentError("start_time must not exceed end_time"))
    return BacktestConfig(feed, router, start_time, end_time, collect(handlers))
end

struct BacktestResult
    fills::Vector{Fill}
    equity_curve::Vector{Tuple{DateTime, Float64}}
    events_processed::Int
    elapsed_ns::Int64
end

function run!(config::BacktestConfig)
    started_ns = time_ns()
    store = Dict{Symbol, Any}(
        :cash => 0.0,
        :position => Dict{String, Int}(),
        :last_event => nothing
    )
    equity_curve = Tuple{DateTime, Float64}[]
    events_processed = 0

    while !is_exhausted(config.feed)
        event = next_event!(config.feed)
        event === nothing && continue
        timestamp = event_time(event)
        timestamp < config.start_time && continue
        timestamp > config.end_time && break

        for handler in config.handlers
            handler(event, store, config.router)
        end

        if config.router isa SimulatedOrderRouter
            existing_fill_count = length(config.router.filled_orders)
            process_event!(config.router, event)
            _apply_new_fills!(store, config.router.filled_orders, existing_fill_count + 1)
        end

        events_processed += 1
        push!(equity_curve, (timestamp, store[:cash]))
        store[:last_event] = event
    end

    elapsed = time_ns() - started_ns
    final_fills = fills(config.router)
    return BacktestResult(final_fills, equity_curve, events_processed, elapsed)
end

function _apply_new_fills!(
        store::Dict{Symbol, Any},
        all_fills::Vector{Fill},
        from_index::Int
)
    from_index > length(all_fills) && return store
    positions = store[:position]
    for idx in from_index:length(all_fills)
        fill = all_fills[idx]
        direction = fill.side === Buy ? 1 : -1
        positions[fill.symbol] = get(positions, fill.symbol, 0) + direction * fill.quantity
        cash_delta = direction == 1 ? -(fill.quantity * fill.price + fill.fees) :
                     (fill.quantity * fill.price - fill.fees)
        store[:cash] += cash_delta
    end
    return store
end
