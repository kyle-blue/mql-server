#property strict

#include "Include/Zmq/Zmq.mqh"

struct SymbolInfo {
    string name;
    double bid;
    double ask;
};

SymbolInfo getNext() {
    static int index = -1;
    index = (index + 1) % SymbolsTotal(true);

    SymbolInfo info = SymbolInfo();
    info.name = SymbolName(index, true);
    info.bid = MarketInfo(info.name, MODE_BID);
    info.ask = MarketInfo(info.name, MODE_ASK);
    return info;
}

Context context;
Socket socket(context, ZMQ_REP);
int OnInit() {
    //--- create timer
    socket.bind("tcp://*:5555");
    EventSetMillisecondTimer(1);

    return (INIT_SUCCEEDED);
    
}

// void OnDeinit(const int reason)
// {
//   //--- destroy timer
//   // EventKillTimer();
// }

void OnTick() {
}


void OnTimer() {
    //SymbolInfo info = getNext();
    //Print("Current bid  for ", info.name, " is ", info.bid, " and current ask is ", info.ask);
    
      ZmqMsg req;
      socket.recv(req);
      
      Print("Received request ", req.getData());
      
      ZmqMsg res("What's up gamers?!");
      Print("Sending response: ", res.getData());
     
      socket.send(res);
}

// double OnTester()
// {
//   return 1.0;
// }

// void OnChartEvent(const int id,
//                   const long &lparam,
//                   const double &dparam,
//                   const string &sparam)
// {
// }