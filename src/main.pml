// for-loop macro
#define for(it, low, high) \
    int it = low; \
    do \
    :: else -> break \
    :: it < high ->

#define rof(it) \
       it++ \
    od

// Number of nodes
#define N (2)

typedef MARKER {
    bool owns;
    int LN[N]
}

chan requests [N] = [0] of { byte, int, chan };

inline request_CS(marker, RN, ireply, jreply) {
    byte j;
    int n;
    if
    :: ! marker.owns ->
        RN[_pid]++;
        for(_i, 0, N)
            if
            :: _i != _pid -> requests[_i] ! _pid, RN[_pid], ireply
            fi;
        rof(_i)
    fi;
    requests[_pid] ? j, n, jreply;
    RN[j] = (RN[j] > n -> RN[j] : n);
    if
    :: marker.owns && RN[j] == marker.LN[j] + 1 -> jreply ! marker
    fi
}

inline enter_CS(marker, cs_count) {
    if
    :: marker.owns -> atomic { cs_count++ }
    fi
}

inline exit_CS(marker, Q, RN) {
    byte next_pid;
    if
    :: marker.owns ->
        marker.LN[_pid] = RN[_pid];
        // TODO: add only pids that are not presented in Q
        for (_i, 0, N)
            if
            :: RN[_i] == marker.LN[_i] + 1 -> Q ! _i
            fi;
        rof(_i);
        if
        :: nempty(Q) ->
            Q ? next_pid;
            // TODO: pass token to next pid
        fi
    fi
}

proctype P(bool owns) {
    chan ireply = [0] of { MARKER };
    chan jreply = [0] of { MARKER };
    int cs_count = 0;
    int RN[N]; // local sequence numbers of last request
    chan Q = [N] of { byte }; // processes queue
    MARKER marker;
    marker.owns = owns;
    for(i, 0, N)
        marker.LN[i] = 0;
        RN[i] = 0;
    rof(i);
    do
    :: request_CS(marker, RN, ireply, jreply); enter_CS(marker, cs_count); exit_CS(marker, Q, RN)
    od
}

init {
    run P(true)
    run P(false);
}

