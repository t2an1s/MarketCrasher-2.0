//+------------------------------------------------------------------+

//| Synergy calculation include                                      |
//+------------------------------------------------------------------+

#ifndef __SYNERGY_MQH__
#define __SYNERGY_MQH__

// helper for synergy addition
static double SynergyAdd(bool above,bool below,double factor,double timeFactor)
  {
   if(above)
      return(factor*timeFactor);
   if(below)
      return(-(factor*timeFactor));
   return(0.0);
  }

// calculate synergy score across several timeframes
static double CalcSynergyScore(
      double rsiWeight,double trendWeight,double macdSlopeWeight,
      bool useTF5,double weight5,
      bool useTF15,double weight15,
      bool useTF60,double weight60)
  {
   double score=0.0;

   if(useTF5)
     {
      double rsi=iRSI(_Symbol,PERIOD_M5,14,PRICE_CLOSE,0);
      double maFast=iMA(_Symbol,PERIOD_M5,10,0,MODE_EMA,PRICE_CLOSE,0);
      double maSlow=iMA(_Symbol,PERIOD_M5,100,0,MODE_EMA,PRICE_CLOSE,0);
      double macd=iMA(_Symbol,PERIOD_M5,12,0,MODE_EMA,PRICE_CLOSE,0)-
                 iMA(_Symbol,PERIOD_M5,26,0,MODE_EMA,PRICE_CLOSE,0);
      double macdPrev=iMA(_Symbol,PERIOD_M5,12,0,MODE_EMA,PRICE_CLOSE,1)-
                      iMA(_Symbol,PERIOD_M5,26,0,MODE_EMA,PRICE_CLOSE,1);
      score+=SynergyAdd(rsi>50,rsi<50,rsiWeight,weight5);
      score+=SynergyAdd(maFast>maSlow,maFast<maSlow,trendWeight,weight5);
      score+=SynergyAdd(macd>macdPrev,macd<macdPrev,macdSlopeWeight,weight5);
     }

   if(useTF15)
     {
      double rsi=iRSI(_Symbol,PERIOD_M15,14,PRICE_CLOSE,0);
      double maFast=iMA(_Symbol,PERIOD_M15,50,0,MODE_EMA,PRICE_CLOSE,0);
      double maSlow=iMA(_Symbol,PERIOD_M15,200,0,MODE_EMA,PRICE_CLOSE,0);
      double macd=iMA(_Symbol,PERIOD_M15,12,0,MODE_EMA,PRICE_CLOSE,0)-
                 iMA(_Symbol,PERIOD_M15,26,0,MODE_EMA,PRICE_CLOSE,0);
      double macdPrev=iMA(_Symbol,PERIOD_M15,12,0,MODE_EMA,PRICE_CLOSE,1)-
                      iMA(_Symbol,PERIOD_M15,26,0,MODE_EMA,PRICE_CLOSE,1);
      score+=SynergyAdd(rsi>50,rsi<50,rsiWeight,weight15);
      score+=SynergyAdd(maFast>maSlow,maFast<maSlow,trendWeight,weight15);
      score+=SynergyAdd(macd>macdPrev,macd<macdPrev,macdSlopeWeight,weight15);
     }

   if(useTF60)
     {
      double rsi=iRSI(_Symbol,PERIOD_H1,14,PRICE_CLOSE,0);
      double maFast=iMA(_Symbol,PERIOD_H1,50,0,MODE_EMA,PRICE_CLOSE,0);
      double maSlow=iMA(_Symbol,PERIOD_H1,200,0,MODE_EMA,PRICE_CLOSE,0);
      double macd=iMA(_Symbol,PERIOD_H1,12,0,MODE_EMA,PRICE_CLOSE,0)-
                 iMA(_Symbol,PERIOD_H1,26,0,MODE_EMA,PRICE_CLOSE,0);
      double macdPrev=iMA(_Symbol,PERIOD_H1,12,0,MODE_EMA,PRICE_CLOSE,1)-
                      iMA(_Symbol,PERIOD_H1,26,0,MODE_EMA,PRICE_CLOSE,1);
      score+=SynergyAdd(rsi>50,rsi<50,rsiWeight,weight60);
      score+=SynergyAdd(maFast>maSlow,maFast<maSlow,trendWeight,weight60);
      score+=SynergyAdd(macd>macdPrev,macd<macdPrev,macdSlopeWeight,weight60);
     }

   return(score);
  }

#endif //__SYNERGY_MQH__

