//+------------------------------------------------------------------+
//| Synergy score calculation include                                |
//+------------------------------------------------------------------+
#ifndef __SYNERGY_MQH__
#define __SYNERGY_MQH__

// helper function
inline double SynergyAdd(bool above,bool below,double factor,double timeFactor)
  {
   if(above) return(factor*timeFactor);
   if(below) return(-(factor*timeFactor));
   return(0.0);
  }

// calculate synergy score using closed bars on multiple timeframes
inline double CalcSynergyScore(
      bool useTF5,
      bool useTF15,
      bool useTF1H,
      double weightM5,
      double weightM15,
      double weightH1,
      double rsiWeight,
      double trendWeight,
      double macdSlopeWeight)
  {
   double score=0.0;
   if(useTF5)
     {
      double rsi=iRSI(_Symbol,PERIOD_M5,14,PRICE_CLOSE,1);
      double ma1=iMA(_Symbol,PERIOD_M5,10,0,MODE_EMA,PRICE_CLOSE,1);
      double ma2=iMA(_Symbol,PERIOD_M5,100,0,MODE_EMA,PRICE_CLOSE,1);
      double macd=iMA(_Symbol,PERIOD_M5,12,0,MODE_EMA,PRICE_CLOSE,1)-iMA(_Symbol,PERIOD_M5,26,0,MODE_EMA,PRICE_CLOSE,1);
      double macd_prev=iMA(_Symbol,PERIOD_M5,12,0,MODE_EMA,PRICE_CLOSE,2)-iMA(_Symbol,PERIOD_M5,26,0,MODE_EMA,PRICE_CLOSE,2);
      score+=SynergyAdd(rsi>50,rsi<50,rsiWeight,weightM5);
      score+=SynergyAdd(ma1>ma2,ma1<ma2,trendWeight,weightM5);
      score+=SynergyAdd(macd>macd_prev,macd<macd_prev,macdSlopeWeight,weightM5);
     }
   if(useTF15)
     {
      double rsi=iRSI(_Symbol,PERIOD_M15,14,PRICE_CLOSE,1);
      double ma1=iMA(_Symbol,PERIOD_M15,50,0,MODE_EMA,PRICE_CLOSE,1);
      double ma2=iMA(_Symbol,PERIOD_M15,200,0,MODE_EMA,PRICE_CLOSE,1);
      double macd=iMA(_Symbol,PERIOD_M15,12,0,MODE_EMA,PRICE_CLOSE,1)-iMA(_Symbol,PERIOD_M15,26,0,MODE_EMA,PRICE_CLOSE,1);
      double macd_prev=iMA(_Symbol,PERIOD_M15,12,0,MODE_EMA,PRICE_CLOSE,2)-iMA(_Symbol,PERIOD_M15,26,0,MODE_EMA,PRICE_CLOSE,2);
      score+=SynergyAdd(rsi>50,rsi<50,rsiWeight,weightM15);
      score+=SynergyAdd(ma1>ma2,ma1<ma2,trendWeight,weightM15);
      score+=SynergyAdd(macd>macd_prev,macd<macd_prev,macdSlopeWeight,weightM15);
     }
   if(useTF1H)
     {
      double rsi=iRSI(_Symbol,PERIOD_H1,14,PRICE_CLOSE,1);
      double ma1=iMA(_Symbol,PERIOD_H1,50,0,MODE_EMA,PRICE_CLOSE,1);
      double ma2=iMA(_Symbol,PERIOD_H1,200,0,MODE_EMA,PRICE_CLOSE,1);
      double macd=iMA(_Symbol,PERIOD_H1,12,0,MODE_EMA,PRICE_CLOSE,1)-iMA(_Symbol,PERIOD_H1,26,0,MODE_EMA,PRICE_CLOSE,1);
      double macd_prev=iMA(_Symbol,PERIOD_H1,12,0,MODE_EMA,PRICE_CLOSE,2)-iMA(_Symbol,PERIOD_H1,26,0,MODE_EMA,PRICE_CLOSE,2);
      score+=SynergyAdd(rsi>50,rsi<50,rsiWeight,weightH1);
      score+=SynergyAdd(ma1>ma2,ma1<ma2,trendWeight,weightH1);
      score+=SynergyAdd(macd>macd_prev,macd<macd_prev,macdSlopeWeight,weightH1);
     }
   return(score);
  }

#endif // __SYNERGY_MQH__
//+------------------------------------------------------------------+
