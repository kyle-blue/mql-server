// #property strict

#include "Include/Zmq/Zmq.mqh"
#include "utils.mq4"

Context context;
Socket main_socket(context, ZMQ_REP);
int main_port = 5555;
Socket* sockets[];
int ports[];
int OnInit() {
    main_socket.bind("tcp://*:" + (string)main_port);
    EventSetMillisecondTimer(1);
    return (INIT_SUCCEEDED);
}

void OnDeinit(const int reason) {}

void OnTick() {
}

Socket new_sock(context, ZMQ_REP);
void OnTimer() {
    ZmqMsg req;
    bool success = main_socket.recv(req, ZMQ_DONTWAIT);
    if (success) {
        Print("Received request '", req.getData(), "' on main socket");
        if (req.getData() == "REQUESTING CONNECTION") {
            int max = find_max(ports);
            if (max == 0) max = main_port;
            int new_port = append(ports, max + 1);
            ZmqMsg res("Connection Accepted\nPort: " + (string)new_port);

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
