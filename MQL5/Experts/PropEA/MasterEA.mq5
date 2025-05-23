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



CTrade      trade;

//--- input parameters
input double   RiskPercent    = 0.3;   // risk per trade in percent
input double   FixedLot       = 1.0;   // fixed lot size when RiskPercent=0
input bool     UseRiskPercent = true;  // use risk percent or fixed lot
input double   HedgeFactor    = 1.0;   // hedge lot multiplier
input string   SignalFile     = "hedge_signal.txt"; // file for hedge instructions


//--- synergy settings
input bool     UseSynergyScore = true;   // enable synergy filter
input double   RsiWeight       = 1.0;    // RSI contribution
input double   TrendWeight     = 1.0;    // MA trend contribution
input double   MacdSlopeWeight = 1.0;    // MACD slope contribution
input bool     UseTF5M         = true;   // use 5 minute timeframe
input double   WeightM5        = 1.0;    // weight for 5m
input bool     UseTF15M        = true;   // use 15 minute timeframe
input double   WeightM15       = 1.0;    // weight for 15m
input bool     UseTF1H         = true;   // use 1 hour timeframe
input double   WeightH1        = 1.0;    // weight for 1h




//--- global variables
bool hasPosition=false;
double lastLots=0.0;
double lastSL=0.0;
double lastTP=0.0;

double synergyScore=0.0;
datetime lastBarTime=0;


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
  DashboardOnTick(synergyScore);

  //--- calculate synergy score on new bar
  datetime curBar=iTime(_Symbol,_Period,0);
  if(curBar!=lastBarTime)
    {
     synergyScore=CalcSynergyScore(UseTF5M,UseTF15M,UseTF1H,
                                   WeightM5,WeightM15,WeightH1,
                                   RsiWeight,TrendWeight,MacdSlopeWeight);
     lastBarTime=curBar;
    }

  //--- check if we have an open position
  hasPosition=(PositionSelect(_Symbol));

  //--- compute signals
  double fast=iMA(_Symbol,_Period,50,0,MODE_EMA,PRICE_CLOSE,0);
  double slow=iMA(_Symbol,_Period,200,0,MODE_EMA,PRICE_CLOSE,0);
  bool longCondition=(fast>slow);
  bool shortCondition=(fast<slow);
  if(UseSynergyScore)
    {
     longCondition=longCondition && synergyScore>0.0;
     shortCondition=shortCondition && synergyScore<0.0;
    }


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
