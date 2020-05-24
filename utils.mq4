// template <typename T>
// T *append(T &array[], T *item) {
//     int size = ArraySize(array);
//     ArrayResize(array, size + 1);
//     array[size] = item;
//     return &array[size];
// }
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

template <typename T>
void ArrayDelete(T &array[], int index) {
    int size = ArraySize(array);
    if (index < 0 || index >= size) return;

    for (int i = index; i < size - 1; i++) {
        array[i] = array[i + 1];
    }
    ArrayResize(array, size - 1);
}

template <typename T>
void ArrayPrint(T &array[]) {
    string x = "";
    for (int i = 0; i < ArraySize(array); i++) {
        x += (string)array[i] + ", ";
    }
    Print(x);
}