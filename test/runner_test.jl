using CassandraBacktest
using Dates
using Test

mutable struct MockFeed <: AbstractMarketFeed
    events::Vector{MarketEvent}
    cursor::Int
end

MockFeed(events::AbstractVector{<:MarketEvent}) = MockFeed(collect(MarketEvent, events), 1)

function CassandraBacktest.next_event!(feed::MockFeed)
    feed.cursor > length(feed.events) && return nothing
    event = feed.events[feed.cursor]
    feed.cursor += 1
    return event
end

function CassandraBacktest.current_time(feed::MockFeed)
    feed.cursor > length(feed.events) && return DateTime(2026, 4, 9, 0, 0, 0)
    return feed.events[feed.cursor].timestamp
end

CassandraBacktest.is_exhausted(feed::MockFeed) = feed.cursor > length(feed.events)
CassandraBacktest.subscribe!(::MockFeed, _symbol, _event_types) = nothing
CassandraBacktest.unsubscribe!(::MockFeed, _symbol) = nothing

@testset "BacktestRunner terminates when feed is exhausted" begin
    feed = MockFeed([
        SessionEvent(:open, DateTime(2026, 4, 9, 10, 0, 0)),
        SessionEvent(:close, DateTime(2026, 4, 9, 10, 0, 1))
    ])
    router = SimulatedOrderRouter()
    result = run!(BacktestConfig(
        feed = feed,
        router = router,
        start_time = DateTime(2026, 4, 9, 9, 59, 0),
        end_time = DateTime(2026, 4, 9, 10, 1, 0)
    ))

    @test result.events_processed == 2
    @test length(result.equity_curve) == 2
end

@testset "BacktestRunner dispatches handlers in order" begin
    feed = MockFeed([SessionEvent(:open, DateTime(2026, 4, 9, 10, 0, 0))])
    router = SimulatedOrderRouter()
    calls = String[]

    handlers = Function[
    (event, _store, _router) -> push!(calls, "first"),
    (
        event, _store, _router) -> push!(calls, "second")
]
    _ = run!(BacktestConfig(
        feed = feed,
        router = router,
        start_time = DateTime(2026, 4, 9, 9, 59, 0),
        end_time = DateTime(2026, 4, 9, 10, 1, 0),
        handlers = handlers
    ))

    @test calls == ["first", "second"]
end

@testset "BacktestResult equity curve timestamps follow processed events" begin
    feed = MockFeed([
        QuoteEvent("SPY", 100.0, 100.2, DateTime(2026, 4, 9, 10, 0, 0)),
        QuoteEvent("SPY", 100.1, 100.3, DateTime(2026, 4, 9, 10, 0, 1))
    ])
    router = SimulatedOrderRouter()
    order = Order(
        symbol = "SPY",
        side = Buy,
        quantity = 1,
        order_type = :market,
        submitted_at = DateTime(2026, 4, 9, 9, 59, 59)
    )
    submit!(router, order)

    result = run!(BacktestConfig(
        feed = feed,
        router = router,
        start_time = DateTime(2026, 4, 9, 9, 59, 0),
        end_time = DateTime(2026, 4, 9, 10, 1, 0)
    ))

    @test getfield.(result.equity_curve, 1) == [
        DateTime(2026, 4, 9, 10, 0, 0),
        DateTime(2026, 4, 9, 10, 0, 1)
    ]
end
