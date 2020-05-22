#property strict

// #include <Zmq/Zmq.mqh>

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

int OnInit() {
    //--- create timer
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
    SymbolInfo info = getNext();
    Print("Current bid  for ", info.name, " is ", info.bid, " and current ask is ", info.ask);
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