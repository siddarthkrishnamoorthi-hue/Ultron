//+------------------------------------------------------------------+
//|                                                       Ultron.mq5 |
//|                        Enterprise ICT/SMC Expert Advisor v2.0.0 |
//|                                   Built for Institutional Trading|
//+------------------------------------------------------------------+
#property copyright "Ultron EA - Enterprise Grade"
#property link      "https://github.com/siddarthkrishnamoorthi-hue/Ultron"
#property version   "2.00"
#property description "Institutional ICT/SMC EA - EUR/USD & XAU/USD"
#property description "Lightweight | Fast Execution | Free MT5 Calendar API"
#property strict

//+------------------------------------------------------------------+
//| INPUT PARAMETERS                                                  |
//+------------------------------------------------------------------+
input group "=== GENERAL SETTINGS ==="
input string   SymbolPrefix        = "";              // Symbol Prefix (e.g., "")
input string   SymbolSuffix        = "";              // Symbol Suffix (e.g., ".a", "m")
input bool     TradeEURUSD         = true;            // Trade EUR/USD
input bool     TradeXAUUSD         = true;            // Trade XAU/USD (Gold)
input int      MagicNumber         = 202511;          // Magic Number (Unique ID)

input group "=== RISK MANAGEMENT ==="
input double   RiskPercent         = 1.0;             // Risk Per Trade (%)
input double   MaxLots             = 2.0;             // Maximum Lot Size
input int      MaxDailyTrades      = 20;              // Max Trades Per Day (0=Unlimited)
input double   MaxDailyLoss        = 5.0;             // Max Daily Loss (%)
input bool     MoveToBreakeven     = true;            // Move SL to Breakeven
input double   BreakevenTrigger    = 1.0;             // BE Trigger (RR Ratio)
input bool     UseTrailingStop     = true;            // Enable Trailing Stop
input int      TrailDistance       = 15;              // Trail Distance (pips)
input bool     UsePartialTP        = true;            // Enable Partial Take Profit
input double   PartialTPPercent    = 50.0;            // Close % at First TP
input double   PartialTPRatio      = 2.0;             // First TP RR Ratio

input group "=== ICT/SMC CORE ==="
input int      SwingLookback       = 10;              // Swing Point Lookback
input int      MinGapPips_EU       = 5;               // Min FVG Gap EUR/USD (pips)
input int      MinGapPips_XAU      = 100;             // Min FVG Gap XAU/USD (pips)
input int      OB_Expiry           = 500;             // Order Block Expiry (bars)
input int      FVG_Expiry          = 300;             // FVG Expiry (bars)
input int      LiquidityTolerance  = 3;               // Equal Highs/Lows Tolerance (pips)

input group "=== TRADING SESSIONS (EST) ==="
input bool     TradeLondon         = true;            // London Killzone (02:00-05:00)
input bool     TradeNY_AM          = true;            // NY AM Silver Bullet (10:00-11:00)
input bool     TradeNY_PM          = true;            // NY PM Silver Bullet (14:00-15:00)

input group "=== ADVANCED FILTERS ==="
input bool     UseNewsFilter       = true;            // Enable News Filter (FREE MT5 Calendar)
input int      NewsAvoidMin        = 30;              // Avoid News (minutes before/after)
input ENUM_CALENDAR_EVENT_IMPORTANCE MinNewsImpact = CALENDAR_IMPORTANCE_HIGH; // Min News Impact
input bool     UseSMT              = false;           // Enable SMT Divergence
input bool     UseCorrelation      = false;           // Enable Correlation Filter
input double   MinCorrelation      = 0.7;             // Min Correlation Threshold
input bool     UseHTF_Bias         = true;            // Enable Multi-Timeframe Bias
input ENUM_TIMEFRAMES HTF_Period   = PERIOD_H4;       // Higher Timeframe Period

input group "=== TAKE PROFIT / STOP LOSS ==="
input double   MinRR               = 2.0;             // Minimum Risk:Reward Ratio
input double   TargetRR            = 3.0;             // Target Risk:Reward Ratio
input int      SL_Buffer_EU        = 5;               // SL Buffer EUR/USD (pips)
input int      SL_Buffer_XAU       = 20;              // SL Buffer XAU/USD (pips)

input group "=== VISUAL & DEBUG ==="
input bool     DrawOBs             = false;           // Draw Order Blocks
input bool     DrawFVGs            = false;           // Draw Fair Value Gaps
input bool     DrawLiquidity       = false;           // Draw Liquidity Levels
input bool     VerboseLogging      = false;           // Verbose Debug Logs

//+------------------------------------------------------------------+
//| CORE DATA STRUCTURES                                              |
//+------------------------------------------------------------------+
enum TREND_STATE {
   TREND_BULLISH,
   TREND_BEARISH,
   TREND_NEUTRAL
};

struct SwingPoint {
   datetime time;
   double   price;
   bool     isHigh;
   int      barIndex;
};

struct OrderBlock {
   datetime timeStart;
   datetime timeEnd;
   double   high;
   double   low;
   bool     isBullish;
   bool     mitigated;
   int      creationBar;
};

struct FairValueGap {
   datetime timeStart;
   datetime timeEnd;
   double   upperBound;
   double   lowerBound;
   bool     isBullish;
   bool     mitigated;
   int      creationBar;
};

struct LiquidityLevel {
   double   price;
   datetime time;
   bool     isHigh;
   bool     swept;
   int      touchCount;
};

struct PositionTracker {
   ulong    ticket;
   bool     partialClosed;
   bool     trailingActive;
   double   highestPrice;
   double   lowestPrice;
};

//+------------------------------------------------------------------+
//| GLOBAL VARIABLES                                                  |
//+------------------------------------------------------------------+
string g_SymbolEURUSD = "";
string g_SymbolXAUUSD = "";
int    g_TradesToday  = 0;
double g_DailyPnL     = 0.0;
datetime g_LastBarTime = 0;
datetime g_DayStart    = 0;

SwingPoint     g_Swings[];
OrderBlock     g_OrderBlocks[];
FairValueGap   g_FVGs[];
LiquidityLevel g_Liquidity[];
PositionTracker g_Positions[];

TREND_STATE g_TrendEURUSD = TREND_NEUTRAL;
TREND_STATE g_TrendXAUUSD = TREND_NEUTRAL;

TREND_STATE g_HTF_TrendEURUSD = TREND_NEUTRAL;
TREND_STATE g_HTF_TrendXAUUSD = TREND_NEUTRAL;

datetime g_NewsEvents[] = {};

//+------------------------------------------------------------------+
//| EXPERT INITIALIZATION                                             |
//+------------------------------------------------------------------+
int OnInit() {
   Print("═══════════════════════════════════════════════════════════");
   Print("   ULTRON EA v2.0.0 - MAXIMUM POTENTIAL MODE");
   Print("═══════════════════════════════════════════════════════════");
   
   g_SymbolEURUSD = GetBrokerSymbol("EURUSD");
   g_SymbolXAUUSD = GetBrokerSymbol("XAUUSD");
   
   if(TradeEURUSD && g_SymbolEURUSD == "") {
      Alert("⚠ EUR/USD symbol not found! Check broker symbol format.");
      return INIT_FAILED;
   }
   
   if(TradeXAUUSD && g_SymbolXAUUSD == "") {
      Alert("⚠ XAU/USD symbol not found! Check broker symbol format.");
      return INIT_FAILED;
   }
   
   ArrayResize(g_Swings, 0);
   ArrayResize(g_OrderBlocks, 0);
   ArrayResize(g_FVGs, 0);
   ArrayResize(g_Liquidity, 0);
   ArrayResize(g_Positions, 0);
   
   g_DayStart = GetDayStart();
   ResetDailyStats();
   
   Print("✓ EUR/USD Symbol: ", g_SymbolEURUSD == "" ? "DISABLED" : g_SymbolEURUSD);
   Print("✓ XAU/USD Symbol: ", g_SymbolXAUUSD == "" ? "DISABLED" : g_SymbolXAUUSD);
   Print("✓ Risk Per Trade: ", RiskPercent, "%");
   Print("✓ Max Daily Trades: ", MaxDailyTrades == 0 ? "UNLIMITED" : IntegerToString(MaxDailyTrades));
   Print("✓ Trailing Stop: ", UseTrailingStop, " | Partial TP: ", UsePartialTP);
   Print("✓ MTF Bias: ", UseHTF_Bias, " (", EnumToString(HTF_Period), ")");
   Print("✓ Sessions: London=", TradeLondon, " | NY_AM=", TradeNY_AM, " | NY_PM=", TradeNY_PM);
   Print("✓ Filters: News=", UseNewsFilter, " | SMT=", UseSMT, " | Correlation=", UseCorrelation);
   Print("✓ MODE: LIGHTWEIGHT & FAST EXECUTION");
   Print("═══════════════════════════════════════════════════════════");
   
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| EXPERT DEINITIALIZATION                                           |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
   DeleteAllChartObjects();
   Print("Ultron EA stopped. Reason: ", reason);
}

//+------------------------------------------------------------------+
//| ONTICK - MAIN EXECUTION ENGINE                                    |
//+------------------------------------------------------------------+
void OnTick() {
   if(IsNewBar()) {
      OnNewBar();
   }
   
   ManageOpenPositions();
}

//+------------------------------------------------------------------+
//| ON NEW BAR - STRUCTURE DETECTION & SIGNAL GENERATION             |
//+------------------------------------------------------------------+
void OnNewBar() {
   CheckDailyReset();
   CleanExpiredStructures();
   
   if(TradeEURUSD && g_SymbolEURUSD != "") {
      ProcessSymbol(g_SymbolEURUSD, MinGapPips_EU, SL_Buffer_EU);
   }
   
   if(TradeXAUUSD && g_SymbolXAUUSD != "") {
      ProcessSymbol(g_SymbolXAUUSD, MinGapPips_XAU, SL_Buffer_XAU);
   }
}

//+------------------------------------------------------------------+
//| PROCESS SYMBOL - MAIN TRADING LOGIC                              |
//+------------------------------------------------------------------+
void ProcessSymbol(string symbol, int minGapPips, int slBuffer) {
   if(!CanTrade(symbol)) return;
   
   UpdateMarketStructure(symbol);
   DetectOrderBlocks(symbol);
   DetectFairValueGaps(symbol, minGapPips);
   DetectLiquidityLevels(symbol);
   
   if(!IsActiveSession()) return;
   if(UseNewsFilter && IsNewsPending(NewsAvoidMin)) return;
   
   int signal = GenerateSignal(symbol, slBuffer);
   
   if(signal == 1) {
      ExecuteBuy(symbol, slBuffer);
   } else if(signal == -1) {
      ExecuteSell(symbol, slBuffer);
   }
}

//+------------------------------------------------------------------+
//| MARKET STRUCTURE - SWING DETECTION & TREND                       |
//+------------------------------------------------------------------+
void UpdateMarketStructure(string symbol) {
   DetectSwingPoints(symbol);
   
   TREND_STATE trend = DetermineTrend(symbol);
   
   if(symbol == g_SymbolEURUSD) {
      g_TrendEURUSD = trend;
      if(UseHTF_Bias) {
         g_HTF_TrendEURUSD = DetermineHTFTrend(symbol);
      }
   } else if(symbol == g_SymbolXAUUSD) {
      g_TrendXAUUSD = trend;
      if(UseHTF_Bias) {
         g_HTF_TrendXAUUSD = DetermineHTFTrend(symbol);
      }
   }
}

void DetectSwingPoints(string symbol) {
   int lookback = SwingLookback;
   
   for(int i = lookback; i < Bars(symbol, PERIOD_CURRENT) - lookback; i++) {
      double high[], low[];
      ArraySetAsSeries(high, true);
      ArraySetAsSeries(low, true);
      
      if(CopyHigh(symbol, PERIOD_CURRENT, 0, lookback * 2 + 1, high) <= 0) return;
      if(CopyLow(symbol, PERIOD_CURRENT, 0, lookback * 2 + 1, low) <= 0) return;
      
      bool isSwingHigh = true;
      bool isSwingLow = true;
      
      for(int j = 1; j <= lookback; j++) {
         if(high[i] <= high[i - j] || high[i] <= high[i + j]) isSwingHigh = false;
         if(low[i] >= low[i - j] || low[i] >= low[i + j]) isSwingLow = false;
      }
      
      if(isSwingHigh) {
         AddSwingPoint(symbol, i, high[i], true);
      }
      
      if(isSwingLow) {
         AddSwingPoint(symbol, i, low[i], false);
      }
   }
   
   LimitArraySize(g_Swings, 15);
}

void AddSwingPoint(string symbol, int barIndex, double price, bool isHigh) {
   int size = ArraySize(g_Swings);
   
   for(int i = 0; i < size; i++) {
      if(g_Swings[i].barIndex == barIndex && g_Swings[i].isHigh == isHigh) {
         return;
      }
   }
   
   ArrayResize(g_Swings, size + 1);
   g_Swings[size].time = iTime(symbol, PERIOD_CURRENT, barIndex);
   g_Swings[size].price = price;
   g_Swings[size].isHigh = isHigh;
   g_Swings[size].barIndex = barIndex;
}

TREND_STATE DetermineTrend(string symbol) {
   if(ArraySize(g_Swings) < 4) return TREND_NEUTRAL;
   
   int higherHighs = 0;
   int lowerLows = 0;
   
   for(int i = 1; i < ArraySize(g_Swings); i++) {
      if(g_Swings[i].isHigh && g_Swings[i - 1].isHigh) {
         if(g_Swings[i].price > g_Swings[i - 1].price) higherHighs++;
      }
      
      if(!g_Swings[i].isHigh && !g_Swings[i - 1].isHigh) {
         if(g_Swings[i].price < g_Swings[i - 1].price) lowerLows++;
      }
   }
   
   if(higherHighs > lowerLows) return TREND_BULLISH;
   if(lowerLows > higherHighs) return TREND_BEARISH;
   
   return TREND_NEUTRAL;
}

TREND_STATE DetermineHTFTrend(string symbol) {
   double ma20[], ma50[];
   ArraySetAsSeries(ma20, true);
   ArraySetAsSeries(ma50, true);
   
   int ma20Handle = iMA(symbol, HTF_Period, 20, 0, MODE_EMA, PRICE_CLOSE);
   int ma50Handle = iMA(symbol, HTF_Period, 50, 0, MODE_EMA, PRICE_CLOSE);
   
   if(ma20Handle == INVALID_HANDLE || ma50Handle == INVALID_HANDLE) {
      return TREND_NEUTRAL;
   }
   
   if(CopyBuffer(ma20Handle, 0, 0, 3, ma20) <= 0 || CopyBuffer(ma50Handle, 0, 0, 3, ma50) <= 0) {
      IndicatorRelease(ma20Handle);
      IndicatorRelease(ma50Handle);
      return TREND_NEUTRAL;
   }
   
   bool bullish = ma20[0] > ma50[0] && ma20[1] > ma50[1];
   bool bearish = ma20[0] < ma50[0] && ma20[1] < ma50[1];
   
   IndicatorRelease(ma20Handle);
   IndicatorRelease(ma50Handle);
   
   if(bullish) return TREND_BULLISH;
   if(bearish) return TREND_BEARISH;
   return TREND_NEUTRAL;
}

//+------------------------------------------------------------------+
//| ORDER BLOCK DETECTION                                             |
//+------------------------------------------------------------------+
void DetectOrderBlocks(string symbol) {
   int bars = Bars(symbol, PERIOD_CURRENT);
   if(bars < 50) return;
   
   double open[], close[], high[], low[];
   ArraySetAsSeries(open, true);
   ArraySetAsSeries(close, true);
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);
   
   if(CopyOpen(symbol, PERIOD_CURRENT, 0, 50, open) <= 0) return;
   if(CopyClose(symbol, PERIOD_CURRENT, 0, 50, close) <= 0) return;
   if(CopyHigh(symbol, PERIOD_CURRENT, 0, 50, high) <= 0) return;
   if(CopyLow(symbol, PERIOD_CURRENT, 0, 50, low) <= 0) return;
   
   for(int i = 3; i < 20; i++) {
      bool isBearishCandle = close[i] < open[i];
      bool isBullishCandle = close[i] > open[i];
      
      bool bullishBOS = close[i - 1] > high[i] && isBearishCandle;
      bool bearishBOS = close[i - 1] < low[i] && isBullishCandle;
      
      if(bullishBOS) {
         AddOrderBlock(symbol, i, high[i], low[i], true);
      }
      
      if(bearishBOS) {
         AddOrderBlock(symbol, i, high[i], low[i], false);
      }
   }
   
   LimitArraySize(g_OrderBlocks, 20);
}

void AddOrderBlock(string symbol, int barIndex, double high, double low, bool isBullish) {
   int size = ArraySize(g_OrderBlocks);
   ArrayResize(g_OrderBlocks, size + 1);
   
   g_OrderBlocks[size].timeStart = iTime(symbol, PERIOD_CURRENT, barIndex);
   g_OrderBlocks[size].timeEnd = TimeCurrent() + OB_Expiry * PeriodSeconds(PERIOD_CURRENT);
   g_OrderBlocks[size].high = high;
   g_OrderBlocks[size].low = low;
   g_OrderBlocks[size].isBullish = isBullish;
   g_OrderBlocks[size].mitigated = false;
   g_OrderBlocks[size].creationBar = barIndex;
   
   if(DrawOBs) {
      DrawOrderBlock(size);
   }
}

void DrawOrderBlock(int index) {
   string name = "OB_" + IntegerToString(index) + "_" + IntegerToString(GetTickCount());
   color obColor = g_OrderBlocks[index].isBullish ? clrDodgerBlue : clrCrimson;
   
   ObjectCreate(0, name, OBJ_RECTANGLE, 0, g_OrderBlocks[index].timeStart, g_OrderBlocks[index].high, g_OrderBlocks[index].timeEnd, g_OrderBlocks[index].low);
   ObjectSetInteger(0, name, OBJPROP_COLOR, obColor);
   ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, name, OBJPROP_BACK, true);
   ObjectSetInteger(0, name, OBJPROP_FILL, true);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
}

//+------------------------------------------------------------------+
//| FAIR VALUE GAP DETECTION                                          |
//+------------------------------------------------------------------+
void DetectFairValueGaps(string symbol, int minGapPips) {
   double high[], low[];
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);
   
   if(CopyHigh(symbol, PERIOD_CURRENT, 0, 50, high) <= 0) return;
   if(CopyLow(symbol, PERIOD_CURRENT, 0, 50, low) <= 0) return;
   
   double minGap = minGapPips * SymbolInfoDouble(symbol, SYMBOL_POINT) * 10;
   
   for(int i = 2; i < 20; i++) {
      bool bullishFVG = low[i - 2] > high[i] && (low[i - 2] - high[i]) >= minGap;
      bool bearishFVG = high[i - 2] < low[i] && (low[i] - high[i - 2]) >= minGap;
      
      if(bullishFVG) {
         AddFVG(symbol, i, low[i - 2], high[i], true);
      }
      
      if(bearishFVG) {
         AddFVG(symbol, i, low[i], high[i - 2], false);
      }
   }
   
   LimitArraySize(g_FVGs, 15);
}

void AddFVG(string symbol, int barIndex, double upper, double lower, bool isBullish) {
   int size = ArraySize(g_FVGs);
   ArrayResize(g_FVGs, size + 1);
   
   g_FVGs[size].timeStart = iTime(symbol, PERIOD_CURRENT, barIndex);
   g_FVGs[size].timeEnd = TimeCurrent() + FVG_Expiry * PeriodSeconds(PERIOD_CURRENT);
   g_FVGs[size].upperBound = upper;
   g_FVGs[size].lowerBound = lower;
   g_FVGs[size].isBullish = isBullish;
   g_FVGs[size].mitigated = false;
   g_FVGs[size].creationBar = barIndex;
   
   if(DrawFVGs) {
      DrawFVG(size);
   }
}

void DrawFVG(int index) {
   string name = "FVG_" + IntegerToString(index) + "_" + IntegerToString(GetTickCount());
   color fvgColor = g_FVGs[index].isBullish ? clrLimeGreen : clrOrangeRed;
   
   ObjectCreate(0, name, OBJ_RECTANGLE, 0, g_FVGs[index].timeStart, g_FVGs[index].upperBound, g_FVGs[index].timeEnd, g_FVGs[index].lowerBound);
   ObjectSetInteger(0, name, OBJPROP_COLOR, fvgColor);
   ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_DOT);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, name, OBJPROP_BACK, true);
   ObjectSetInteger(0, name, OBJPROP_FILL, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
}

//+------------------------------------------------------------------+
//| LIQUIDITY LEVEL DETECTION                                         |
//+------------------------------------------------------------------+
void DetectLiquidityLevels(string symbol) {
   if(ArraySize(g_Swings) < 3) return;
   
   double tolerance = LiquidityTolerance * SymbolInfoDouble(symbol, SYMBOL_POINT) * 10;
   
   for(int i = 0; i < ArraySize(g_Swings) - 1; i++) {
      for(int j = i + 1; j < ArraySize(g_Swings); j++) {
         if(g_Swings[i].isHigh == g_Swings[j].isHigh) {
            if(MathAbs(g_Swings[i].price - g_Swings[j].price) <= tolerance) {
               AddLiquidityLevel(g_Swings[i].price, g_Swings[i].time, g_Swings[i].isHigh);
               break;
            }
         }
      }
   }
   
   LimitArraySize(g_Liquidity, 10);
}

void AddLiquidityLevel(double price, datetime time, bool isHigh) {
   int size = ArraySize(g_Liquidity);
   
   for(int i = 0; i < size; i++) {
      if(MathAbs(g_Liquidity[i].price - price) < SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 5) {
         g_Liquidity[i].touchCount++;
         return;
      }
   }
   
   ArrayResize(g_Liquidity, size + 1);
   g_Liquidity[size].price = price;
   g_Liquidity[size].time = time;
   g_Liquidity[size].isHigh = isHigh;
   g_Liquidity[size].swept = false;
   g_Liquidity[size].touchCount = 1;
   
   if(DrawLiquidity) {
      DrawLiquidityLine(size);
   }
}

void DrawLiquidityLine(int index) {
   string name = "LIQ_" + IntegerToString(index) + "_" + IntegerToString(GetTickCount());
   color liqColor = g_Liquidity[index].isHigh ? clrYellow : clrCyan;
   
   ObjectCreate(0, name, OBJ_HLINE, 0, 0, g_Liquidity[index].price);
   ObjectSetInteger(0, name, OBJPROP_COLOR, liqColor);
   ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_DASHDOT);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, 2);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
}

//+------------------------------------------------------------------+
//| SIGNAL GENERATION - COMPLETE ENTRY LOGIC                         |
//+------------------------------------------------------------------+
int GenerateSignal(string symbol, int slBuffer) {
   if(HasOpenPosition(symbol)) return 0;
   
   double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
   
   TREND_STATE trend = (symbol == g_SymbolEURUSD) ? g_TrendEURUSD : g_TrendXAUUSD;
   TREND_STATE htfTrend = (symbol == g_SymbolEURUSD) ? g_HTF_TrendEURUSD : g_HTF_TrendXAUUSD;
   
   bool bullishStructure = (trend == TREND_BULLISH);
   bool bearishStructure = (trend == TREND_BEARISH);
   
   if(UseHTF_Bias) {
      if(htfTrend == TREND_BEARISH && bullishStructure) {
         if(VerboseLogging) Print("[FILTER] HTF bearish blocks bullish entry");
         return 0;
      }
      if(htfTrend == TREND_BULLISH && bearishStructure) {
         if(VerboseLogging) Print("[FILTER] HTF bullish blocks bearish entry");
         return 0;
      }
   }
   
   bool bullishOBMitigation = CheckOBMitigation(symbol, true, bid);
   bool bearishOBMitigation = CheckOBMitigation(symbol, false, ask);
   
   if(UseSMT && !CheckSMTDivergence(symbol, bullishStructure)) return 0;
   if(UseCorrelation && !CheckCorrelation(symbol)) return 0;
   
   if(bullishStructure && bullishOBMitigation) {
      if(VerboseLogging) Print("[SIGNAL] Bullish entry conditions met for ", symbol);
      return 1;
   }
   
   if(bearishStructure && bearishOBMitigation) {
      if(VerboseLogging) Print("[SIGNAL] Bearish entry conditions met for ", symbol);
      return -1;
   }
   
   return 0;
}

bool CheckOBMitigation(string symbol, bool isBullish, double price) {
   for(int i = 0; i < ArraySize(g_OrderBlocks); i++) {
      if(g_OrderBlocks[i].isBullish != isBullish) continue;
      if(g_OrderBlocks[i].mitigated) continue;
      
      if(price >= g_OrderBlocks[i].low && price <= g_OrderBlocks[i].high) {
         return true;
      }
   }
   
   return false;
}

bool CheckSMTDivergence(string symbol, bool expectedBullish) {
   string correlatedSymbol = "";
   
   if(symbol == g_SymbolEURUSD) {
      correlatedSymbol = GetBrokerSymbol("GBPUSD");
   } else if(symbol == g_SymbolXAUUSD) {
      correlatedSymbol = GetBrokerSymbol("XAGUSD");
   }
   
   if(correlatedSymbol == "") return true;
   
   double mainHigh = iHigh(symbol, PERIOD_H1, 1);
   double corrHigh = iHigh(correlatedSymbol, PERIOD_H1, 1);
   
   if(expectedBullish && mainHigh > iHigh(symbol, PERIOD_H1, 2) && corrHigh < iHigh(correlatedSymbol, PERIOD_H1, 2)) {
      return true;
   }
   
   return true;
}

bool CheckCorrelation(string symbol) {
   string dxySymbol = GetBrokerSymbol("DXY");
   if(dxySymbol == "") return true;
   
   double correlation = CalculateCorrelation(symbol, dxySymbol, 50);
   
   if(MathAbs(correlation) < MinCorrelation) {
      if(VerboseLogging) Print("[FILTER] Correlation too weak: ", correlation);
      return false;
   }
   
   return true;
}

double CalculateCorrelation(string symbol1, string symbol2, int period) {
   double close1[], close2[];
   ArraySetAsSeries(close1, true);
   ArraySetAsSeries(close2, true);
   
   if(CopyClose(symbol1, PERIOD_H1, 0, period, close1) <= 0) return 0.0;
   if(CopyClose(symbol2, PERIOD_H1, 0, period, close2) <= 0) return 0.0;
   
   double mean1 = 0, mean2 = 0;
   for(int i = 0; i < period; i++) {
      mean1 += close1[i];
      mean2 += close2[i];
   }
   mean1 /= period;
   mean2 /= period;
   
   double numerator = 0, denom1 = 0, denom2 = 0;
   for(int i = 0; i < period; i++) {
      double diff1 = close1[i] - mean1;
      double diff2 = close2[i] - mean2;
      numerator += diff1 * diff2;
      denom1 += diff1 * diff1;
      denom2 += diff2 * diff2;
   }
   
   if(denom1 == 0 || denom2 == 0) return 0.0;
   
   return numerator / MathSqrt(denom1 * denom2);
}

//+------------------------------------------------------------------+
//| ORDER EXECUTION                                                   |
//+------------------------------------------------------------------+
void ExecuteBuy(string symbol, int slBuffer) {
   if(MaxDailyTrades > 0 && g_TradesToday >= MaxDailyTrades) {
      if(VerboseLogging) Print("[FILTER] Max daily trades reached");
      return;
   }
   
   if(g_DailyPnL <= -(MaxDailyLoss * AccountInfoDouble(ACCOUNT_BALANCE) / 100)) {
      Alert("⛔ Max daily loss reached. Trading halted.");
      return;
   }
   
   double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
   double stopLoss = CalculateSL(symbol, true, slBuffer);
   double takeProfit = CalculateTP(symbol, true, ask, stopLoss);
   double lotSize = CalculateLotSize(symbol, ask, stopLoss);
   
   if(lotSize < SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN)) {
      Print("[ERROR] Lot size too small: ", lotSize);
      return;
   }
   
   MqlTradeRequest request = {};
   MqlTradeResult result = {};
   
   request.action = TRADE_ACTION_DEAL;
   request.symbol = symbol;
   request.volume = lotSize;
   request.type = ORDER_TYPE_BUY;
   request.price = ask;
   request.sl = stopLoss;
   request.tp = takeProfit;
   request.deviation = 10;
   request.magic = MagicNumber;
   request.comment = "Ultron_Buy";
   
   if(OrderSend(request, result)) {
      Print("✓ BUY ORDER: ", symbol, " | Lot: ", lotSize, " | SL: ", stopLoss, " | TP: ", takeProfit);
      g_TradesToday++;
      
      if(UsePartialTP || UseTrailingStop) {
         AddPositionTracker(result.order, false);
      }
   } else {
      Print("✗ BUY FAILED: ", symbol, " | Error: ", GetLastError());
   }
}

void ExecuteSell(string symbol, int slBuffer) {
   if(MaxDailyTrades > 0 && g_TradesToday >= MaxDailyTrades) {
      if(VerboseLogging) Print("[FILTER] Max daily trades reached");
      return;
   }
   
   if(g_DailyPnL <= -(MaxDailyLoss * AccountInfoDouble(ACCOUNT_BALANCE) / 100)) {
      Alert("⛔ Max daily loss reached. Trading halted.");
      return;
   }
   
   double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
   double stopLoss = CalculateSL(symbol, false, slBuffer);
   double takeProfit = CalculateTP(symbol, false, bid, stopLoss);
   double lotSize = CalculateLotSize(symbol, bid, stopLoss);
   
   if(lotSize < SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN)) {
      Print("[ERROR] Lot size too small: ", lotSize);
      return;
   }
   
   MqlTradeRequest request = {};
   MqlTradeResult result = {};
   
   request.action = TRADE_ACTION_DEAL;
   request.symbol = symbol;
   request.volume = lotSize;
   request.type = ORDER_TYPE_SELL;
   request.price = bid;
   request.sl = stopLoss;
   request.tp = takeProfit;
   request.deviation = 10;
   request.magic = MagicNumber;
   request.comment = "Ultron_Sell";
   
   if(OrderSend(request, result)) {
      Print("✓ SELL ORDER: ", symbol, " | Lot: ", lotSize, " | SL: ", stopLoss, " | TP: ", takeProfit);
      g_TradesToday++;
      
      if(UsePartialTP || UseTrailingStop) {
         AddPositionTracker(result.order, false);
      }
   } else {
      Print("✗ SELL FAILED: ", symbol, " | Error: ", GetLastError());
   }
}

//+------------------------------------------------------------------+
//| POSITION MANAGEMENT                                               |
//+------------------------------------------------------------------+
void ManageOpenPositions() {
   for(int i = PositionsTotal() - 1; i >= 0; i--) {
      ulong ticket = PositionGetTicket(i);
      if(ticket <= 0) continue;
      
      if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
      
      string symbol = PositionGetString(POSITION_SYMBOL);
      double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      double currentPrice = PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY ? SymbolInfoDouble(symbol, SYMBOL_BID) : SymbolInfoDouble(symbol, SYMBOL_ASK);
      double sl = PositionGetDouble(POSITION_SL);
      double tp = PositionGetDouble(POSITION_TP);
      bool isBuy = PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY;
      
      int posIndex = GetPositionIndex(ticket);
      
      if(UsePartialTP && posIndex >= 0 && !g_Positions[posIndex].partialClosed) {
         HandlePartialTP(ticket, symbol, openPrice, currentPrice, sl, isBuy, posIndex);
      }
      
      if(UseTrailingStop && posIndex >= 0) {
         HandleTrailingStop(ticket, symbol, openPrice, currentPrice, sl, tp, isBuy, posIndex);
      }
      
      if(MoveToBreakeven && sl != openPrice && (!UsePartialTP || (posIndex >= 0 && g_Positions[posIndex].partialClosed))) {
         double slDistance = MathAbs(openPrice - sl);
         double currentProfit = isBuy ? (currentPrice - openPrice) : (openPrice - currentPrice);
         
         if(currentProfit >= slDistance * BreakevenTrigger) {
            MqlTradeRequest request = {};
            MqlTradeResult result = {};
            
            request.action = TRADE_ACTION_SLTP;
            request.position = ticket;
            request.symbol = symbol;
            request.sl = openPrice;
            request.tp = tp;
            
            if(OrderSend(request, result)) {
               Print("✓ Moved to breakeven: ", symbol, " | Ticket: ", ticket);
            }
         }
      }
   }
}

void HandlePartialTP(ulong ticket, string symbol, double openPrice, double currentPrice, double sl, bool isBuy, int posIndex) {
   double slDistance = MathAbs(openPrice - sl);
   double partialTPPrice = isBuy ? openPrice + slDistance * PartialTPRatio : openPrice - slDistance * PartialTPRatio;
   
   bool partialTPHit = isBuy ? currentPrice >= partialTPPrice : currentPrice <= partialTPPrice;
   
   if(partialTPHit) {
      double currentVolume = PositionGetDouble(POSITION_VOLUME);
      double closeVolume = NormalizeDouble(currentVolume * PartialTPPercent / 100.0, 2);
      
      double minLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
      if(closeVolume < minLot) closeVolume = minLot;
      
      if(closeVolume >= currentVolume) return;
      
      MqlTradeRequest request = {};
      MqlTradeResult result = {};
      
      request.action = TRADE_ACTION_DEAL;
      request.symbol = symbol;
      request.volume = closeVolume;
      request.type = isBuy ? ORDER_TYPE_SELL : ORDER_TYPE_BUY;
      request.price = currentPrice;
      request.position = ticket;
      request.deviation = 10;
      request.magic = MagicNumber;
      request.comment = "Ultron_PartialTP";
      
      if(OrderSend(request, result)) {
         Print("✓ PARTIAL TP: ", symbol, " | Closed: ", closeVolume, " lots at ", DoubleToString(currentPrice, (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS)));
         g_Positions[posIndex].partialClosed = true;
      }
   }
}

void HandleTrailingStop(ulong ticket, string symbol, double openPrice, double currentPrice, double sl, double tp, bool isBuy, int posIndex) {
   if(isBuy) {
      if(currentPrice > g_Positions[posIndex].highestPrice || g_Positions[posIndex].highestPrice == 0) {
         g_Positions[posIndex].highestPrice = currentPrice;
      }
      
      double trailDistance = TrailDistance * SymbolInfoDouble(symbol, SYMBOL_POINT) * 10;
      double newSL = g_Positions[posIndex].highestPrice - trailDistance;
      
      if(newSL > sl && newSL < currentPrice) {
         MqlTradeRequest request = {};
         MqlTradeResult result = {};
         
         request.action = TRADE_ACTION_SLTP;
         request.position = ticket;
         request.symbol = symbol;
         request.sl = NormalizeDouble(newSL, (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS));
         request.tp = tp;
         
         if(OrderSend(request, result)) {
            Print("✓ TRAILING STOP: ", symbol, " | New SL: ", newSL);
            g_Positions[posIndex].trailingActive = true;
         }
      }
   } else {
      if(currentPrice < g_Positions[posIndex].lowestPrice || g_Positions[posIndex].lowestPrice == 0) {
         g_Positions[posIndex].lowestPrice = currentPrice;
      }
      
      double trailDistance = TrailDistance * SymbolInfoDouble(symbol, SYMBOL_POINT) * 10;
      double newSL = g_Positions[posIndex].lowestPrice + trailDistance;
      
      if(newSL < sl && newSL > currentPrice) {
         MqlTradeRequest request = {};
         MqlTradeResult result = {};
         
         request.action = TRADE_ACTION_SLTP;
         request.position = ticket;
         request.symbol = symbol;
         request.sl = NormalizeDouble(newSL, (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS));
         request.tp = tp;
         
         if(OrderSend(request, result)) {
            Print("✓ TRAILING STOP: ", symbol, " | New SL: ", newSL);
            g_Positions[posIndex].trailingActive = true;
         }
      }
   }
}

void AddPositionTracker(ulong ticket, bool partialClosed) {
   int size = ArraySize(g_Positions);
   ArrayResize(g_Positions, size + 1);
   
   g_Positions[size].ticket = ticket;
   g_Positions[size].partialClosed = partialClosed;
   g_Positions[size].trailingActive = false;
   g_Positions[size].highestPrice = 0;
   g_Positions[size].lowestPrice = 0;
}

int GetPositionIndex(ulong ticket) {
   for(int i = 0; i < ArraySize(g_Positions); i++) {
      if(g_Positions[i].ticket == ticket) {
         return i;
      }
   }
   return -1;
}

//+------------------------------------------------------------------+
//| RISK CALCULATIONS                                                 |
//+------------------------------------------------------------------+
double CalculateLotSize(string symbol, double entryPrice, double stopLoss) {
   double slDistance = MathAbs(entryPrice - stopLoss);
   if(slDistance == 0) return 0;
   
   double tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
   double riskAmount = AccountInfoDouble(ACCOUNT_BALANCE) * RiskPercent / 100.0;
   
   double lotSize = (riskAmount * tickSize) / (slDistance * tickValue);
   
   double minLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   double maxLot = MathMin(MaxLots, SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX));
   double lotStep = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
   
   lotSize = MathFloor(lotSize / lotStep) * lotStep;
   lotSize = MathMax(minLot, MathMin(lotSize, maxLot));
   
   if(!AccountInfoDouble(ACCOUNT_FREEMARGIN_CHECK, symbol, ORDER_TYPE_BUY, lotSize)) {
      Print("[ERROR] Insufficient margin for lot size: ", lotSize);
      return 0;
   }
   
   return lotSize;
}

double CalculateSL(string symbol, bool isBuy, int buffer) {
   double slPrice = 0;
   double bufferDistance = buffer * SymbolInfoDouble(symbol, SYMBOL_POINT) * 10;
   
   for(int i = 0; i < ArraySize(g_Swings); i++) {
      if(isBuy && !g_Swings[i].isHigh) {
         slPrice = g_Swings[i].price - bufferDistance;
         break;
      } else if(!isBuy && g_Swings[i].isHigh) {
         slPrice = g_Swings[i].price + bufferDistance;
         break;
      }
   }
   
   if(slPrice == 0) {
      double atr = GetATR(symbol, 14);
      slPrice = isBuy ? SymbolInfoDouble(symbol, SYMBOL_BID) - atr * 1.5 : SymbolInfoDouble(symbol, SYMBOL_ASK) + atr * 1.5;
   }
   
   return NormalizeDouble(slPrice, (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS));
}

double CalculateTP(string symbol, bool isBuy, double entryPrice, double stopLoss) {
   double slDistance = MathAbs(entryPrice - stopLoss);
   double tpDistance = slDistance * TargetRR;
   
   double tpPrice = isBuy ? entryPrice + tpDistance : entryPrice - tpDistance;
   
   for(int i = 0; i < ArraySize(g_OrderBlocks); i++) {
      if(g_OrderBlocks[i].isBullish != isBuy) {
         double obPrice = isBuy ? g_OrderBlocks[i].low : g_OrderBlocks[i].high;
         if((isBuy && obPrice > tpPrice) || (!isBuy && obPrice < tpPrice)) {
            tpPrice = obPrice;
         }
      }
   }
   
   return NormalizeDouble(tpPrice, (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS));
}

double GetATR(string symbol, int period) {
   double atr[];
   ArraySetAsSeries(atr, true);
   
   int handle = iATR(symbol, PERIOD_CURRENT, period);
   if(handle == INVALID_HANDLE) return 0;
   
   if(CopyBuffer(handle, 0, 0, 1, atr) <= 0) {
      IndicatorRelease(handle);
      return 0;
   }
   
   IndicatorRelease(handle);
   return atr[0];
}

//+------------------------------------------------------------------+
//| SESSION & NEWS FILTERS                                           |
//+------------------------------------------------------------------+
bool IsActiveSession() {
   datetime currentTime = TimeGMT() - 5 * 3600;
   MqlDateTime dt;
   TimeToStruct(currentTime, dt);
   
   int hour = dt.hour;
   
   if(TradeLondon && hour >= 2 && hour < 5) return true;
   if(TradeNY_AM && hour >= 10 && hour < 11) return true;
   if(TradeNY_PM && hour >= 14 && hour < 15) return true;
   
   return false;
}

bool IsNewsPending(int avoidMinutes) {
   datetime currentTime = TimeCurrent();
   datetime startTime = currentTime - avoidMinutes * 60;
   datetime endTime = currentTime + avoidMinutes * 60;
   
   MqlCalendarValue values[];
   
   if(CalendarValueHistory(values, startTime, endTime, NULL, NULL)) {
      for(int i = 0; i < ArraySize(values); i++) {
         MqlCalendarEvent event;
         if(CalendarEventById(values[i].event_id, event)) {
            if(event.importance >= MinNewsImpact) {
               string currencies[];
               StringSplit(event.currency, ',', currencies);
               
               for(int j = 0; j < ArraySize(currencies); j++) {
                  string curr = currencies[j];
                  if(curr == "USD" || curr == "EUR" || curr == "GBP") {
                     int minutesUntil = (int)((values[i].time - currentTime) / 60);
                     if(VerboseLogging) {
                        Print("[FILTER] High-impact ", event.currency, " news in ", minutesUntil, " minutes: ", event.name);
                     }
                     return true;
                  }
               }
            }
         }
      }
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| UTILITY FUNCTIONS                                                 |
//+------------------------------------------------------------------+
bool IsNewBar() {
   datetime currentBarTime = iTime(_Symbol, PERIOD_CURRENT, 0);
   
   if(currentBarTime != g_LastBarTime) {
      g_LastBarTime = currentBarTime;
      return true;
   }
   
   return false;
}

bool HasOpenPosition(string symbol) {
   for(int i = 0; i < PositionsTotal(); i++) {
      if(PositionGetSymbol(i) == symbol && PositionGetInteger(POSITION_MAGIC) == MagicNumber) {
         return true;
      }
   }
   
   return false;
}

bool CanTrade(string symbol) {
   if(MaxDailyTrades > 0 && g_TradesToday >= MaxDailyTrades) return false;
   if(g_DailyPnL <= -(MaxDailyLoss * AccountInfoDouble(ACCOUNT_BALANCE) / 100)) return false;
   if(HasOpenPosition(symbol)) return false;
   
   return true;
}

datetime GetDayStart() {
   MqlDateTime dt;
   TimeCurrent(dt);
   dt.hour = 0;
   dt.min = 0;
   dt.sec = 0;
   return StructToTime(dt);
}

void CheckDailyReset() {
   datetime currentDayStart = GetDayStart();
   
   if(currentDayStart != g_DayStart) {
      ResetDailyStats();
      g_DayStart = currentDayStart;
   }
}

void ResetDailyStats() {
   g_TradesToday = 0;
   g_DailyPnL = 0.0;
   
   if(VerboseLogging) Print("[RESET] Daily stats reset");
}

void CleanExpiredStructures() {
   datetime currentTime = TimeCurrent();
   
   for(int i = ArraySize(g_OrderBlocks) - 1; i >= 0; i--) {
      if(currentTime > g_OrderBlocks[i].timeEnd) {
         ArrayRemove(g_OrderBlocks, i, 1);
      }
   }
   
   for(int i = ArraySize(g_FVGs) - 1; i >= 0; i--) {
      if(currentTime > g_FVGs[i].timeEnd) {
         ArrayRemove(g_FVGs, i, 1);
      }
   }
   
   DeleteOldChartObjects(200);
}

void DeleteOldChartObjects(int barsBack) {
   datetime threshold = iTime(_Symbol, PERIOD_CURRENT, barsBack);
   
   for(int i = ObjectsTotal(0) - 1; i >= 0; i--) {
      string name = ObjectName(0, i);
      
      if(StringFind(name, "OB_") == 0 || StringFind(name, "FVG_") == 0 || StringFind(name, "LIQ_") == 0) {
         datetime objTime = (datetime)ObjectGetInteger(0, name, OBJPROP_TIME);
         
         if(objTime < threshold) {
            ObjectDelete(0, name);
         }
      }
   }
}

void DeleteAllChartObjects() {
   for(int i = ObjectsTotal(0) - 1; i >= 0; i--) {
      string name = ObjectName(0, i);
      
      if(StringFind(name, "OB_") == 0 || StringFind(name, "FVG_") == 0 || StringFind(name, "LIQ_") == 0) {
         ObjectDelete(0, name);
      }
   }
}

template<typename T>
void LimitArraySize(T &arr[], int maxSize) {
   int currentSize = ArraySize(arr);
   
   if(currentSize > maxSize) {
      ArrayRemove(arr, maxSize, currentSize - maxSize);
   }
}

string GetBrokerSymbol(string baseSymbol) {
   string testSymbol = SymbolPrefix + baseSymbol + SymbolSuffix;
   
   if(SymbolSelect(testSymbol, true)) {
      return testSymbol;
   }
   
   string variants[] = {baseSymbol, baseSymbol + ".", baseSymbol + "m", baseSymbol + ".a", "m." + baseSymbol, "#" + baseSymbol, baseSymbol + ".pro", baseSymbol + "pro"};
   
   for(int i = 0; i < ArraySize(variants); i++) {
      if(SymbolSelect(variants[i], true)) {
         return variants[i];
      }
   }
   
   return "";
}

//+------------------------------------------------------------------+
//| END OF ULTRON EA - INSTITUTIONAL GRADE ICT/SMC SYSTEM            |
//+------------------------------------------------------------------+
