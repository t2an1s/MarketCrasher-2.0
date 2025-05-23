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

//--- trading session inputs (HHMM-HHMM)
input bool     UseSessions    = true;
input string   MonSession1    = "0000-2359";
input string   MonSession2    = "0000-2359";
input string   TueSession1    = "0000-2359";
input string   TueSession2    = "0000-2359";
input string   WedSession1    = "0000-2359";
input string   WedSession2    = "0000-2359";
input string   ThuSession1    = "0000-2359";
input string   ThuSession2    = "0000-2359";
input string   FriSession1    = "0000-2359";
input string   FriSession2    = "0000-2359";
input string   SatSession1    = "0000-2359";
input string   SatSession2    = "0000-2359";
input string   SunSession1    = "0000-2359";
input string   SunSession2    = "0000-2359";

//--- market bias settings
input bool              UseMarketBias = true;
input ENUM_TIMEFRAMES   BiasTimeframe = PERIOD_H1;
input int               BiasMAPeriod  = 100;

//--- ADX filter settings
input bool   EnableADXFilter    = true;
input int    ADXPeriod          = 14;
input bool   UseDynamicADX      = true;
input double StaticADXThreshold = 25;
input int    ADXLookbackPeriod  = 20;
input double ADXMultiplier      = 0.8;
input double ADXMinThreshold    = 15;



//--- global variables
bool hasPosition=false;
double lastLots=0.0;
double lastSL=0.0;
double lastTP=0.0;

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
//| Helper: check if current time falls inside session string         |
//+------------------------------------------------------------------+
bool InSession(const string session)
  {
   if(StringLen(session)<9)
      return(true);
   int sh=(int)StringToInteger(StringSubstr(session,0,2));
   int sm=(int)StringToInteger(StringSubstr(session,2,2));
   int eh=(int)StringToInteger(StringSubstr(session,5,2));
   int em=(int)StringToInteger(StringSubstr(session,7,2));
   datetime t=TimeCurrent();
   int cur=TimeHour(t)*60+TimeMinute(t);
   int start=sh*60+sm;
   int end=eh*60+em;
   if(start<=end)
      return(cur>=start && cur<=end);
   return(cur>=start || cur<=end);
  }

//+------------------------------------------------------------------+
//| Determine if trading is allowed based on sessions                  |
//+------------------------------------------------------------------+
bool TradingAllowed()
  {
   if(!UseSessions)
      return(true);

   int dow=DayOfWeek(); // 0=Sunday
   switch(dow)
     {
      case 1: return(InSession(MonSession1)||InSession(MonSession2));
      case 2: return(InSession(TueSession1)||InSession(TueSession2));
      case 3: return(InSession(WedSession1)||InSession(WedSession2));
      case 4: return(InSession(ThuSession1)||InSession(ThuSession2));
      case 5: return(InSession(FriSession1)||InSession(FriSession2));
      case 6: return(InSession(SatSession1)||InSession(SatSession2));
      default: return(InSession(SunSession1)||InSession(SunSession2));
     }
  }

//+------------------------------------------------------------------+
//| Determine current market bias                                     |
//+------------------------------------------------------------------+
bool BiasBullish()
  {
   if(!UseMarketBias)
      return(true);
   double maClose=iMA(_Symbol,BiasTimeframe,BiasMAPeriod,0,MODE_EMA,PRICE_CLOSE,0);
   double maOpen =iMA(_Symbol,BiasTimeframe,BiasMAPeriod,0,MODE_EMA,PRICE_OPEN,0);
   return(maClose>maOpen);
  }

//+------------------------------------------------------------------+
//| ADX trend condition                                               |
//+------------------------------------------------------------------+
bool ADXTrendOk()
  {
   if(!EnableADXFilter)
      return(true);
   double adx=iADX(_Symbol,_Period,ADXPeriod,PRICE_CLOSE,MODE_MAIN,0);
   double threshold=StaticADXThreshold;
   if(UseDynamicADX)
     {
      double sum=0;
      for(int i=0;i<ADXLookbackPeriod;i++)
         sum+=iADX(_Symbol,_Period,ADXPeriod,PRICE_CLOSE,MODE_MAIN,i);
      double avg=sum/ADXLookbackPeriod;
      double dyn=MathMax(ADXMinThreshold,avg*ADXMultiplier);
      threshold=dyn;
     }
   return(adx>threshold);
  }

//+------------------------------------------------------------------+
//| Expert tick function                                              |
//+------------------------------------------------------------------+
void OnTick()
  {
  //--- update dashboard
  DashboardOnTick();

  if(!TradingAllowed() || !ADXTrendOk())
     return;

  //--- check if we have an open position
  hasPosition=(PositionSelect(_Symbol));

  //--- compute signals
  double fast=iMA(_Symbol,_Period,50,0,MODE_EMA,PRICE_CLOSE,0);
  double slow=iMA(_Symbol,_Period,200,0,MODE_EMA,PRICE_CLOSE,0);
  bool biasBull=BiasBullish();
  bool longCondition=(fast>slow && biasBull);
  bool shortCondition=(fast<slow && !biasBull);

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
