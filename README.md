# 🚀 ULTRON EA v2.0.0 - LIGHTWEIGHT & FAST
## Enterprise ICT/SMC Expert Advisor for MetaTrader 5

![Platform](https://img.shields.io/badge/Platform-MetaTrader_5-blue)
![Strategy](https://img.shields.io/badge/Strategy-ICT%2FSMC-green)
![Version](https://img.shields.io/badge/Version-2.0.0-red)

---

## 📊 OVERVIEW

**Ultron** is a lightweight, high-performance ICT/SMC Expert Advisor optimized for **EUR/USD** and **XAU/USD**. Built for speed and minimal resource usage.

### Performance Targets
- **Risk:Reward:** 1:2 to 1:5+
- **Expected Monthly Return:** 20-50%
- **Maximum Drawdown:** 15-25%
- **Trading Pairs:** EUR/USD, XAU/USD (Gold)

### System Requirements
- **Platform:** MetaTrader 5 (Build 3802+)
- **RAM:** <100MB usage (ultra-lightweight)
- **CPU:** <5ms OnTick execution
- **Account Type:** Any (Standard, Cent, ECN)
- **Minimum Balance:** $100 or 1000 cents

---

## ✨ KEY FEATURES

### Core ICT/SMC Logic
✅ Market Structure (BOS/CHoCH) | Order Blocks | Fair Value Gaps | Liquidity Levels  
✅ Multi-Timeframe Bias (H4/D1 trend filter)  
✅ Trailing Stop & Partial Take Profit  
✅ Session-Based Trading (London, NY AM/PM)  
✅ **FREE MT5 Calendar API** for news (no paid API needed!)  
✅ Symbol Auto-Detection  
✅ Lightweight (<100MB RAM, <5ms OnTick)  

---

## 🔧 QUICK SETUP

1. Copy `Ultron.mq5` to MT5 Experts folder
2. Open **M15 chart** (EUR/USD or XAU/USD)
3. Attach EA → Enable AutoTrading
4. Configure risk in settings (see below)
5. Done!

---

## ⚙️ KEY SETTINGS

**Recommended for $100 Account:**
```
RiskPercent = 1.0
MaxDailyTrades = 0 (unlimited)
UseTrailingStop = true
UsePartialTP = true
UseHTF_Bias = true
UseNewsFilter = true (FREE - uses MT5 Calendar API)
```

**Recommended for 1000 Cents Account:**
```
RiskPercent = 2.0
MaxDailyTrades = 0
```

---

## � NEWS API - FREE & AUTOMATIC

**❓ Do I need a paid API for news?**  
**✅ NO! MT5 has a FREE built-in Calendar API.**

**How it works:**
1. MT5 automatically downloads economic calendar
2. EA uses `CalendarValueHistory()` function (built into MT5)
3. Detects high-impact USD/EUR/GBP news
4. Avoids trading 30 min before/after
5. **Zero cost, zero configuration needed!**

Just ensure:
- MT5 has internet connection
- Set `UseNewsFilter = true` in EA settings
- That's it!

---

## 🎯 STRATEGY LOGIC

**ICT/SMC Core:**
1. Market Structure (BOS/CHoCH)
2. Order Blocks (institutional zones)
3. Fair Value Gaps (price imbalances)
4. Liquidity Sweeps (stop hunts)
5. Multi-Timeframe Bias (H4/D1 trend)

**Entry Requirements:**
- Price mitigates Order Block
- Market structure aligned
- Active session (London/NY AM/PM)
- No high-impact news (FREE Calendar API)
- Optional: SMT divergence, HTF bias confirmation

**Exit Management:**
- Partial TP: Close 50% at first target
- Trailing Stop: Lock in profits
- Breakeven: Move SL to entry after 1:1 RR
- Max daily trades/loss protection

---

## ⚙️ FULL SETTINGS REFERENCE

### Risk (All Configurable)
```
RiskPercent = 1.0       // % risk per trade
MaxLots = 2.0           // Position size cap
MaxDailyTrades = 0      // 0 = unlimited
MaxDailyLoss = 3.0      // % loss before halt
MoveToBreakeven = true
BreakevenTrigger = 1.0  // At 1:1 RR
```

### Features
```
UseHTF_Bias = true      // H4/D1 trend filter
UseTrailingStop = true
UsePartialTP = true
UseNewsFilter = true    // FREE MT5 Calendar
UseSMT = false          // EUR/GBP or XAU/XAG divergence
```

### Sessions (EST)
```
TradeLondon = true      // 02:00-05:00
TradeNY_AM = true       // 10:00-11:00 (PRIORITY)
TradeNY_PM = true       // 14:00-15:00
```

### Visuals (Optional)
```
DrawOBs = false         // Order Block rectangles
DrawFVGs = false        // FVG zones
DrawLiquidity = false   // Liquidity lines
```

### Symbol Detection
```
SymbolPrefix = ""       // e.g., "m." or "#"
SymbolSuffix = ""       // e.g., ".a" or "pro"
TradeEURUSD = true
TradeXAUUSD = true
```

---

## ❓ FAQ

**Q: Which timeframe should I use?**  
A: **M15** (15-minute chart). The EA uses H4/D1 for bias automatically.

**Q: Do I need multiple charts for MTF bias?**  
A: No. Just attach to 1 M15 chart. EA fetches H4/D1 data internally.

**Q: What's the minimum account balance?**  
A: $100 or 1000 cents with 1% risk.

**Q: How do I know if it's working?**  
A: Check Experts tab in Terminal for initialization message.

**Q: Symbol not found error?**  
A: Adjust `SymbolPrefix` or `SymbolSuffix` (e.g., "m." or ".a").

**Q: How to disable visual drawings?**  
A: Set `DrawOBs = false`, `DrawFVGs = false`, `DrawLiquidity = false`.

**Q: Is trailing stop automatic?**  
A: Yes, if `UseTrailingStop = true`.

---

## �️ TROUBLESHOOTING

**❌ "Symbol not found"**  
→ Check symbol list in Market Watch. Adjust SymbolPrefix/Suffix.

**❌ No trades opening**  
→ Verify: AutoTrading enabled | Active session | No high-impact news | Valid market structure

**❌ High RAM usage**  
→ Set DrawOBs/DrawFVGs/DrawLiquidity = false | Reduce lookback periods

**❌ Compilation errors**  
→ Use MT5 Build 3802+ | Check MQL5 syntax

---

## 📝 CHANGELOG

**v2.0.0 - Lightweight & Fast**
- Removed dashboard (RAM optimization)
- Disabled visual drawings by default
- Simplified OnTick execution
- FREE MT5 Calendar API clarified
- All risk parameters fully configurable
- Minimal documentation (README only)

**v1.0.0 - Initial Release**
- Core ICT/SMC implementation
- Multi-symbol support (EUR/USD, XAU/USD)
- Session-based trading
- HTF bias, trailing stop, partial TP

---

## 📄 LICENSE

MIT License - Free for personal and commercial use.

---

## 💬 SUPPORT

**Issues?** Open a ticket on GitHub or contact via email.

**Backtest First!** Always test on demo before live trading.

---

**⚡ ULTRON EA - Lightweight | Fast | ICT/SMC | FREE Calendar API ⚡**
