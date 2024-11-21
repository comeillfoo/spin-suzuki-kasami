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
#define DEFAULT_OWNER (0)

typedef MARKER {
    byte owner = DEFAULT_OWNER;
    int LN[N]
};

MARKER token;
int cs_counts [N];
int cs_flags [N];
byte at_cs = 0;
chan requests [N] = [N] of { byte, int };
// request(sender, n, _), where sender - sender's pid (j), n - RN_j[j]
// marker(_, _, mbuf), where mbuf - buffer with the marker

inline try_pass_marker(next_owner) {
    atomic {
        if
        :: else -> skip
        :: token.owner == _pid ->
           token.owner = next_owner
        fi
    }
}

inline request_CS(RN) {
    byte j;
    int n;
    if
    :: else -> skip
    :: token.owner != _pid ->
       RN[_pid]++;
       for(other_pid, 0, N)
           if
           :: else -> skip
           :: other_pid != _pid ->
              requests[other_pid] ! _pid, RN[_pid]
           fi;
       rof(other_pid)
    fi;
    if
    :: empty(requests[_pid]) -> skip
    :: nempty(requests[_pid]) ->
       requests[_pid] ? j, n;
       RN[j] = (RN[j] > n -> RN[j] : n);
       if
       :: else -> skip
       :: RN[j] == token.LN[j] + 1 ->
          try_pass_marker(j)
       fi
    fi
}

inline enter_CS() {
    if
    :: else -> skip
    :: token.owner == _pid ->
       cs_flags[_pid] = true;
       at_cs++;
       cs_counts[_pid]++;
       assert (at_cs <= 1);
       at_cs--;
       cs_flags[_pid] = false
    fi
}

inline exit_CS(RN, Q) {
    byte next_pid;
    if
    :: else -> skip
    :: token.owner == _pid ->
       token.LN[_pid] = RN[_pid];
       for (enqueue_pid, 0, N)
          if // random polling (typed [] for using as guard, usually <>)
          :: (Q ?? [eval(enqueue_pid)]) -> skip
          :: else ->
             if
             :: else -> skip
             :: RN[enqueue_pid] == token.LN[enqueue_pid] + 1 ->
                Q ! enqueue_pid
             fi
          fi;
       rof(enqueue_pid);
       if
       :: empty(Q) -> skip
       :: nempty(Q) ->
          Q ? next_pid;
          try_pass_marker(next_pid)
       fi
    fi
}

active [N] proctype P() {
    int RN[N]; // local sequence numbers of last request
    chan Q = [N] of { byte }; // processes queue
    cs_counts[_pid] = 0;
    do
    :: request_CS(RN);
       enter_CS();
       exit_CS(RN, Q)
    od
}

ltl cs_prop { [](at_cs <= 1) }
ltl only_token_owner_in_cs { []((at_cs == 1) -> cs_flags[token.owner]) }
