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

CTrade      trade;

//--- input parameters
input double   RiskPercent    = 0.3;   // risk per trade in percent
input double   FixedLot       = 1.0;   // fixed lot size when RiskPercent=0
input bool     UseRiskPercent = true;  // use risk percent or fixed lot
input double   HedgeFactor    = 1.0;   // hedge lot multiplier
input string   SignalFile     = "hedge_signal.txt"; // file for hedge instructions

// scale-out and breakeven settings
input bool     EnableScaleOut = true;    // enable partial profit taking
input double   ScaleOutPct    = 50;      // percent of distance to TP for scale-out
input double   ScaleOutSize   = 50;      // percent of position to close
input bool     ScaleOutBE     = true;    // set breakeven after scale-out
input bool     EnableBreakEven = false;  // enable breakeven without scale-out
input double   BreakEvenTrigger = 100;   // profit in points to trigger breakeven



//--- global variables
bool hasPosition=false;
double lastLots=0.0;
double lastSL=0.0;
double lastTP=0.0;
bool  scaleOutDone=false;
bool  breakEvenDone=false;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   DashboardInit();
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

   //--- compute signals
   double fast=iMA(_Symbol,_Period,50,0,MODE_EMA,PRICE_CLOSE,0);
   double slow=iMA(_Symbol,_Period,200,0,MODE_EMA,PRICE_CLOSE,0);
   bool longCondition=(fast>slow);
   bool shortCondition=(fast<slow);

   if(!hasPosition)
     {
      //--- open position if condition met
      double sl,tp;
      if(longCondition)
        {
         sl=SymbolInfoDouble(_Symbol,SYMBOL_BID)-100*_Point;
         tp=SymbolInfoDouble(_Symbol,SYMBOL_BID)+200*_Point;
         double lots=CalcLots(100);
         if(trade.Buy(lots,_Symbol,0,sl,tp))
           {
            lastLots=lots; lastSL=sl; lastTP=tp;
            scaleOutDone=false;
            breakEvenDone=false;
            SendHedgeSignal("SELL",lots*HedgeFactor,sl,tp);
         }
      }
      else if(shortCondition)
        {
         sl=SymbolInfoDouble(_Symbol,SYMBOL_ASK)+100*_Point;
         tp=SymbolInfoDouble(_Symbol,SYMBOL_ASK)-200*_Point;
         double lots=CalcLots(100);
         if(trade.Sell(lots,_Symbol,0,sl,tp))
           {
            lastLots=lots; lastSL=sl; lastTP=tp;
            scaleOutDone=false;
            breakEvenDone=false;
            SendHedgeSignal("BUY",lots*HedgeFactor,sl,tp);
           }
        }
     }
   else
     {
     ulong ticket=PositionGetTicket(0);
     int type=PositionGetInteger(POSITION_TYPE);
     double entry=PositionGetDouble(POSITION_PRICE_OPEN);
     double volume=PositionGetDouble(POSITION_VOLUME);
     double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
     double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
     double profit_in_points=(type==POSITION_TYPE_BUY)? (bid-entry)/_Point : (entry-ask)/_Point;

     //--- scale-out logic
     if(EnableScaleOut && !scaleOutDone)
       {
        double scalePrice=entry;
        if(type==POSITION_TYPE_BUY)
           scalePrice=entry + (lastTP-entry)*ScaleOutPct/100.0;
        else
           scalePrice=entry - (entry-lastTP)*ScaleOutPct/100.0;

        if((type==POSITION_TYPE_BUY && bid>=scalePrice) ||
           (type==POSITION_TYPE_SELL && ask<=scalePrice))
          {
           double closeLots=NormalizeDouble(volume*(ScaleOutSize/100.0),2);
           if(closeLots>0.0 && trade.PositionClosePartial(ticket,closeLots))
             {
              scaleOutDone=true;
              lastLots-=closeLots;
              SendHedgeSignal("SO",closeLots,0,0);

              if(ScaleOutBE && !breakEvenDone)
                {
                 trade.PositionModify(ticket,entry,lastTP);
                 lastSL=entry;
                 breakEvenDone=true;
                }
             }
          }
       }

     //--- breakeven logic
     if(EnableBreakEven && !breakEvenDone && profit_in_points>=BreakEvenTrigger)
       {
        if(trade.PositionModify(ticket,entry,lastTP))
          {
           lastSL=entry;
           breakEvenDone=true;
          }
       }
     }
  }

//+------------------------------------------------------------------+
