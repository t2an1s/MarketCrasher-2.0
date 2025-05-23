//+------------------------------------------------------------------+
//| Dashboard include                                                |
//+------------------------------------------------------------------+

class CDashboard
  {
private:
   long   chart_id;
   int    y;
   string synergy_name;
public:
   void Init()
     {
      chart_id=ChartID();
      y=20;
      ObjectCreate(chart_id,"dash_bg",OBJ_LABEL,0,0,0);
      ObjectSetInteger(chart_id,"dash_bg",OBJPROP_CORNER,0);
      ObjectSetInteger(chart_id,"dash_bg",OBJPROP_XDISTANCE,10);
      ObjectSetInteger(chart_id,"dash_bg",OBJPROP_YDISTANCE,10);
      ObjectSetString(chart_id,"dash_bg",OBJPROP_TEXT,"MarketCrasher Dashboard");
      ObjectSetInteger(chart_id,"dash_bg",OBJPROP_FONTSIZE,12);
      synergy_name="synergy";
      ObjectCreate(chart_id,synergy_name,OBJ_LABEL,0,0,0);
      ObjectSetInteger(chart_id,synergy_name,OBJPROP_CORNER,0);
      ObjectSetInteger(chart_id,synergy_name,OBJPROP_XDISTANCE,10);
      ObjectSetInteger(chart_id,synergy_name,OBJPROP_YDISTANCE,30);
      ObjectSetInteger(chart_id,synergy_name,OBJPROP_FONTSIZE,10);
      }
   void Update(double score=0.0)
      {
      ObjectSetString(chart_id,synergy_name,OBJPROP_TEXT,
                      StringFormat("Synergy: %.2f",score));
      }
   void Shutdown()
      {
      ObjectDelete(chart_id,"dash_bg");
      ObjectDelete(chart_id,synergy_name);
      }
  };

static CDashboard dashboard;

void DashboardInit()
  {
   dashboard.Init();
  }

void DashboardOnTick(double score=0.0)
  {
   dashboard.Update(score);
  }

void DashboardShutdown()
  {
   dashboard.Shutdown();
  }
//+------------------------------------------------------------------+
