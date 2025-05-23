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
#include <HedgeEngine.mqh>

CTrade      trade;

//--- input parameters
input double   RiskPercent    = 0.3;   // risk per trade in percent
input double   FixedLot       = 1.0;   // fixed lot size when RiskPercent=0
input bool     UseRiskPercent = true;  // use risk percent or fixed lot
input string   SignalFile     = "hedge_signal.txt"; // file for hedge instructions
input double   ChallengeFee   = 700;  // challenge fee (C)
input double   MaxDD          = 4000; // max drawdown (M)
input double   SlipBuffer     = 0.10; // slip buffer
input double   DailyDDCap     = 1700; // daily drawdown cap
input double   StageTarget    = 1000; // stage target for bleed



//--- global variables
bool hasPosition=false;
double lastLots=0.0;
double lastSL=0.0;
double lastTP=0.0;
double lastHedgeLots=0.0;
CHedgeEngine hedge;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   DashboardInit();
   hedge.Init(SignalFile,ChallengeFee,MaxDD,SlipBuffer,StageTarget,DailyDDCap);
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
//| Expert tick function                                              |
//+------------------------------------------------------------------+
void OnTick()
  {
   //--- update dashboard
   DashboardOnTick();
   hedge.UpdateDailyEquity();

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
            lastHedgeLots=hedge.HedgeLots(lots);
            if(!hedge.DailyDDExceeded())
               hedge.SendSignal("SELL",lastHedgeLots,sl,tp);
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
            lastHedgeLots=hedge.HedgeLots(lots);
            if(!hedge.DailyDDExceeded())
               hedge.SendSignal("BUY",lastHedgeLots,sl,tp);
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
           if(!hedge.DailyDDExceeded())
              hedge.SendSignal("ADJ",lastHedgeLots,newSL,lastTP);
           }
        }
      }

   hedge.CheckBleed(AccountInfoDouble(ACCOUNT_PROFIT),lastHedgeLots);
  }

//+------------------------------------------------------------------+
