// #property strict

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

void OnDeinit(const int reason) {}
void handleSocketConnections();

void OnTick() {
    if (IsTesting()) {
        handleSocketConnections();

        CJAVal json;
        json["type"] = "MARKET_INFO";

        string time = TimeCurrent();
        string name = Symbol();

        CJAVal s;  // Symbol info
        s["time"] = TimeToString(time, TIME_DATE | TIME_SECONDS);
        s["symbol"] = name;
        s["bid"] = Bid;
        s["ask"] = Ask;  // TODO: NEED TO FIND different way of getting volume, since this is sent nearly every tick. Use CopyTickVolume() ??
        json["symbols"].Add(s);

        if (json.HasKey("symbols")) {
            pub_socket.send(ZmqMsg(json.Serialize()));
        }
    }
}

void handleSocketConnections() {
    ZmqMsg req;
    bool success = main_socket.recv(req, ZMQ_DONTWAIT);
    if (success) {
        Print("Received request '", req.getData(), "' on main socket");
        if (req.getData() == "REQUESTING CONNECTION") {
            int max = find_max(ports);
            if (max == 0) max = main_port;
            int new_port = append(ports, max + 1);
            ZmqMsg res("CONNECTION ACCEPTED\nREQ_PORT: " + (string)new_port + "\nSUB_PORT: " + pub_port + "\n");

            append(sockets, new Socket(context, ZMQ_REP));
            sockets[ArraySize(sockets) - 1].bind("tcp://*:" + (string)new_port);
            main_socket.send(res);
            Print("Connection Accepted on Port " + (string)new_port);
            ArrayPrint(ports);
        }
    }

    for (int i = 0; i < ArraySize(sockets); i++) {
        ZmqMsg req;
        bool success = sockets[i].recv(req, ZMQ_DONTWAIT);
        if (success) {
            Print("Received request '", req.getData(), "' on port " + ports[i]);
            if (req.getData() == "REMOVE CONNECTION") {
                Print("Removing Connection...");
                sockets[i].send(ZmqMsg("OK"));
                sockets[i].disconnect("tcp://*:" + ports[i]);
                delete sockets[i];
                ArrayDelete(ports, i);
                ArrayDelete(sockets, i);
                ArrayPrint(ports);
            }
        }
    }
}

Socket new_sock(context, ZMQ_REP);
CJAVal last;  // Last tick times per symbol
void OnTimer() {
    handleSocketConnections();

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

        CJAVal s;  // Symbol info
        s["symbol"] = name;
        s["bid"] = bid;
        s["ask"] = ask;  // TODO: NEED TO FIND different way of getting volume, since this is sent nearly every tick. Use CopyTickVolume() ??
        s["time"] = TimeToString(time, TIME_DATE | TIME_SECONDS);
        json["symbols"].Add(s);

        l["time"] = time;
        l["bid"] = bid;
        l["ask"] = ask;
    }

    if (json.HasKey("symbols")) {
        pub_socket.send(ZmqMsg(json.Serialize()));
    }
}
