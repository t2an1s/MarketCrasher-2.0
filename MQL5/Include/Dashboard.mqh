//+------------------------------------------------------------------+
//| Dashboard include                                                |
//+------------------------------------------------------------------+

class CDashboard
  {
private:
   long   chart_id;
   int    y;
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
     }
   void Update()
     {
      // additional stats can be drawn here
     }
   void Shutdown()
     {
      ObjectDelete(chart_id,"dash_bg");
     }
  };

static CDashboard dashboard;

void DashboardInit()
  {
   dashboard.Init();
  }

void DashboardOnTick()
  {
   dashboard.Update();
  }

void DashboardShutdown()
  {
   dashboard.Shutdown();
  }
//+------------------------------------------------------------------+
