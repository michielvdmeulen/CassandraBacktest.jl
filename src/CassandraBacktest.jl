module CassandraBacktest

using Dates

include("Types.jl")
include("Interfaces.jl")
include("Router.jl")
include("Runner.jl")

export AbstractMarketFeed,
       AbstractOrderRouter,
       next_event!,
       current_time,
       is_exhausted,
       subscribe!,
       unsubscribe!,
       submit!,
       cancel!,
       replace!,
       fills
export MarketEvent, QuoteEvent, TradeEvent, BarEvent, ChainEvent, SessionEvent
export Side, Buy, Sell, Order, OrderRef, Fill, SlippageModel, SimulatedOrderRouter
export BacktestConfig, BacktestResult, run!
export process_event!

end
