# CassandraBacktest Implemented Surface

Last changed: 2026-04-09T18:55:00+02:00

## Ecosystem Role

`CassandraBacktest.jl` provides the replay/backtest skeleton for Cassandra.
It defines shared interfaces that both live and replay execution paths can target.

## Public Surface

Implemented interfaces:

- `AbstractMarketFeed`
- `AbstractOrderRouter`
- required feed methods: `next_event!`, `current_time`, `is_exhausted`, `subscribe!`, `unsubscribe!`
- required router methods: `submit!`, `cancel!`, `replace!`, `fills`

Implemented event and order models:

- `MarketEvent` plus concrete events:
  - `QuoteEvent`
  - `TradeEvent`
  - `BarEvent`
  - `ChainEvent`
  - `SessionEvent`
- `Side` (`Buy`, `Sell`)
- `Order`, `OrderRef`, `Fill`
- `SlippageModel`

Implemented replay primitives:

- `SimulatedOrderRouter <: AbstractOrderRouter`
- `process_event!(router, event)` for simulated fill progression
- `BacktestConfig`
- `BacktestResult`
- `run!(config)` skeleton loop with:
  - feed exhaustion/time-window handling
  - ordered handler dispatch
  - simulated router fill processing
  - equity-curve accumulation

## Current Behavior Notes

- Limit orders fill at limit price when market trades through.
- Market orders fill at next quote mid plus slippage.
- No partial fills are modeled.
- Runner uses a minimal internal state dictionary and is designed for future handler expansion.

## Remaining Gaps

- Historical data loading and feed adapters are not implemented.
- Strategy/prediction handlers are not implemented.
- Analytics beyond fill ledger and cash-based equity curve are deferred.
