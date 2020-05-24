// #property strict

#include "Include/Zmq/Zmq.mqh"

template <typename T>
T *append(T &array[], T &item) {
    int size = ArraySize(array);
    ArrayResize(array, size + 1);
    array[size] = item;
    return &array[size];
}
template <typename T>
T append(T &array[], T item) {
    int size = ArraySize(array);
    ArrayResize(array, size + 1);
    array[size] = item;
    return array[size];
}

template <typename T>
T find_max(T &array[]) {
    T max = T();
    for (int i = 0; i < ArraySize(array); i++) {
        if (array[i] > max) {
            max = array[i];
        }
    }
    return max;
}

Context context;
Socket main_socket(context, ZMQ_REP);
Socket sockets[];
int ports[] = {5555};
ZmqMsg req("");
int OnInit() {
    //--- create timer
    main_socket.bind("tcp://*:" + (string)ports[0]);
    EventSetMillisecondTimer(1);
    return (INIT_SUCCEEDED);
}

void OnDeinit(const int reason) {}

void OnTick() {
    ZmqMsg info("poop");
    for (int i = 0; i < ArraySize(sockets); i++) {
        Socket *s = &sockets[i];
        s.send(info);
    }
}

void OnTimer() {
    bool success = main_socket.recv(req, ZMQ_DONTWAIT);
    if (success) {
        Print("Received request '", req.getData(), "'");
        if (req.getData() == "Requesting Connection") {
            int new_port = append(ports, find_max(ports) + 1);
            ZmqMsg res("Connection Accepted\nPort: " + (string)new_port);
            Socket *p_socket = append(sockets, Socket(context, ZMQ_REP));
            p_socket.bind("tcp://*:" + (string)new_port);
            Print("Connection Accepted on Port " + (string)new_port);
            main_socket.send(res);
        } else if (StringFind(req.getData(), "Remove Connection") != -1) {
            Print("Removing Connection...");
            // TODO: Remove Connection
        }
    }
}
