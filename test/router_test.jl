using CassandraBacktest
using Dates
using Test

@testset "SimulatedOrderRouter fills limit orders when market trades through" begin
    router = SimulatedOrderRouter(slippage = SlippageModel(fixed_per_leg = 0.0, spread_fraction = 0.0))
    order = Order(
        symbol = "SPY",
        side = Buy,
        quantity = 2,
        order_type = :limit,
        limit_price = 100.0,
        submitted_at = DateTime(2026, 4, 9, 10, 0, 0)
    )
    ref = submit!(router, order)
    process_event!(router,
        TradeEvent("SPY", 99.5, 10.0, DateTime(2026, 4, 9, 10, 0, 1)))

    @test length(fills(router)) == 1
    fill = only(fills(router))
    @test fill.ref == ref
    @test fill.price == 100.0
    @test isempty(router.pending_orders)
end

@testset "SimulatedOrderRouter applies slippage for market orders" begin
    router = SimulatedOrderRouter(slippage = SlippageModel(fixed_per_leg = 0.10, spread_fraction = 0.5))
    order = Order(
        symbol = "SPY",
        side = Buy,
        quantity = 1,
        order_type = :market,
        submitted_at = DateTime(2026, 4, 9, 10, 0, 0)
    )
    submit!(router, order)
    process_event!(router,
        QuoteEvent("SPY", 100.0, 100.4, DateTime(2026, 4, 9, 10, 0, 1)))

    fill = only(fills(router))
    expected_price = 100.2 + 0.10 + 0.5 * 0.4
    @test fill.price ≈ expected_price
    @test fill.fees ≈ 0.10
end
