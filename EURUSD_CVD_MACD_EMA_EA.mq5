//+------------------------------------------------------------------+
//|                                      EURUSD_CVD_MACD_EMA_EA.mq5  |
//|                        Combined Strategy: CVD + MACD + EMA Cross |
//|                              Converted from TradingView Pine     |
//+------------------------------------------------------------------+
#property copyright "Converted from TradingView Pine Script"
#property link      ""
#property version   "1.00"
#property description "MACD + EMA Cross Strategy with Golden/Death Cross signals"

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\SymbolInfo.mqh>

//+------------------------------------------------------------------+
//| Input parameters                                                   |
//+------------------------------------------------------------------+

//--- EMA Settings
sinput string  EMA_Settings = "=== EMA Settings ===";  // --- EMA Settings ---
input int      EMA_Momentum_Period = 8;       // Momentum EMA Period
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
input double   TP1_Percent = 100.0;           // TP1 Exit %
input double   TP2_Percent = 25.0;            // TP2 Exit %
input bool     MoveToBreakevenAfterTP1 = true; // Move to Breakeven after TP1

//--- Entry Signal Settings
sinput string  Entry_Settings = "=== Entry Signal Settings ===";  // --- Entry Settings ---
input bool     EnableMacdEmaEntry = true;     // Enable MACD + EMA Entry Signal
input bool     RequireKillZone = false;       // Require Kill Zone
input bool     RequireDayFilter = true;       // Require Day Filter

//--- Kill Zone Settings
sinput string  KZ_Settings = "=== Kill Zone Trading Windows ===";  // --- Kill Zone Settings ---
input bool     EnableLondonKZ = true;         // Enable London Kill Zone
input int      LondonKZ_StartHour = 2;        // London KZ Start Hour (Server Time)
input int      LondonKZ_EndHour = 6;          // London KZ End Hour (Server Time)
input bool     EnableNYKZ = false;            // Enable New York Kill Zone
input int      NYKZ_StartHour = 9;            // NY KZ Start Hour (Server Time)
input int      NYKZ_EndHour = 12;             // NY KZ End Hour (Server Time)

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
input color    EMA_Momentum_Color = clrMagenta;   // Momentum EMA Color
input color    EMA_Fast_Color = clrGreen;         // Fast EMA Color
input color    EMA_Slow_Color = clrRed;           // Slow EMA Color
input color    EMA_Direction_Color = clrBlue;     // Direction EMA Color

//--- Global variables
CTrade         trade;
CPositionInfo  positionInfo;
CSymbolInfo    symbolInfo;

int            handleEMA_Mom;
int            handleEMA_Fast;
int            handleEMA_Slow;
int            handleEMA_Dir;
int            handleMACD;

double         emaBufferMom[];
double         emaBufferFast[];
double         emaBufferSlow[];
double         emaBufferDir[];
double         macdMain[];
double         macdSignal[];

double         prevEmaFast = 0;
double         prevEmaSlow = 0;
bool           initialized = false;

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
   
   //--- Set magic number for trade identification
   trade.SetExpertMagicNumber(magicNumber);
   trade.SetDeviationInPoints(10);
   trade.SetTypeFilling(ORDER_FILLING_IOC);
   
   //--- Create EMA handles
   handleEMA_Mom = iMA(Symbol(), PERIOD_CURRENT, EMA_Momentum_Period, 0, MODE_EMA, PRICE_CLOSE);
   handleEMA_Fast = iMA(Symbol(), PERIOD_CURRENT, EMA_Fast_Period, 0, MODE_EMA, PRICE_CLOSE);
   handleEMA_Slow = iMA(Symbol(), PERIOD_CURRENT, EMA_Slow_Period, 0, MODE_EMA, PRICE_CLOSE);
   handleEMA_Dir = iMA(Symbol(), PERIOD_CURRENT, EMA_Direction_Period, 0, MODE_EMA, PRICE_CLOSE);
   
   //--- Create MACD handle
   handleMACD = iMACD(Symbol(), PERIOD_CURRENT, MACD_Fast_Length, MACD_Slow_Length, MACD_Signal_Length, PRICE_CLOSE);
   
   //--- Check handles
   if(handleEMA_Mom == INVALID_HANDLE || handleEMA_Fast == INVALID_HANDLE || 
      handleEMA_Slow == INVALID_HANDLE || handleEMA_Dir == INVALID_HANDLE ||
      handleMACD == INVALID_HANDLE)
   {
      Print("Error creating indicator handles");
      return(INIT_FAILED);
   }
   
   //--- Set array as series
   ArraySetAsSeries(emaBufferMom, true);
   ArraySetAsSeries(emaBufferFast, true);
   ArraySetAsSeries(emaBufferSlow, true);
   ArraySetAsSeries(emaBufferDir, true);
   ArraySetAsSeries(macdMain, true);
   ArraySetAsSeries(macdSignal, true);
   
   Print("EURUSD CVD + MACD EMA EA initialized successfully");
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                   |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   //--- Release indicator handles
   IndicatorRelease(handleEMA_Mom);
   IndicatorRelease(handleEMA_Fast);
   IndicatorRelease(handleEMA_Slow);
   IndicatorRelease(handleEMA_Dir);
   IndicatorRelease(handleMACD);
   
   //--- Remove objects
   ObjectsDeleteAll(0, "EMA_");
   
   Print("EURUSD CVD + MACD EMA EA deinitialized");
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
   
   //--- Copy indicator data
   if(CopyBuffer(handleEMA_Mom, 0, 0, 3, emaBufferMom) < 3) return;
   if(CopyBuffer(handleEMA_Fast, 0, 0, 3, emaBufferFast) < 3) return;
   if(CopyBuffer(handleEMA_Slow, 0, 0, 3, emaBufferSlow) < 3) return;
   if(CopyBuffer(handleEMA_Dir, 0, 0, 3, emaBufferDir) < 3) return;
   if(CopyBuffer(handleMACD, 0, 0, 3, macdMain) < 3) return;
   if(CopyBuffer(handleMACD, 1, 0, 3, macdSignal) < 3) return;
   
   //--- Store previous values for cross detection
   if(!initialized)
   {
      prevEmaFast = emaBufferFast[1];
      prevEmaSlow = emaBufferSlow[1];
      initialized = true;
      return;
   }
   
   //--- Draw EMA lines if enabled
   if(ShowEmaLines)
   {
      DrawEmaLines();
   }
   
   //--- Check entry conditions
   if(EnableMacdEmaEntry && !HasOpenPosition())
   {
      CheckEntrySignals();
   }
   
   //--- Manage open positions (TP1 breakeven, etc.)
   ManagePositions();
   
   //--- Update previous values
   prevEmaFast = emaBufferFast[1];
   prevEmaSlow = emaBufferSlow[1];
}

//+------------------------------------------------------------------+
//| Check for entry signals                                            |
//+------------------------------------------------------------------+
void CheckEntrySignals()
{
   //--- Check day filter
   if(RequireDayFilter && !IsTradingDayEnabled())
      return;
   
   //--- Check kill zone filter
   if(RequireKillZone && !IsInKillZone())
      return;
   
   //--- Current values (bar 1, completed bar)
   double emaFastCurrent = emaBufferFast[1];
   double emaSlowCurrent = emaBufferSlow[1];
   double macdMainCurrent = macdMain[1];
   double macdSignalCurrent = macdSignal[1];
   
   //--- Previous values (bar 2)
   double emaFastPrev = emaBufferFast[2];
   double emaSlowPrev = emaBufferSlow[2];
   
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
      Print("BUY SIGNAL: Golden Cross with MACD Bullish confirmation");
      ExecuteBuyOrder();
   }
   
   //--- Sell Signal: Death Cross + MACD Bearish
   if(deathCross && macdBearish)
   {
      Print("SELL SIGNAL: Death Cross with MACD Bearish confirmation");
      ExecuteSellOrder();
   }
}

//+------------------------------------------------------------------+
//| Execute Buy Order                                                  |
//+------------------------------------------------------------------+
void ExecuteBuyOrder()
{
   double ask = symbolInfo.Ask();
   double bid = symbolInfo.Bid();
   
   //--- Calculate stop loss and take profit in price
   double slPrice = ask - PipsToPrice(StopLoss_Pips);
   double tp1Price = ask + PipsToPrice(TP1_Pips);
   
   //--- Calculate lot size based on risk
   double lotSize = CalculateLotSize(StopLoss_Pips);
   
   //--- Normalize prices
   slPrice = NormalizeDouble(slPrice, digits);
   tp1Price = NormalizeDouble(tp1Price, digits);
   
   //--- Execute order
   if(trade.Buy(lotSize, Symbol(), ask, slPrice, tp1Price, "MACD+EMA Golden Cross"))
   {
      Print("BUY order executed: Lot=", lotSize, " SL=", slPrice, " TP=", tp1Price);
   }
   else
   {
      Print("BUY order failed: ", trade.ResultRetcode(), " - ", trade.ResultRetcodeDescription());
   }
}

//+------------------------------------------------------------------+
//| Execute Sell Order                                                 |
//+------------------------------------------------------------------+
void ExecuteSellOrder()
{
   double ask = symbolInfo.Ask();
   double bid = symbolInfo.Bid();
   
   //--- Calculate stop loss and take profit in price
   double slPrice = bid + PipsToPrice(StopLoss_Pips);
   double tp1Price = bid - PipsToPrice(TP1_Pips);
   
   //--- Calculate lot size based on risk
   double lotSize = CalculateLotSize(StopLoss_Pips);
   
   //--- Normalize prices
   slPrice = NormalizeDouble(slPrice, digits);
   tp1Price = NormalizeDouble(tp1Price, digits);
   
   //--- Execute order
   if(trade.Sell(lotSize, Symbol(), bid, slPrice, tp1Price, "MACD+EMA Death Cross"))
   {
      Print("SELL order executed: Lot=", lotSize, " SL=", slPrice, " TP=", tp1Price);
   }
   else
   {
      Print("SELL order failed: ", trade.ResultRetcode(), " - ", trade.ResultRetcodeDescription());
   }
}

//+------------------------------------------------------------------+
//| Calculate lot size based on risk percentage                        |
//+------------------------------------------------------------------+
double CalculateLotSize(double slPips)
{
   double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskAmount = accountBalance * (RiskPercent / 100.0);
   
   //--- Get tick value
   double tickValue = symbolInfo.TickValue();
   double tickSize = symbolInfo.TickSize();
   
   //--- Calculate pip value
   double pipValue = (tickValue / tickSize) * pointValue * 10;  // For 5-digit brokers
   
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
   //--- For 5-digit brokers (EURUSD, etc.)
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
   MqlDateTime dt;
   TimeCurrent(dt);
   int currentHour = dt.hour;
   
   //--- Check London Kill Zone
   if(EnableLondonKZ)
   {
      if(currentHour >= LondonKZ_StartHour && currentHour < LondonKZ_EndHour)
         return true;
   }
   
   //--- Check NY Kill Zone
   if(EnableNYKZ)
   {
      if(currentHour >= NYKZ_StartHour && currentHour < NYKZ_EndHour)
         return true;
   }
   
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
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(positionInfo.SelectByIndex(i))
      {
         if(positionInfo.Symbol() != Symbol() || positionInfo.Magic() != magicNumber)
            continue;
         
         //--- Check for move to breakeven after TP1
         if(MoveToBreakevenAfterTP1)
         {
            double entryPrice = positionInfo.PriceOpen();
            double currentSL = positionInfo.StopLoss();
            double currentPrice = positionInfo.PriceCurrent();
            
            //--- For buy positions
            if(positionInfo.PositionType() == POSITION_TYPE_BUY)
            {
               double tp1Level = entryPrice + PipsToPrice(TP1_Pips);
               
               //--- If price has reached TP1 and SL is not at breakeven yet
               if(currentPrice >= tp1Level && currentSL < entryPrice)
               {
                  double newSL = NormalizeDouble(entryPrice, digits);
                  if(trade.PositionModify(positionInfo.Ticket(), newSL, positionInfo.TakeProfit()))
                  {
                     Print("BUY position moved to breakeven");
                  }
               }
            }
            //--- For sell positions
            else if(positionInfo.PositionType() == POSITION_TYPE_SELL)
            {
               double tp1Level = entryPrice - PipsToPrice(TP1_Pips);
               
               //--- If price has reached TP1 and SL is not at breakeven yet
               if(currentPrice <= tp1Level && currentSL > entryPrice)
               {
                  double newSL = NormalizeDouble(entryPrice, digits);
                  if(trade.PositionModify(positionInfo.Ticket(), newSL, positionInfo.TakeProfit()))
                  {
                     Print("SELL position moved to breakeven");
                  }
               }
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Draw EMA lines on chart                                            |
//+------------------------------------------------------------------+
void DrawEmaLines()
{
   //--- We'll draw indicator objects for visual reference
   //--- This is optional - you can also just use the built-in MA indicator
   
   string prefix = "EMA_";
   
   //--- Create horizontal lines at current EMA values for reference
   double emaM = emaBufferMom[0];
   double emaF = emaBufferFast[0];
   double emaS = emaBufferSlow[0];
   double emaD = emaBufferDir[0];
   
   //--- Note: For proper EMA lines on chart, it's better to add the 
   //--- Moving Average indicators directly to the chart in MT5
   //--- This function is just for reference points
}

//+------------------------------------------------------------------+
//| ChartEvent handler for additional functionality                    |
//+------------------------------------------------------------------+
void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
{
   //--- Handle chart events if needed
}
//+------------------------------------------------------------------+
