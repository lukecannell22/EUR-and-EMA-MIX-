//+------------------------------------------------------------------+
//|                                      EURUSD_CVD_MACD_EMA_EA.mq5  |
//|                        Combined Strategy: CVD + MACD + EMA Cross |
//|                              Converted from TradingView Pine     |
//+------------------------------------------------------------------+
#property copyright "Converted from TradingView Pine Script"
#property link      ""
#property version   "1.01"
#property description "MACD + EMA Cross Strategy with Golden/Death Cross signals"

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\SymbolInfo.mqh>

//+------------------------------------------------------------------+
//| Input parameters                                                   |
//+------------------------------------------------------------------+

//--- EMA Settings
sinput string  EMA_Settings = "=== EMA Settings ===";  // --- EMA Settings ---
input int      EMA_Fast_Period = 20;          // Fast EMA Period
input int      EMA_Slow_Period = 50;          // Slow EMA Period
input int      EMA_Direction_Period = 238;    // Direction EMA Period

//--- MACD Settings
sinput string  MACD_Settings = "=== MACD Settings ===";  // --- MACD Settings ---
input int      MACD_Fast_Length = 12;         // MACD Fast Length
input int      MACD_Slow_Length = 26;         // MACD Slow Length
input int      MACD_Signal_Length = 9;        // MACD Signal Smoothing

//--- Trade Management
sinput string  Trade_Settings = "=== Trade Management ===";  // --- Trade Management ---
input double   StopLoss_Pips = 5.0;           // Stop Loss (Pips)
input double   RiskPercent = 1.0;             // Risk % of Equity
input double   TP1_Pips = 10.0;               // TP1 (Pips)
input bool     EnableTP2 = false;             // Enable TP2
input double   TP2_Pips = 20.0;               // TP2 (Pips)
input bool     EnableTP3 = false;             // Enable TP3
input double   TP3_Pips = 30.0;               // TP3 (Pips)
input bool     MoveToBreakevenAfterTP1 = true; // Move to Breakeven after TP1

//--- Entry Signal Settings
sinput string  Entry_Settings = "=== Entry Signal Settings ===";  // --- Entry Settings ---
input bool     EnableMacdEmaEntry = true;     // Enable MACD + EMA Entry Signal
input bool     RequireKillZone = false;       // Require Kill Zone
input bool     RequireDayFilter = true;       // Require Day Filter

//--- Kill Zone Settings (with proper time inputs)
sinput string  KZ_Settings = "=== Kill Zone Trading Windows ===";  // --- Kill Zone Settings ---
input bool     EnableLondonKZ = true;         // Enable London Kill Zone
input string   LondonKZ_Start = "02:00";      // London KZ Start Time (HH:MM)
input string   LondonKZ_End = "06:00";        // London KZ End Time (HH:MM)
input bool     EnableNYKZ = false;            // Enable New York Kill Zone
input string   NYKZ_Start = "09:00";          // NY KZ Start Time (HH:MM)
input string   NYKZ_End = "12:00";            // NY KZ End Time (HH:MM)

//--- Trading Days
sinput string  Day_Settings = "=== Trading Days ===";  // --- Trading Days ---
input bool     TradeMonday = true;            // Monday
input bool     TradeTuesday = true;           // Tuesday
input bool     TradeWednesday = true;         // Wednesday
input bool     TradeThursday = true;          // Thursday
input bool     TradeFriday = true;            // Friday
input bool     TradeSaturday = false;         // Saturday
input bool     TradeSunday = true;            // Sunday

//--- Visual Settings
sinput string  Visual_Settings = "=== Visual Settings ===";  // --- Visual Settings ---
input bool     ShowEmaLines = true;           // Show EMA Lines
input color    EMA_Fast_Color = clrGreen;         // Fast EMA Color
input color    EMA_Slow_Color = clrRed;           // Slow EMA Color
input color    EMA_Direction_Color = clrBlue;     // Direction EMA Color

//--- Global variables
CTrade         trade;
CPositionInfo  positionInfo;
CSymbolInfo    symbolInfo;

int            handleEMA_Fast;
int            handleEMA_Slow;
int            handleEMA_Dir;
int            handleMACD;

double         emaBufferFast[];
double         emaBufferSlow[];
double         emaBufferDir[];
double         macdMain[];
double         macdSignal[];

int            magicNumber = 123456;
double         pointValue;
int            digits;

//+------------------------------------------------------------------+
//| Expert initialization function                                     |
//+------------------------------------------------------------------+
int OnInit()
{
   //--- Initialize symbol info
   if(!symbolInfo.Name(Symbol()))
   {
      Print("Error initializing symbol info");
      return(INIT_FAILED);
   }
   
   pointValue = symbolInfo.Point();
   digits = (int)symbolInfo.Digits();
   
   //--- Debug: Print initialization values
   Print("=== EA Initialized ===");
   Print("Symbol: ", Symbol(), " Digits: ", digits, " Point: ", pointValue);
   Print("For 5 pips, price distance = ", PipsToPrice(5.0));
   Print("EMA Fast: ", EMA_Fast_Period, " EMA Slow: ", EMA_Slow_Period);
   
   //--- Set magic number for trade identification
   trade.SetExpertMagicNumber(magicNumber);
   trade.SetDeviationInPoints(30);  // Allow more slippage
   trade.SetTypeFilling(ORDER_FILLING_FOK);  // Try FOK first
   
   //--- Create EMA handles
   handleEMA_Fast = iMA(Symbol(), PERIOD_CURRENT, EMA_Fast_Period, 0, MODE_EMA, PRICE_CLOSE);
   handleEMA_Slow = iMA(Symbol(), PERIOD_CURRENT, EMA_Slow_Period, 0, MODE_EMA, PRICE_CLOSE);
   handleEMA_Dir = iMA(Symbol(), PERIOD_CURRENT, EMA_Direction_Period, 0, MODE_EMA, PRICE_CLOSE);
   
   //--- Create MACD handle
   handleMACD = iMACD(Symbol(), PERIOD_CURRENT, MACD_Fast_Length, MACD_Slow_Length, MACD_Signal_Length, PRICE_CLOSE);
   
   //--- Check handles
   if(handleEMA_Fast == INVALID_HANDLE || handleEMA_Slow == INVALID_HANDLE || 
      handleEMA_Dir == INVALID_HANDLE || handleMACD == INVALID_HANDLE)
   {
      Print("Error creating indicator handles");
      return(INIT_FAILED);
   }
   
   //--- Set array as series
   ArraySetAsSeries(emaBufferFast, true);
   ArraySetAsSeries(emaBufferSlow, true);
   ArraySetAsSeries(emaBufferDir, true);
   ArraySetAsSeries(macdMain, true);
   ArraySetAsSeries(macdSignal, true);
   
   Print("EURUSD MACD + EMA EA initialized successfully");
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                   |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   //--- Release indicator handles
   IndicatorRelease(handleEMA_Fast);
   IndicatorRelease(handleEMA_Slow);
   IndicatorRelease(handleEMA_Dir);
   IndicatorRelease(handleMACD);
   
   Print("EURUSD MACD + EMA EA deinitialized");
}

//+------------------------------------------------------------------+
//| Expert tick function                                               |
//+------------------------------------------------------------------+
void OnTick()
{
   //--- Check for new bar
   static datetime lastBarTime = 0;
   datetime currentBarTime = iTime(Symbol(), PERIOD_CURRENT, 0);
   
   if(lastBarTime == currentBarTime)
      return;  // Only process once per bar
   
   lastBarTime = currentBarTime;
   
   //--- Copy indicator data (need 3 bars for cross detection)
   if(CopyBuffer(handleEMA_Fast, 0, 0, 3, emaBufferFast) < 3)
   {
      Print("Failed to copy Fast EMA buffer");
      return;
   }
   if(CopyBuffer(handleEMA_Slow, 0, 0, 3, emaBufferSlow) < 3)
   {
      Print("Failed to copy Slow EMA buffer");
      return;
   }
   if(CopyBuffer(handleEMA_Dir, 0, 0, 3, emaBufferDir) < 3)
   {
      Print("Failed to copy Direction EMA buffer");
      return;
   }
   if(CopyBuffer(handleMACD, 0, 0, 3, macdMain) < 3)
   {
      Print("Failed to copy MACD Main buffer");
      return;
   }
   if(CopyBuffer(handleMACD, 1, 0, 3, macdSignal) < 3)
   {
      Print("Failed to copy MACD Signal buffer");
      return;
   }
   
   //--- Check entry conditions
   if(EnableMacdEmaEntry && !HasOpenPosition())
   {
      CheckEntrySignals();
   }
   
   //--- Manage open positions (TP1 breakeven, etc.)
   ManagePositions();
}

//+------------------------------------------------------------------+
//| Parse time string to hour and minute                               |
//+------------------------------------------------------------------+
void ParseTime(string timeStr, int &hour, int &minute)
{
   string parts[];
   int count = StringSplit(timeStr, ':', parts);
   if(count >= 2)
   {
      hour = (int)StringToInteger(parts[0]);
      minute = (int)StringToInteger(parts[1]);
   }
   else
   {
      hour = 0;
      minute = 0;
   }
}

//+------------------------------------------------------------------+
//| Check if current time is in a time range                           |
//+------------------------------------------------------------------+
bool IsInTimeRange(string startTime, string endTime)
{
   MqlDateTime dt;
   TimeCurrent(dt);
   
   int startHour, startMin, endHour, endMin;
   ParseTime(startTime, startHour, startMin);
   ParseTime(endTime, endHour, endMin);
   
   int currentMinutes = dt.hour * 60 + dt.min;
   int startMinutes = startHour * 60 + startMin;
   int endMinutes = endHour * 60 + endMin;
   
   if(startMinutes <= endMinutes)
   {
      // Same day range
      return (currentMinutes >= startMinutes && currentMinutes < endMinutes);
   }
   else
   {
      // Crosses midnight
      return (currentMinutes >= startMinutes || currentMinutes < endMinutes);
   }
}

//+------------------------------------------------------------------+
//| Check for entry signals                                            |
//+------------------------------------------------------------------+
void CheckEntrySignals()
{
   //--- Check day filter
   if(RequireDayFilter && !IsTradingDayEnabled())
   {
      return;
   }
   
   //--- Check kill zone filter
   if(RequireKillZone && !IsInKillZone())
   {
      return;
   }
   
   //--- Values from completed bars (bar index 1 = last completed, 2 = bar before that)
   double emaFastCurrent = emaBufferFast[1];
   double emaSlowCurrent = emaBufferSlow[1];
   double emaFastPrev = emaBufferFast[2];
   double emaSlowPrev = emaBufferSlow[2];
   double macdMainCurrent = macdMain[1];
   double macdSignalCurrent = macdSignal[1];
   
   //--- Debug output
   Print("Checking signals - Fast EMA: ", emaFastCurrent, " Slow EMA: ", emaSlowCurrent);
   Print("Previous - Fast EMA: ", emaFastPrev, " Slow EMA: ", emaSlowPrev);
   Print("MACD: ", macdMainCurrent, " Signal: ", macdSignalCurrent);
   
   //--- Detect Golden Cross (Fast EMA crosses ABOVE Slow EMA)
   bool goldenCross = (emaFastPrev <= emaSlowPrev) && (emaFastCurrent > emaSlowCurrent);
   
   //--- Detect Death Cross (Fast EMA crosses BELOW Slow EMA)
   bool deathCross = (emaFastPrev >= emaSlowPrev) && (emaFastCurrent < emaSlowCurrent);
   
   //--- MACD Confirmation
   bool macdBullish = macdMainCurrent > macdSignalCurrent;
   bool macdBearish = macdMainCurrent < macdSignalCurrent;
   
   //--- Buy Signal: Golden Cross + MACD Bullish
   if(goldenCross && macdBullish)
   {
      Print(">>> BUY SIGNAL DETECTED: Golden Cross with MACD Bullish confirmation <<<");
      ExecuteBuyOrder();
   }
   
   //--- Sell Signal: Death Cross + MACD Bearish
   if(deathCross && macdBearish)
   {
      Print(">>> SELL SIGNAL DETECTED: Death Cross with MACD Bearish confirmation <<<");
      ExecuteSellOrder();
   }
}

//+------------------------------------------------------------------+
//| Execute Buy Order                                                  |
//+------------------------------------------------------------------+
void ExecuteBuyOrder()
{
   //--- Refresh symbol info to get current prices
   if(!symbolInfo.RefreshRates())
   {
      Print("Failed to refresh rates");
      return;
   }
   
   double ask = symbolInfo.Ask();
   double bid = symbolInfo.Bid();
   
   if(ask == 0 || bid == 0)
   {
      Print("Invalid prices: Ask=", ask, " Bid=", bid);
      return;
   }
   
   //--- Calculate stop loss and take profit as actual price levels
   double slDistance = PipsToPrice(StopLoss_Pips);
   double tpDistance = PipsToPrice(TP1_Pips);
   
   double slPrice = NormalizeDouble(ask - slDistance, digits);
   double tp1Price = NormalizeDouble(ask + tpDistance, digits);
   
   //--- Calculate lot size based on risk
   double lotSize = CalculateLotSize(StopLoss_Pips);
   
   //--- Debug output
   Print("=== BUY Order ===");
   Print("Ask: ", ask, " Bid: ", bid);
   Print("SL Price: ", slPrice, " (", slDistance, " below ask)");
   Print("TP Price: ", tp1Price, " (", tpDistance, " above ask)");
   Print("Lot Size: ", lotSize);
   
   //--- Execute order
   if(trade.Buy(lotSize, Symbol(), ask, slPrice, tp1Price, "MACD+EMA Buy"))
   {
      Print("BUY order executed successfully!");
   }
   else
   {
      Print("BUY order FAILED: Error ", trade.ResultRetcode(), " - ", trade.ResultRetcodeDescription());
   }
}

//+------------------------------------------------------------------+
//| Execute Sell Order                                                 |
//+------------------------------------------------------------------+
void ExecuteSellOrder()
{
   //--- Refresh symbol info to get current prices
   if(!symbolInfo.RefreshRates())
   {
      Print("Failed to refresh rates");
      return;
   }
   
   double ask = symbolInfo.Ask();
   double bid = symbolInfo.Bid();
   
   if(ask == 0 || bid == 0)
   {
      Print("Invalid prices: Ask=", ask, " Bid=", bid);
      return;
   }
   
   //--- Calculate stop loss and take profit as actual price levels
   double slDistance = PipsToPrice(StopLoss_Pips);
   double tpDistance = PipsToPrice(TP1_Pips);
   
   double slPrice = NormalizeDouble(bid + slDistance, digits);
   double tp1Price = NormalizeDouble(bid - tpDistance, digits);
   
   //--- Calculate lot size based on risk
   double lotSize = CalculateLotSize(StopLoss_Pips);
   
   //--- Debug output
   Print("=== SELL Order ===");
   Print("Ask: ", ask, " Bid: ", bid);
   Print("SL Price: ", slPrice, " (", slDistance, " above bid)");
   Print("TP Price: ", tp1Price, " (", tpDistance, " below bid)");
   Print("Lot Size: ", lotSize);
   
   //--- Execute order
   if(trade.Sell(lotSize, Symbol(), bid, slPrice, tp1Price, "MACD+EMA Sell"))
   {
      Print("SELL order executed successfully!");
   }
   else
   {
      Print("SELL order FAILED: Error ", trade.ResultRetcode(), " - ", trade.ResultRetcodeDescription());
   }
}

//+------------------------------------------------------------------+
//| Calculate lot size based on risk percentage                        |
//+------------------------------------------------------------------+
double CalculateLotSize(double slPips)
{
   double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskAmount = accountBalance * (RiskPercent / 100.0);
   
   //--- Get tick value and size
   double tickValue = symbolInfo.TickValue();
   double tickSize = symbolInfo.TickSize();
   
   if(tickValue == 0 || tickSize == 0)
   {
      Print("Invalid tick info, using minimum lot");
      return symbolInfo.LotsMin();
   }
   
   //--- Calculate pip value (for 5-digit brokers, 1 pip = 10 points)
   double pipSize = (digits == 5 || digits == 3) ? pointValue * 10 : pointValue;
   double pipValue = tickValue * (pipSize / tickSize);
   
   //--- Calculate lot size
   double lotSize = riskAmount / (slPips * pipValue);
   
   //--- Normalize lot size
   double minLot = symbolInfo.LotsMin();
   double maxLot = symbolInfo.LotsMax();
   double lotStep = symbolInfo.LotsStep();
   
   lotSize = MathFloor(lotSize / lotStep) * lotStep;
   lotSize = MathMax(minLot, MathMin(maxLot, lotSize));
   
   return NormalizeDouble(lotSize, 2);
}

//+------------------------------------------------------------------+
//| Convert pips to price                                              |
//+------------------------------------------------------------------+
double PipsToPrice(double pips)
{
   //--- For 5-digit brokers (EURUSD, etc.) 1 pip = 10 points
   if(digits == 5 || digits == 3)
      return pips * pointValue * 10;
   else
      return pips * pointValue;
}

//+------------------------------------------------------------------+
//| Check if current day is enabled for trading                        |
//+------------------------------------------------------------------+
bool IsTradingDayEnabled()
{
   MqlDateTime dt;
   TimeCurrent(dt);
   
   switch(dt.day_of_week)
   {
      case 0: return TradeSunday;
      case 1: return TradeMonday;
      case 2: return TradeTuesday;
      case 3: return TradeWednesday;
      case 4: return TradeThursday;
      case 5: return TradeFriday;
      case 6: return TradeSaturday;
   }
   return false;
}

//+------------------------------------------------------------------+
//| Check if current time is in kill zone                              |
//+------------------------------------------------------------------+
bool IsInKillZone()
{
   //--- Check London Kill Zone
   if(EnableLondonKZ && IsInTimeRange(LondonKZ_Start, LondonKZ_End))
      return true;
   
   //--- Check NY Kill Zone
   if(EnableNYKZ && IsInTimeRange(NYKZ_Start, NYKZ_End))
      return true;
   
   return false;
}

//+------------------------------------------------------------------+
//| Check if there's an open position                                  |
//+------------------------------------------------------------------+
bool HasOpenPosition()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(positionInfo.SelectByIndex(i))
      {
         if(positionInfo.Symbol() == Symbol() && positionInfo.Magic() == magicNumber)
            return true;
      }
   }
   return false;
}

//+------------------------------------------------------------------+
//| Manage open positions (breakeven, etc.)                            |
//+------------------------------------------------------------------+
void ManagePositions()
{
   if(!MoveToBreakevenAfterTP1)
      return;
      
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(positionInfo.SelectByIndex(i))
      {
         if(positionInfo.Symbol() != Symbol() || positionInfo.Magic() != magicNumber)
            continue;
         
         double entryPrice = positionInfo.PriceOpen();
         double currentSL = positionInfo.StopLoss();
         double currentPrice = positionInfo.PriceCurrent();
         double tp1Distance = PipsToPrice(TP1_Pips);
         
         //--- For buy positions
         if(positionInfo.PositionType() == POSITION_TYPE_BUY)
         {
            double tp1Level = entryPrice + tp1Distance;
            
            //--- If price has reached TP1 and SL is not at breakeven yet
            if(currentPrice >= tp1Level && currentSL < entryPrice)
            {
               double newSL = NormalizeDouble(entryPrice + pointValue, digits);
               if(trade.PositionModify(positionInfo.Ticket(), newSL, positionInfo.TakeProfit()))
               {
                  Print("BUY position moved to breakeven");
               }
            }
         }
         //--- For sell positions
         else if(positionInfo.PositionType() == POSITION_TYPE_SELL)
         {
            double tp1Level = entryPrice - tp1Distance;
            
            //--- If price has reached TP1 and SL is not at breakeven yet
            if(currentPrice <= tp1Level && currentSL > entryPrice)
            {
               double newSL = NormalizeDouble(entryPrice - pointValue, digits);
               if(trade.PositionModify(positionInfo.Ticket(), newSL, positionInfo.TakeProfit()))
               {
                  Print("SELL position moved to breakeven");
               }
            }
         }
      }
   }
}
//+------------------------------------------------------------------+
