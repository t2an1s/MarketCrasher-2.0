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
#include <Pivot.mqh>

CTrade      trade;

//--- input parameters
input double   RiskPercent    = 0.3;   // risk per trade in percent
input double   FixedLot       = 1.0;   // fixed lot size when RiskPercent=0
input bool     UseRiskPercent = true;  // use risk percent or fixed lot
input double   HedgeFactor    = 1.0;   // hedge lot multiplier
input string   SignalFile     = "hedge_signal.txt"; // file for hedge instructions
input int      PivotLookback  = 50;    // lookback bars for pivot SL/TP
input int      PivotLeft      = 6;     // pivot length left
input int      PivotRight     = 6;     // pivot length right
input bool     DrawZigZag     = true;  // show zigzag lines



//--- global variables
bool hasPosition=false;
double lastLots=0.0;
double lastSL=0.0;
double lastTP=0.0;
datetime lastBarTime=0;
PivotZigZag zz;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   DashboardInit();
   zz.Init(DrawZigZag);
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

   //--- detect new bar for zigzag drawing
   datetime currentBar=Time[0];
   if(currentBar!=lastBarTime)
     {
      lastBarTime=currentBar;
      double ph=IsPivotHigh(PivotRight,PivotLeft,PivotRight)?High[PivotRight]:EMPTY_VALUE;
      if(ph!=EMPTY_VALUE)
         zz.AddPoint(Time[PivotRight],ph);
      double pl=IsPivotLow(PivotRight,PivotLeft,PivotRight)?Low[PivotRight]:EMPTY_VALUE;
      if(pl!=EMPTY_VALUE)
         zz.AddPoint(Time[PivotRight],pl);
     }

   //--- check if we have an open position
   hasPosition=(PositionSelect(_Symbol));

   //--- compute signals
   double fast=iMA(_Symbol,_Period,50,0,MODE_EMA,PRICE_CLOSE,0);
   double slow=iMA(_Symbol,_Period,200,0,MODE_EMA,PRICE_CLOSE,0);
   bool longCondition=(fast>slow);
   bool shortCondition=(fast<slow);

   if(!hasPosition)
     {
      //--- open position if condition met using pivot-based SL/TP
      double sl,tp;
      if(longCondition)
        {
         sl=FindDeepestPivotLowBelowClose(PivotLookback,PivotLeft,PivotRight);
         tp=FindHighestPivotHighAboveClose(PivotLookback,PivotLeft,PivotRight);
         if(sl!=EMPTY_VALUE && tp!=EMPTY_VALUE)
           {
            double entry=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
            double sl_points=(entry-sl)/_Point;
            double lots=CalcLots(sl_points);
            if(trade.Buy(lots,_Symbol,0,sl,tp))
              {
               lastLots=lots; lastSL=sl; lastTP=tp;
               SendHedgeSignal("SELL",lots*HedgeFactor,sl,tp);
              }
           }
        }
      else if(shortCondition)
        {
         sl=FindHighestPivotHighAboveClose(PivotLookback,PivotLeft,PivotRight);
         tp=FindDeepestPivotLowBelowClose(PivotLookback,PivotLeft,PivotRight);
         if(sl!=EMPTY_VALUE && tp!=EMPTY_VALUE)
           {
            double entry=SymbolInfoDouble(_Symbol,SYMBOL_BID);
            double sl_points=(sl-entry)/_Point;
            double lots=CalcLots(sl_points);
            if(trade.Sell(lots,_Symbol,0,sl,tp))
              {
               lastLots=lots; lastSL=sl; lastTP=tp;
               SendHedgeSignal("BUY",lots*HedgeFactor,sl,tp);
              }
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
