// #property strict

#include <stdlib.mqh>

#include "Include/JAson.mqh"
#include "Include/Zmq/Zmq.mqh"
#include "utils.mq4"

Context context;
Socket main_socket(context, ZMQ_REP);
Socket pub_socket(context, ZMQ_PUB);  // Publish
int main_port = 25001;
int pub_port = 25000;
Socket* sockets[];
int ports[];
int OnInit() {
    main_socket.bind("tcp://*:" + (string)main_port);
    pub_socket.bind("tcp://*:" + (string)pub_port);
    EventSetMillisecondTimer(1);
    return (INIT_SUCCEEDED);
}

void sendData();
void OnDeinit(const int reason) {}
void handleSocketConnections();

void OnTick() {
    if (IsTesting()) {
        handleSocketConnections();
        sendData();
    }
}

void removeSocket(int i) {
    CJAVal res;
    res["type"] = "REMOVE SUCCESS";
    Print("Removing Connection...");
    sockets[i].send(res.Serialize());
    sockets[i].disconnect("tcp://*:" + ports[i]);
    delete sockets[i];
    ArrayDelete(ports, i);
    ArrayDelete(sockets, i);
    ArrayPrint(ports);
}

void openTrade(CJAVal& tradeInfo, Socket& socket) {
    color arrowColor;
    int op = tradeInfo["type"].ToInt();
    if (op == OP_BUY || op == OP_BUYLIMIT || op == OP_BUYSTOP)
        arrowColor = clrLimeGreen;
    else
        arrowColor = clrCrimson;

    int ret = OrderSend(tradeInfo["symbol"].ToStr(), op, tradeInfo["lots"].ToDbl(), tradeInfo["price"].ToDbl(), tradeInfo["maxSlippage"].ToInt(), tradeInfo["stopLoss"].ToDbl(), tradeInfo["takeProfit"].ToDbl(), tradeInfo["comment"].ToStr(), 0, 0, arrowColor);

    CJAVal tradeRes;
    tradeRes["ticket"] = ret;
    if (ret == -1) {
        int errorCode = GetLastError();
        tradeRes["errorCode"] = errorCode;
        tradeRes["errorDesc"] = ErrorDescription(errorCode);
    } else {
        OrderSelect(ret, SELECT_BY_TICKET);
        tradeRes["openPrice"] = OrderOpenPrice();
        tradeRes["openTime"] = TimeToStr(OrderOpenTime(), TIME_DATE | TIME_SECONDS);
    }
    socket.send(tradeRes.Serialize());
}

void closeTrade(CJAVal& tradeInfo, Socket& socket) {
    string ticket = tradeInfo["ticket"].ToStr();
    double lots = tradeInfo["lots"].ToDbl();
    double price = tradeInfo["price"].ToDbl();
    int slippage = tradeInfo["maxSlippage"].ToInt();

    OrderSelect(ticket, SELECT_BY_TICKET);

    color arrowColor;
    int op = OrderType();
    if (op == OP_BUY || op == OP_BUYLIMIT || op == OP_BUYSTOP)
        arrowColor = clrCrimson;
    else
        arrowColor = clrLimeGreen;

    Print(slippage);
    bool ret = OrderClose(ticket, lots, price, slippage, arrowColor);
    if (!ret) ret = OrderDelete(ticket, arrowColor);

    CJAVal tradeRes;
    if (!ret) {
        int errorCode = GetLastError();
        tradeRes["errorCode"] = errorCode;
        tradeRes["errorDesc"] = ErrorDescription(errorCode);
    } else {
        tradeRes["closePrice"] = OrderClosePrice();
        tradeRes["closeTime"] = TimeToStr(OrderCloseTime(), TIME_DATE | TIME_SECONDS);
    }
    socket.send(tradeRes.Serialize());
}

void modifyTrade(CJAVal& tradeInfo, Socket& socket) {
    string ticket = tradeInfo["ticket"].ToStr();
    double price = tradeInfo["price"].ToDbl();
    double stopLoss = tradeInfo["stopLoss"].ToDbl();
    double takeProfit = tradeInfo["takeProfit"].ToDbl();

    bool ret = OrderModify(ticket, price, stopLoss, takeProfit, 0);

    string retString = "{}";
    CJAVal tradeRes;
    if (!ret) {
        int errorCode = GetLastError();
        tradeRes["errorCode"] = errorCode;
        tradeRes["errorDesc"] = ErrorDescription(errorCode);
        retString = tradeRes.Serialize();
    } else {
    }
    socket.send(retString);
}

void getStaticInfo(Socket& socket) {
    CJAVal json;
    json["type"] = "MARKET_INFO";
    for (int i = 0; i < SymbolsTotal(true); i++) {
        string name = SymbolName(i, true);
        double minLot = MarketInfo(name, MODE_MINLOT);
        double tickSize = MarketInfo(name, MODE_TICKSIZE);

        CJAVal s;  // Symbol info
        s["name"] = name;
        s["tickSize"] = tickSize;
        s["minLot"] = minLot;

        json["symbols"].Add(s);
    }
    CJAVal a;               // account info
    a["commission"] = 6.0;  // 6 dollars for blackbullmarkets
    a["leverage"] = AccountInfoInteger(ACCOUNT_LEVERAGE);
    json["account"].CopyData(a);
    socket.send(json.Serialize());
}

void handleSocketConnections() {
    ZmqMsg reqMsg;
    bool success = main_socket.recv(reqMsg, ZMQ_DONTWAIT);
    if (success) {
        Print("Received request '", reqMsg.getData(), "' on main socket");
        CJAVal req;
        req.Deserialize(reqMsg.getData());

        if (req["type"].ToStr() == "REQUEST CONNECTION") {
            int max = find_max(ports);
            if (max == 0) max = main_port;
            int new_port = append(ports, max + 1);

            CJAVal res;
            res["req_port"] = new_port;
            res["sub_port"] = pub_port;

            append(sockets, new Socket(context, ZMQ_REP));
            sockets[ArraySize(sockets) - 1].bind("tcp://*:" + (string)new_port);
            main_socket.send(res.Serialize());
            Print("Connection Accepted on Port " + (string)new_port);
            ArrayPrint(ports);
        }
    }

    for (int i = 0; i < ArraySize(sockets); i++) {
        ZmqMsg reqMsg;
        bool success = sockets[i].recv(reqMsg, ZMQ_DONTWAIT);
        if (success) {
            Print("Received request '", reqMsg.getData(), "' on port " + ports[i]);

            CJAVal req;
            req.Deserialize(reqMsg.getData());
            if (req["type"].ToStr() == "REMOVE CONNECTION")
                removeSocket(i);
            else if (req["type"].ToStr() == "OPEN TRADE")
                openTrade(req["data"], sockets[i]);
            else if (req["type"].ToStr() == "CLOSE TRADE")
                closeTrade(req["data"], sockets[i]);
            else if (req["type"].ToStr() == "MODIFY TRADE")
                modifyTrade(req["data"], sockets[i]);
            else if (req["type"].ToStr() == "GET STATIC INFO")
                getStaticInfo(sockets[i]);
        }
    }
}

void sendData() {
    // TODO: Send one-time (or infrequent) info, such as MODE_MINLOT, MODE_MAXLOT, MODE_LOTSIZE, MODE_TICKVALUE, MODE_LOTSTEP
    // ANND stuff like ACCOUNT_LEVERAGE, ACCOUNT_BALANCE, ACCOUNT_EQUITY, ACCOUNT_MARGIN .....
    CJAVal json;
    json["type"] = "MARKET_INFO";
    last["type"] = "LAST";
    for (int i = 0; i < SymbolsTotal(true); i++) {
        string name = SymbolName(i, true);
        int time = SymbolInfoInteger(name, SYMBOL_TIME);
        double bid = SymbolInfoDouble(name, SYMBOL_BID);
        double ask = SymbolInfoDouble(name, SYMBOL_ASK);

        CJAVal* l = last[name];
        if (time == l["time"].ToInt() && bid == l["bid"].ToDbl() && ask == l["ask"].ToDbl()) {
            continue;  // SAME TICK AS BEFORE... SKIP
        }
        double tickValue = MarketInfo(name, MODE_TICKVALUE);

        CJAVal s;  // Symbol info
        s["symbol"] = name;
        s["bid"] = bid;
        s["ask"] = ask;  // TODO: NEED TO FIND different way of getting volume, since this is sent nearly every tick. Use CopyTickVolume() ??
        s["time"] = TimeToString(time, TIME_DATE | TIME_SECONDS);
        s["tickValue"] = tickValue;

        json["symbols"].Add(s);

        l["time"] = time;
        l["bid"] = bid;
        l["ask"] = ask;
    }

    if (json.HasKey("symbols")) {  // Something has changed
        CJAVal a;                  // account info
        a["equity"] = AccountInfoDouble(ACCOUNT_EQUITY);
        a["balance"] = AccountInfoDouble(ACCOUNT_BALANCE);
        a["freeMargin"] = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
        json["account"].CopyData(a);
        pub_socket.send(ZmqMsg(json.Serialize()));
    }
}

Socket new_sock(context, ZMQ_REP);
CJAVal last;  // Last tick times per symbol
void OnTimer() {
    handleSocketConnections();

    for (int i = 0; i < ArraySize(sockets); i++) {
        ZmqMsg req;
        bool success = sockets[i].recv(req, ZMQ_DONTWAIT);
        if (success) {
            Print("Received request '", req.getData(), "' on port " + ports[i]);
        }
    }

    sendData();
}
