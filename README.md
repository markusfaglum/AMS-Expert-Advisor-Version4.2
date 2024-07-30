# Advanced-Market-Structure-Expert-Advisor-Version 4.2

This is an expert advisor using a startegy based on a very simplified understanding of Advanced Market Structure. It finds the extreme high looking back X amount of bars. Then from the high looks back until it finds the first bar that closed lower than it opened. If the current bar closes below the lowest price between the extreme high and the first down bar, an order is placed at that price with a stop loss at the extreme high. The reverse is done for a short.

Inputs:
- Several pattern filters calculated in precentage of the current price
- Takeprofit based on risk to reward
- Trailing Stop Loss
- Supertrend indicator
- Variable lot size based on precentage of account balance to risk
- Martingale strategy
- 11 adjusatble inputs in total

The EA will only buy and sell during certain periods based a simple understanding of the cycle work.(github version is missing complete cycle dates produced by calculator outside of this EA)

Complicating the strategy/code has not yet produced better results.

The Expert Advisor used for the backtests has access the complete cycle work/dates for the relevant period. Martingale strategy, index filter and supertrend indicator are all disabled in the backtests based on the optimization results(not shown here).

2015-2024 data used for optimizing EA inputs.

2009-2015 data is used to verify results of the optimization(forward test). No changes made to the EA or inputs based on this time period.

In testing the risk used per trade is fixed, for more accurate evaluation of results.
