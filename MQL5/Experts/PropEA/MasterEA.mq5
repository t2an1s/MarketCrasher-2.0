//+------------------------------------------------------------------+
//|                                                    MasterEA.mq5 |
//|       Ported from TradingView strategy                          |
//|                                                                  |
//|  This EA executes trades on a prop account and writes hedge      |
//|  instructions for a second terminal.                             |
//+------------------------------------------------------------------+
#property copyright ""
#property version   "1.00"
#property strict

#include <Trade/Trade.mqh>
#include <Files/File.mqh>
#include <Dashboard.mqh>
#include <Synergy.mqh>
#include <Pivots.mqh>

CTrade      trade;

//--- input parameters
input double   RiskPercent    = 0.3;   // risk per trade in percent
input double   FixedLot       = 1.0;   // fixed lot size when RiskPercent=0
input bool     UseRiskPercent = true;  // use risk percent or fixed lot
input double   HedgeFactor    = 1.0;   // hedge lot multiplier
input string   SignalFile     = "hedge_signal.txt"; // file for hedge instructions

//--- synergy inputs
input bool     UseSynergy     = true;   // enable multi-timeframe synergy filter
input double   RSIWeight      = 1.0;    // RSI contribution
input double   TrendWeight    = 1.0;    // EMA trend contribution
input double   MacdSlopeWeight= 1.0;    // MACD slope contribution
input bool     UseTF5m        = true;   // use 5 minute timeframe
input bool     UseTF15m       = true;   // use 15 minute timeframe
input bool     UseTF1h        = true;   // use 1 hour timeframe
input double   Weight5m       = 1.0;    // weight for 5m timeframe
input double   Weight15m      = 1.0;    // weight for 15m timeframe
input double   Weight1h       = 1.0;    // weight for 1h timeframe

//--- pivot inputs
input int      PivotLookback  = 50;     // lookback bars for pivot SL/TP
input int      PivotLeft      = 6;      // pivot length left
input int      PivotRight     = 6;      // pivot length right
input bool     DrawZigZag     = true;   // draw zigzag between pivots



//--- global variables
bool hasPosition=false;
double lastLots=0.0;
double lastSL=0.0;
double lastTP=0.0;
SynergySettings syn;
PivotSettings   piv;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   DashboardInit();
   syn.useSynergy=UseSynergy;
   syn.rsiWeight=RSIWeight;
   syn.trendWeight=TrendWeight;
   syn.macdSlopeWeight=MacdSlopeWeight;
   syn.useTF5m=UseTF5m;
   syn.useTF15m=UseTF15m;
   syn.useTF1h=UseTF1h;
   syn.weight5m=Weight5m;
   syn.weight15m=Weight15m;
   syn.weight1h=Weight1h;

   piv.lookback=PivotLookback;
   piv.leftLen=PivotLeft;
   piv.rightLen=PivotRight;
   piv.drawZigZag=DrawZigZag;
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   DashboardShutdown();
  }

//+------------------------------------------------------------------+
//| Calculate lots based on risk settings                             |
//+------------------------------------------------------------------+
double CalcLots(double sl_points)
  {
   if(!UseRiskPercent || sl_points<=0)
      return(FixedLot);

   double risk_money=AccountInfoDouble(ACCOUNT_BALANCE)*RiskPercent/100.0;
   double lotstep=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
   double tick_value=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_VALUE);
   double tick_size=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
   double value_per_point=tick_value/tick_size;
   double lots=risk_money/(sl_points*value_per_point);
   lots=MathMax(lotstep,MathFloor(lots/lotstep)*lotstep);
   return(NormalizeDouble(lots,2));
  }

//+------------------------------------------------------------------+
//| Send hedge instruction to file                                    |
//+------------------------------------------------------------------+
void SendHedgeSignal(string direction,double lots,double sl,double tp)
  {
   int file=FileOpen(SignalFile,FILE_WRITE|FILE_TXT|FILE_COMMON);
   if(file!=INVALID_HANDLE)
     {
      string line=StringFormat("%s,%s,%f,%f,%f",TimeToString(TimeCurrent(),TIME_DATE|TIME_SECONDS),direction,lots,sl,tp);
      FileWriteString(file,line+"\n");
      FileClose(file);
     }
  }

//+------------------------------------------------------------------+
//| Expert tick function                                              |
//+------------------------------------------------------------------+
void OnTick()
  {
   //--- update dashboard
   DashboardOnTick();

   //--- check if we have an open position
   hasPosition=(PositionSelect(_Symbol));
   //--- compute synergy score
   double synScore=CalcSynergyScore(syn);

   //--- find pivots for SL/TP
   int shift1,shift2;
   double slLong=FindPivotLowBelowClose(piv,shift1);
   double tpLong=FindPivotHighAboveClose(piv,shift2);
   UpdateZigZag(false,shift1,piv);
   UpdateZigZag(true,shift2,piv);

   int shift3,shift4;
   double slShort=FindPivotHighAboveClose(piv,shift3);
   double tpShort=FindPivotLowBelowClose(piv,shift4);
   UpdateZigZag(true,shift3,piv);
   UpdateZigZag(false,shift4,piv);

   bool longCondition=(syn.useSynergy?synScore>0:true) &&
                      slLong!=EMPTY_VALUE && tpLong!=EMPTY_VALUE &&
                      slLong<SymbolInfoDouble(_Symbol,SYMBOL_BID) && tpLong>SymbolInfoDouble(_Symbol,SYMBOL_BID);
   bool shortCondition=(syn.useSynergy?synScore<0:true) &&
                      slShort!=EMPTY_VALUE && tpShort!=EMPTY_VALUE &&
                      slShort>SymbolInfoDouble(_Symbol,SYMBOL_ASK) && tpShort<SymbolInfoDouble(_Symbol,SYMBOL_ASK);

   if(!hasPosition)
     {
      //--- open position if condition met
      double sl,tp;
      if(longCondition)
        {
         sl=slLong;
         tp=tpLong;
         double lots=CalcLots(MathAbs((SymbolInfoDouble(_Symbol,SYMBOL_BID)-sl)/_Point));
         if(trade.Buy(lots,_Symbol,0,sl,tp))
           {
            lastLots=lots; lastSL=sl; lastTP=tp;
            SendHedgeSignal("SELL",lots*HedgeFactor,sl,tp);
           }
        }
      else if(shortCondition)
        {
         sl=slShort;
         tp=tpShort;
         double lots=CalcLots(MathAbs((sl-SymbolInfoDouble(_Symbol,SYMBOL_ASK))/_Point));
         if(trade.Sell(lots,_Symbol,0,sl,tp))
           {
            lastLots=lots; lastSL=sl; lastTP=tp;
            SendHedgeSignal("BUY",lots*HedgeFactor,sl,tp);
           }
        }
     }
   else
     {
      //--- manage trailing stop to breakeven
      ulong ticket=PositionGetTicket(0);
      double entry=PositionGetDouble(POSITION_PRICE_OPEN);
      double profit_in_points=(SymbolInfoDouble(_Symbol,SYMBOL_BID)-entry)/_Point;
      if(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_SELL)
         profit_in_points=(entry-SymbolInfoDouble(_Symbol,SYMBOL_ASK))/_Point;
      if(profit_in_points>100)
        {
         double newSL=entry;
         if(newSL!=lastSL)
           {
            trade.PositionModify(ticket,newSL,lastTP);
            lastSL=newSL;
            SendHedgeSignal("ADJ",lastLots,newSL,lastTP);
           }
        }
     }
  }

//+------------------------------------------------------------------+
