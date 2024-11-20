// for-loop macro
#define for(it, low, high) \
    int it = low; \
    do \
    :: else -> break \
    :: it < high ->

#define rof(it) \
       it++ \
    od

// channel placeholder
#define SENTINEL_CHAN (-1)

// Number of nodes
#define N (2)

typedef MARKER {
    bool owns;
    int LN[N]
}

mtype = { request, marker };
chan ports [N] = [N] of { mtype, byte, int, chan };
// request(sender, n, _), where sender - sender's pid (j), n - RN_j[j]
// marker(_, _, mbuf), where mbuf - buffer with the marker

inline pass_marker(port, token, mbuf) {
    mbuf ! token;
    ports[port] ! marker(0, 0, mbuf)
}

inline request_CS(token, mbuf, RN) {
    byte j;
    int n;
    mtype ingress_mtype;
    if
    :: ! token.owns ->
        RN[_pid]++;
        for(other_pid, 0, N)
            if
            :: other_pid != _pid -> ports[other_pid] ! request(_pid, RN[_pid], SENTINEL_CHAN)
            fi;
        rof(other_pid)
    fi;
    ports[_pid] ? ingress_mtype, j, n, mbuf;
    if
    :: ingress_mtype == marker -> mbuf ? token
    :: ingress_mtype == request ->
       RN[j] = (RN[j] > n -> RN[j] : n);
       if
       :: token.owns && RN[j] == token.LN[j] + 1 -> pass_marker(j, token, mbuf)
       fi
    fi
}

inline enter_CS(token, cs_count) {
    if
    :: token.owns -> atomic { cs_count++ }
    fi
}

inline exit_CS(token, mbuf, RN, Q) {
    byte next_pid;
    if
    :: token.owns ->
       token.LN[_pid] = RN[_pid];
       for (enqueue_pid, 0, N)
          if // random polling (typed [] for using as guard, usually <>)
          :: (Q ?? [eval(enqueue_pid)]) -> skip
          :: else ->
             if
             :: RN[enqueue_pid] == token.LN[enqueue_pid] + 1 ->
                Q ! enqueue_pid
             fi
          fi;
       rof(enqueue_pid);
       if
       :: nempty(Q) ->
          Q ? next_pid;
          pass_marker(next_pid, token, mbuf)
       fi
    fi
}

proctype P(bool owns) {
    chan mbuf = [1] of { MARKER };
    int cs_count = 0;
    int RN[N]; // local sequence numbers of last request
    chan Q = [N] of { byte }; // processes queue
    MARKER token;
    token.owns = owns;
    for(i, 0, N)
        token.LN[i] = 0;
        RN[i] = 0;
    rof(i);
    do
    :: request_CS(token, mbuf, RN);
       enter_CS(token, cs_count);
       exit_CS(token, mbuf, RN, Q)
    od
}

init {
    run P(false);
    run P(true)
}

