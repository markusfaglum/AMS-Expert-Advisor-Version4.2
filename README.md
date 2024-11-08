# Advanced-Market-Structure-Expert-Advisor-Version 4.2

This Expert Advisor (EA) utilizes a strategy based on a simplified interpretation of Advanced Market Structure (AMS). The EA is programmed to execute buy and sell orders only during specific periods, determined by a basic mathematical cycle. (Note: The GitHub code currently lacks the complete cycle dates, which are generated by a separate calculator outside of the EA, that I also built.)

The cycle aspect of this strategy is effective in identifying favorable periods for trading by leveraging a mathematical framework that determines the general trend of the market. However, the challenge is that identifying a date or period based on the cycle does not automatically translate to a viable trade. A date alone lacks the necessary context or decision-making criteria for executing a trade, such as determining the optimal entry point, setting stop losses, or managing risk effectively.

This is where Advanced Market Structure (AMS) comes into play. AMS helps define these critical elements by providing insights into price action and market structure. However, while AMS offers valuable guidance, it is insufficient on its own to form a complete strategy. Without additional components, like the cycle to help guide entry timing, AMS lacks the broader context required for precise trade decisions. To develop a fully effective strategy, both the cycle and an additional component—such as AMS—are required. While the cycle identifies the optimal moments to take action, AMS provides the necessary decision-making framework to guide trade execution.

To enter a trade, the EA identifies the highest price within a specified range of bars. From this peak, it looks backward until it finds the first bar that closed lower than it opened. If the current bar closes below the lowest price between the extreme high and the first down bar, a trade is initiated at that price, with a stop loss placed at the extreme high. The opposite process is applied for short trades.

Attempts to complicate the strategy or code have not yielded improved results.

Inputs:
- Several pattern filters calculated as a percentage of the current price
- Takeprofit based on risk-to-reward ratio
- Trailing Stop Loss
- Supertrend indicator
- Variable lot size based on percentage of account balance to risk
- Martingale strategy

11 adjustable inputs in total

The Expert Advisor used for backtesting has access to the complete cycle dates for the relevant period. Martingale, index filter, and the supertrend indicator are all disabled in the backtests based on the optimization results (not shown here).

Data from 2015 to 2024 was used for optimizing EA inputs.

Data from 2009 to 2015: https://markusfaglum.github.io/AMS-Expert-Advisor-Version4.2/
This was used to verify the results of the optimization (forward test). No changes were made to the EA or inputs based on this time period.
