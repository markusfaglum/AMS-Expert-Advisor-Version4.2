//+------------------------------------------------------------------+
//|                                  V2         Cycle + AMS
//|                                             Index filter + high low distance filter
//|                                             Lots based on risk
//|                                             
//|
//|                                  V3.Add+    High low to entry size filter  [Y]
//|                                             Allow add to winning position  [Y]
//|                                             Time filter                    [Y]
//|                                             Clean up code                  [Y]
//|
//|                                  V4.Add+    SuperTrend                     [Y]
//|                                             10 years of cycle dates        [Y]
//|                                             Martingale                     [Y]                   
//|                                             (logic of ST was fixed in v4)
//|                                  V4.2       change logic of size filter from points to pct
//|                                             clean up code/logic
//|
//|                                             Above is comments made for myself while working on this EA
//|                                             
//|                                 Notes: Anything related to Supertrend is disabled via comment, will produce error without supertrend indicator downloaded and installed
//|                                        This is a startegy based on a very simplified version of Advanced Market Structure and simplified cycle work (github version is missing complete cycle dates produced by calculator outside of this code)
//|                                        Complicating the strategy/code has not yet produced better results
//|  
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Include                                                          |
//+------------------------------------------------------------------+
#include <Trade\Trade.mqh>

//+------------------------------------------------------------------+
//| Input                                                            |
//+------------------------------------------------------------------+

static input long    InpMagicNumber = 27321; // magic number

input int            InpBars = 20;           // bars range for high/low
input int            InpIndexFilter = 0;     // index filter in % (0=off)
input double         InpSizeFilter = 0;      // channel size filter in pct 1/1000 (0=off) 1=0.1%
input double         InpRiskPCT = 5;         // pct of account to risk, min 0.1 max 10
input double         InpRiskToReward = 0;    // take profit based on R:R ex. 1 - 3, (0=off), max null

//v3
input double         InpAmsSizeFilter = 0;   // AMS size filter in pct 1/1000 (0=off) 1=0.1%
input bool           trailingSL = false;     // trailing stop loss on/off 

input string         TimeStart = "02:00";    // allowed trading period start
input string         TimeEnd = "22:00";      // allowed trading period end

input bool           InpFixed = true;        // fixed risk, used for testing

input int            InpMartingaleThreshold = 3;//number of losses before martingale strategy kicks in (0=off)

//input int            periods = 10;           // Supertrend variables
//input double         multiplier = 3;         // Supertrend variables

//+------------------------------------------------------------------+
//| Global Variables                                                 |
//+------------------------------------------------------------------+
double high = 0;                             // highest price of the last N bars
double low = 0;                              // lowest price of the last N bars
double firstDownBar = 0;                     // entry price for Short
double firstUpBar = 0;                       // entry price for Long
double lastSellEntry = 0;                    // last price used for making sell order
double lastBuyEntry = 0;                     // last price used for making buy order

bool AB = false;                             // allow adding to winning long position
bool AS = false;                             // allow adding to winning short position

int highIdx = 0;                             // index of highest bar
int lowIdx = 0;                              // index of lowest bar
int entryBarHighidx = 0;                     // bar index used for AMS and entry Long
int entryBarLowidx = 0;                      // bar index used for AMS and entry Short

//cycle variables
bool pivotFound = false;                     // keep cycle up to date
bool waitingForHigh = true;                  // polarity of cycle(true for 2023 backtesting)
int icycle = 0;                              // position in the cycle array
datetime currentPivot;                       // next date coming
datetime nextPivot;                          // date after that

//supertrend (currently disabled via comment in code, line 178 & 201)
//int stHandle;
//input ENUM_TIMEFRAMES Timeframe = PERIOD_CURRENT;

//martingale
bool martinGale = false;
int martingaleMultiplier = 0;

//tick and trader
MqlTick currentTick, previousTick;
CTrade trade;

int OnInit() {

      //check for user input
      if(!CheckInputs()) {return INIT_PARAMETERS_INCORRECT;}
      
      // set magic number
      trade.SetExpertMagicNumber(InpMagicNumber);
      
      //supertrend
      //stHandle = iCustom(_Symbol,Timeframe,"Supertrend.ex5",periods,multiplier);


   return(INIT_SUCCEEDED);
  }

void OnDeinit(const int reason)
  {
   
   ObjectDelete(NULL, "high");
   ObjectDelete(NULL, "low");
   ObjectDelete(NULL, "text");
   ObjectDelete(NULL, "indexFilter");
   ObjectDelete(NULL, "firstDownBar");
   ObjectDelete(NULL, "firstUpBar");
   
  }
  
  //custom tester
double OnTester(){
   
   if(TesterStatistics(STAT_TRADES)==0 || TesterStatistics(STAT_TRADES)<120){
      return 0.0;
   }
   if(TesterStatistics(STAT_EQUITY_DDREL_PERCENT)>30){
      return 0.0;
   }
   if(TesterStatistics(STAT_PROFIT)<4000){
      return 0.0;
   }
   double dd = TesterStatistics(STAT_EQUITY_DDREL_PERCENT);
   double customCriteria = 100-dd;

  return customCriteria;
}

void OnTick()
  {
  
  
      // check for new bar open
      if(!IsNewBar()) {return;}
      
      
      // get tick
      previousTick = currentTick;
      if(!SymbolInfoTick(_Symbol, currentTick)) {Print("Failed to get current tick"); return;}
      
         //supertrend
   /*double st[];
   CopyBuffer(stHandle,0,0,3,st);  
   double close1 = iClose(_Symbol,Timeframe,1);
   double close2 = iClose(_Symbol,Timeframe,2);
   bool buyCondition = close1 > st[1];
   */
       
      //cycle work
      cycle();
      
         
      //calculate high / low
      calculateHighLow();
      
      
      // Check for the first down candle before the high
      checkForAMS();
      
      
      // count open positions
      int cntBuy, cntSell;
      if(!CountOpenPositions(cntBuy, cntSell)) {return;}
      
      
      
      //timefilter
      datetime timeStart = StringToTime(TimeStart);
      datetime timeEnd = StringToTime(TimeEnd);
      bool isTime = TimeCurrent() >= timeStart && TimeCurrent() < timeEnd;
      
      
      //check for sell position
      if(
           //buyCondition == false &&
            isTime                        && low!=0 
         && previousTick.bid>firstDownBar && currentTick.bid<firstDownBar 
         && CheckIndexFilter(lowIdx)      && CheckAmsSizeFilterShort()
         && CheckSizeFilter()             && waitingForHigh == false){
         
        if(cntSell == 0){
            placeSellOrder();
            Print("cntsell = 0 order");
         }else{
         allowSell();
         if(cntSell>0 && AS){
            placeSellOrder();
            AS = false;
            Print("cnt sell > 0 order");
            
         }
        }         
      }
      
      
      //check for buy position
      if(
          //buyCondition &&
            isTime                      && low!=0                     
         && previousTick.ask<firstUpBar && currentTick.ask>firstUpBar 
         && CheckIndexFilter(lowIdx)    && CheckSizeFilter()           
         && CheckAmsSizeFilterLong()    && waitingForHigh == true){
         
         if(cntBuy == 0){
            placeBuyOrder();
            Print("cntbuy = 0 order");
         } else{
         allowBuy();
         if(cntBuy>0 && AB){
            placeBuyOrder();
            AB = false;
            Print("cnt buy > 0 order");
            
         }
        } 
                 
      }
      
     
       // update stoploss
       if(trailingSL){
          updateStopLoss(); }
   
      //martingale
      if(InpMartingaleThreshold > 0){
      martingale(); }
  }



//+------------------------------------------------------------------+ 
//|                                                                  |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| functions                                                        |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+


// check user input
bool CheckInputs() {

   if(InpMagicNumber<=0){
      Alert("Wrong inputs: Magic Number <=0");
      return false;
   }
   
  
   
   if(InpBars<=0){
      Alert("Wrong inputs: Bars <=0");
      return false;
   }
   
   if(InpIndexFilter<0 || InpIndexFilter >=50){
      Alert("Wrong inputs: Index filter <=0 or >= 50");
      return false;
   }
   
   if(InpSizeFilter<0){
      Alert("Wrong inputs: Size filter <0");
      return false;
   }
   
    if(InpRiskPCT<=0 || InpRiskPCT > 10){
      Alert("Wrong inputs: Risk percent <=0 or >10");
      return false;
   }
   
   if(InpRiskToReward<0){
      Alert("Wrong inputs: Risk to Reward <0");
      return false;
   }
   
   if(InpAmsSizeFilter<0){
      Alert("Wrong inputs: AMS Size filter <0");
      return false;
   }
   
    if(InpMartingaleThreshold<0){
      Alert("Wrong inputs: Martingale Threshold <0");
      return false;
   }
   
 
   return true;
}



// check if we have a bar open tick
bool IsNewBar(){

   static datetime previousTime = 0;
   datetime currentTime = iTime(_Symbol,PERIOD_CURRENT,0);
   if(previousTime!=currentTime){
      previousTime=currentTime;
      return true;
   }
   return false;
}


//calculate high / low
void calculateHighLow(){
     
     highIdx = iHighest(_Symbol,PERIOD_CURRENT,MODE_HIGH, InpBars, 1);
     lowIdx = iLowest(_Symbol,PERIOD_CURRENT,MODE_LOW, InpBars, 1);
     high = iHigh(_Symbol, PERIOD_CURRENT, highIdx);
     low = iLow(_Symbol, PERIOD_CURRENT,lowIdx);
     
     DrawObjects();
}



// Check for AMS
void checkForAMS(){
        for (int i = highIdx + 1; i < 400 ; ++i)
        {
            double openPrice = iOpen(_Symbol, PERIOD_CURRENT, i);
            double closePrice = iClose(_Symbol, PERIOD_CURRENT, i);
            double lowPrice = iLow(_Symbol, PERIOD_CURRENT, i);
            double highPrice = iHigh(_Symbol, PERIOD_CURRENT, i);
           
            if (closePrice < openPrice)
            {
               
               int countLow =  i - highIdx;
               countLow = countLow + 1;
               
               entryBarLowidx = iLowest(_Symbol,PERIOD_CURRENT,MODE_LOW, countLow, highIdx);
                firstDownBar = iLow(_Symbol, PERIOD_CURRENT, entryBarLowidx); 
                DrawObjects();
                break;
            }
        }
        
         for (int i = lowIdx + 1; i < 400 ; ++i)
        {
            double SopenPrice = iOpen(_Symbol, PERIOD_CURRENT, i);
            double SclosePrice = iClose(_Symbol, PERIOD_CURRENT, i);
            double SlowPrice = iLow(_Symbol, PERIOD_CURRENT, i);
            double ShighPrice = iHigh(_Symbol, PERIOD_CURRENT, i);
           
            if (SclosePrice > SopenPrice)
            {
               
               int ScountLow =  i - lowIdx;
               ScountLow = ScountLow + 1;
               
               entryBarHighidx = iHighest(_Symbol,PERIOD_CURRENT,MODE_HIGH, ScountLow, lowIdx);
                firstUpBar = iHigh(_Symbol, PERIOD_CURRENT, entryBarHighidx); 
                DrawObjects();
                break;
            }
        }
}



// count open posistions
bool CountOpenPositions(int &cntBuy, int &cntSell){

   cntBuy = 0;
   cntSell = 0;
   int total = PositionsTotal();
   for(int i=total-1; i>=0; i--){
      ulong ticket = PositionGetTicket(i);
      if(ticket<=0){Print("Failed to get Posistion ticket in cnt"); return false;}
      
      if(!PositionSelectByTicket(ticket)) {Print("Failed to select position in cnt"); return false;}
      
      long magic;
      if(!PositionGetInteger(POSITION_MAGIC, magic)){Print("Failed to get position magic number"); return false;}
      if(magic==InpMagicNumber){
         long type;
         if(!PositionGetInteger(POSITION_TYPE, type)) {Print("Failed to get position type"); return false;}
         if(type==POSITION_TYPE_BUY) { cntBuy++;}
         if(type==POSITION_TYPE_SELL) { cntSell++;}
      
      }
   }
   
  
   int openTotal = OrdersTotal();
   for(int i=openTotal-1; i>=0; i--){
      ulong ticket = OrderGetTicket(i);
      if(ticket<=0){Print("Failed to get Order ticket"); return false;}
      
      if(!OrderSelect(ticket)) {Print("Failed to select Order", GetLastError()); return false;}
      
      long magic;
      if(!OrderGetInteger(ORDER_MAGIC, magic)){Print("Failed to get Order magic number"); return false;}
      if(magic==InpMagicNumber){
         long type;
         if(!OrderGetInteger(ORDER_TYPE, type)) {Print("Failed to get Order type"); return false;}
         if(type==ORDER_TYPE_BUY_LIMIT) { cntBuy++;}
         if(type==ORDER_TYPE_SELL_LIMIT) { cntSell++;}
      
      }
   }
   return true;
  }
  
  

//check if high/ low is inside valid index range
bool CheckIndexFilter(int index){
   
   if(InpIndexFilter>0 && (index<=round(InpBars*InpIndexFilter*0.01) || index>InpBars-round(InpBars*InpIndexFilter*0.01))){
      
      return false;
   }

return true;
}



//check channel size
bool CheckSizeFilter(){
   
   double size = iClose(_Symbol,PERIOD_CURRENT,1)*(InpSizeFilter/1000);
   if(size>0 && (high-low)<size){
   
      
      return false;
   }

return true;
}



//check entry to high size for short
bool CheckAmsSizeFilterShort(){
   
   double size = iClose(_Symbol,PERIOD_CURRENT,1)*(InpAmsSizeFilter/1000);
   if(size>0 && (high-firstDownBar)<size){
      Print("false: ",(size/_Point), " " , iClose(_Symbol,PERIOD_CURRENT,1));
      return false;
   }
Print("true: ",(size/_Point), " " , iClose(_Symbol,PERIOD_CURRENT,1));
return true;
}



//check entry to low size for long
bool CheckAmsSizeFilterLong(){
   
   double size = iClose(_Symbol,PERIOD_CURRENT,1)*(InpAmsSizeFilter/1000);
   if(size>0 && (firstUpBar-low)<size){
      
      return false;
   }

return true;
}


  
// place sell order
void placeSellOrder(){

         //entry
         double entry = firstDownBar;
         entry = NormalizeDouble(entry,_Digits);
         
         //stop loss
         double sl = high - entry*_Point;
         sl = NormalizeDouble(sl,_Digits);
         
         //take profit
         double tp = 0; 
         if(InpRiskToReward > 0){
         tp = sl - entry;
         tp = tp * InpRiskToReward;
         tp = entry - tp;
         tp = NormalizeDouble(tp,_Digits);
         } else{ tp = 0;}
         
         
         //lots
         double lots = CalculateLots(InpRiskPCT,sl - entry);
         
         //martingale strategy
         if(martinGale){
            lots = lots * martingaleMultiplier;}
         
         //place order
         trade.SellLimit(lots,entry,_Symbol,sl,tp,ORDER_TIME_DAY,0,"order placed");
         
         lastSellEntry = firstDownBar;
}
  
//place buy order
void placeBuyOrder(){
         
         //entry
         double entry = firstUpBar;
         entry = NormalizeDouble(entry,_Digits);
         
         //stop loss
         double sl = low - entry*_Point;
         sl = NormalizeDouble(sl,_Digits);
         
         
         //take profit
         double tp = 0; 
         if(InpRiskToReward > 0){
         tp = entry - sl;
         tp = tp * InpRiskToReward;         
         tp = tp + entry;        
         tp = NormalizeDouble(tp,_Digits);         
         } else{ tp = 0;}
         
         //lots
         double lots = CalculateLots(InpRiskPCT,sl - entry);   
         entry = NormalizeDouble(entry,_Digits);
         double lots2=lots*2;
         lots = lots - lots2;
         
         //? useless normalize maybe?
         sl = NormalizeDouble(sl,_Digits);
         
         //martingale strategy
         if(martinGale){
            lots = lots * martingaleMultiplier;}
         
         //place order
         trade.BuyLimit(lots,entry,_Symbol,sl,tp,ORDER_TIME_DAY,0,"order placed");
         
         lastBuyEntry = firstUpBar;
}


   
// update stop loss

void updateStopLoss(){

            for(int i = PositionsTotal()-1; i>=0; i--){
               ulong posTicket = PositionGetTicket(i);
               if(PositionSelectByTicket(posTicket)){
                  double posSL = PositionGetDouble(POSITION_SL);
                  double posTP = PositionGetDouble(POSITION_TP);
                  
                  if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY){
                     int shift = iLowest(_Symbol,PERIOD_CURRENT,MODE_LOW,InpBars,1);
                     double slLow = iLow(_Symbol,PERIOD_CURRENT,shift);
                     slLow = NormalizeDouble(slLow,_Digits);
                     if(slLow > posSL){
                        if(trade.PositionModify(posTicket,slLow,posTP)){
                           Print("POS:",posTicket, " stop loss was modified + posTP: ", posTP);
                        }
                     }
                     
                     
                  }else if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL){
                    int shift = iHighest(_Symbol,PERIOD_CURRENT,MODE_HIGH,InpBars,1);
                     double slHigh = iHigh(_Symbol,PERIOD_CURRENT,shift);
                     slHigh = NormalizeDouble(slHigh,_Digits);
                     if(slHigh < posSL || posSL == 0){
                        if(trade.PositionModify(posTicket,slHigh,posTP)){
                           Print("POS:",posTicket, " stop loss was modified");
                        }
                     }
                     
                     
                  }
               }
               
            } 
}


 //calculate lots
double CalculateLots(double riskPrecent, double slDistance){
   double risk = 0;
    if(InpFixed){risk = 10000;}else{risk = AccountInfoDouble(ACCOUNT_BALANCE);}
    double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
    double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
    double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
    
    if(tickSize == 0 || tickValue == 0 || lotStep == 0){
      
      return 0;
    }
    
    double riskMoney = risk
    * riskPrecent/100;
    double moneyLotStep = (slDistance / tickSize) * tickValue * lotStep;
    
    if(moneyLotStep ==0){
    Print("Cannot calculate lot size, ==0");
    return 0;
    }
    double lots = MathFloor(riskMoney / moneyLotStep) * lotStep; 
    
    
    return lots;
  }
  
  double PriceToPoints(double currentPrice, double referencePrice) {
    double priceDifference = currentPrice - referencePrice;
    double points = priceDifference / _Point;
    return points;
}



//draw objects
 void DrawObjects() {
   
   datetime time1 = iTime(_Symbol,PERIOD_CURRENT,InpBars);
   datetime time2 = iTime(_Symbol,PERIOD_CURRENT,1);
   
   // high
   ObjectDelete(NULL, "high");
   ObjectCreate(NULL, "high", OBJ_TREND, 0, time1, high, time2, high);
   ObjectSetInteger(NULL, "high", OBJPROP_WIDTH, 2);
   ObjectSetInteger(NULL, "high", OBJPROP_COLOR,CheckIndexFilter(highIdx) && CheckSizeFilter() ? clrBlue : clrBlack);
   
    // low
   ObjectDelete(NULL, "low");
   ObjectCreate(NULL, "low", OBJ_TREND, 0, time1, low, time2, low);
   ObjectSetInteger(NULL, "low", OBJPROP_WIDTH, 2);
   ObjectSetInteger(NULL, "low", OBJPROP_COLOR,CheckIndexFilter(lowIdx) && CheckSizeFilter() ? clrLime : clrBlack);
   
    // first downbar
   ObjectDelete(NULL, "firstDownBar");
   ObjectCreate(NULL, "firstDownBar", OBJ_TREND, 0, time1, firstDownBar, time2, firstDownBar);
   ObjectSetInteger(NULL, "firstDownBar", OBJPROP_WIDTH, 2);
   ObjectSetInteger(NULL, "firstDownBar", OBJPROP_COLOR,CheckIndexFilter(highIdx) && CheckSizeFilter() ? clrBlue : clrBlack);
   
    
    // firstUpBar
   ObjectDelete(NULL, "firstUpBar");
   ObjectCreate(NULL, "firstUpBar", OBJ_TREND, 0, time1, firstUpBar, time2, firstUpBar);
   ObjectSetInteger(NULL, "firstUpBar", OBJPROP_WIDTH, 2);
   ObjectSetInteger(NULL, "firstUpBar", OBJPROP_COLOR,CheckIndexFilter(lowIdx) && CheckSizeFilter() ? clrLime : clrBlack); 
    
    // index filter
    ObjectDelete(NULL, "indexFilter");
    if(InpIndexFilter>0){
    datetime timeIDF1 = iTime(_Symbol,PERIOD_CURRENT,(int) (InpBars-round(InpBars*InpIndexFilter*0.01)));
    datetime timeIDF2 = iTime(_Symbol,PERIOD_CURRENT,(int) (round(InpBars*InpIndexFilter*0.01)));
   ObjectCreate(NULL, "indexFilter", OBJ_RECTANGLE, 0, timeIDF1, low, timeIDF2, low);
   ObjectSetInteger(NULL, "indexFilter", OBJPROP_BACK, true);
   ObjectSetInteger(NULL, "indexFilter", OBJPROP_FILL, true);
   ObjectSetInteger(NULL, "indexFilter", OBJPROP_COLOR,clrAliceBlue);
    } 
    
     // text
   ObjectDelete(NULL, "text");
   ObjectCreate(NULL, "text", OBJ_TEXT, 0, time2, low);
   ObjectSetInteger(NULL, "text", OBJPROP_ANCHOR, ANCHOR_RIGHT_UPPER);
   ObjectSetInteger(NULL, "text", OBJPROP_COLOR, clrBlack);
   ObjectSetString(NULL, "text", OBJPROP_TEXT, "Bars:"+ (string)InpBars+
                                                " index filter:"+ DoubleToString(round(InpBars*InpIndexFilter*0.01),0)+
                                                " high index:" + (string)highIdx+
                                                " low index:"+ (string)lowIdx+
                                                " size:"+ DoubleToString((high-low)/_Point,0));
                                        
       double shortFilter = (high-firstDownBar)/_Point; 
       double longFilter = (firstUpBar-low)/_Point;
       double sizefilter = (iClose(_Symbol,PERIOD_CURRENT,1)*(InpSizeFilter/1000))/_Point; 
       double amssizefilter = (iClose(_Symbol,PERIOD_CURRENT,1)*(InpAmsSizeFilter/1000))/_Point; 
       string com;
      com="\n High - Entry Size:"; 
      com= com+(string)shortFilter;  
      com= com+"\n Entry - Low Size:"; 
      com= com+(string)longFilter; 
      com= com+"\n Size Filter:"+ DoubleToString(sizefilter);
      com= com+"\n AMS Size Filter:"+ DoubleToString(amssizefilter);                                    
      
      Comment(com);
    
}
  
void allowBuy(){

   double openPrice;
   int total = PositionsTotal();
   total = total-1;
   
   
      ulong ticket = PositionGetTicket(total);
      if(ticket<=0){Print("Failed to get Posistion ticket");}
      
      if(!PositionSelectByTicket(ticket)) {Print("Failed to select position in AB");}
      
      long magic;
      if(!PositionGetInteger(POSITION_MAGIC, magic)){Print("Failed to get position magic number");}
      if(magic==InpMagicNumber){
         long type;
         if(!PositionGetInteger(POSITION_TYPE, type)) {Print("Failed to get position type");}
         if(type==POSITION_TYPE_BUY) { 
            
            openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
            if(openPrice < low && lastBuyEntry != firstUpBar){AB= true;} else{AB = false;}
         }
         
      
      }
      
   
   
   }
  
  
  

//allow sell

void allowSell(){

   double openPrice;
   int total = PositionsTotal();
   if(total > 0){
   total = total-1;
   
      
      ulong ticket = PositionGetTicket(total);
      if(ticket<=0){Print("Failed to get Posistion ticket in AS");}
      
      if(!PositionSelectByTicket(ticket)) {Print("Failed to select position");}
      
      long magic;
      if(!PositionGetInteger(POSITION_MAGIC, magic)){Print("Failed to get position magic number");}
      if(magic==InpMagicNumber){
         long type;
         if(!PositionGetInteger(POSITION_TYPE, type)) {Print("Failed to get position type");}
         if(type==POSITION_TYPE_SELL) { 
            
            openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
            if(openPrice > high && lastSellEntry != firstDownBar){AS= true;} else{AS = false;}
         }
         
      
      }
   } else{AS = true;}
   
   
}


//martingale
void martingale(){
 
 int cntLosses = 0;
if (HistorySelect(0, INT_MAX)) {
    for (int i = HistoryDealsTotal() - 1; i >= 0; i--) {
        const ulong Ticket = HistoryDealGetTicket(i);

        if ((HistoryDealGetInteger(Ticket, DEAL_MAGIC) == InpMagicNumber) && (HistoryDealGetString(Ticket, DEAL_SYMBOL) == Symbol())) {
            if (HistoryDealGetDouble(Ticket, DEAL_PROFIT) < (-10)) {
                cntLosses++;}
             if(HistoryDealGetDouble(Ticket, DEAL_PROFIT) > 0) {
                break; // Exit the loop if a profitable trade is encountered
            }
        }
    }
} 
if(cntLosses >= InpMartingaleThreshold){ 
   martingaleMultiplier = cntLosses;
   martinGale = true; } 
   else{ martinGale = false;}
Print("number of losses before a profit: ",cntLosses, " martingale time is ", martinGale, " the multiplier is ", martingaleMultiplier);
   
}




// cycle
void cycle(){

     datetime cycleDate[] = {
     
                         D'2009.11.24', D'2009.12.06' };
              
   
   //todays date
    datetime today = TimeCurrent();
    
    //check if pivot has occured
   if(today >= nextPivot){
      
      pivotFound = false;
   }
   
   // find the current pivot and the pivot after that
   while (pivotFound == false) {
   
    // current point in the cycle sheet
    datetime currentDate = cycleDate[icycle];   
    
    // if today is larger than the point in the cycle sheet set the currentpivot to this date
      if(currentDate <= today) {
         
         currentPivot = currentDate;
         
         waitingForHigh = !waitingForHigh;
         
         icycle++;
         
         // if today is smaller than the point in the cycle sheet, set the nextpivot to this date and break the loop
      } else{ 
         nextPivot = currentDate; 
         pivotFound = true;
         
         }
      
       Print("Current point in sheet:",currentPivot, " Today: ",today, " next pivot:", nextPivot, " waiting for high:",waitingForHigh);
   
}

  
}

