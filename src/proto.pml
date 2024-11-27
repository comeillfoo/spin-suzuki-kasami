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
#ifndef N
#define N (2)
#endif

// Default owner
#ifndef DEFAULT_OWNER
#define DEFAULT_OWNER (1)
#endif

typedef token_t {
   byte owner = DEFAULT_OWNER;
   int LN[N];
   chan Q = [N + N / 2] of { byte } // processes queue
};

token_t token;
int cs_flags [N];
byte at_cs = 0;
int cs_mask = 0;
chan requests [N] = [N] of { byte, int }; // sender's pid (j), n - RN_j[j]

inline try_pass_marker(next_owner) {
    atomic {
        if
        :: else -> skip
        :: token.owner == _pid ->
           token.owner = next_owner
        fi
    }
}

inline handle_requests(RN) {
    byte j;
    int n;
    requests[_pid] ? j, n;
    RN[j] = (RN[j] > n -> RN[j] : n);
    if
    :: else -> skip
    :: RN[j] == token.LN[j] + 1 ->
       try_pass_marker(j)
    fi
}

inline request_CS(RN) {
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
    fi
}

inline enter_CS() {
    if
    :: token.owner == _pid ->
       cs_flags[_pid] = true;
       at_cs++;
       cs_mask = cs_mask | (1 << _pid);
       assert (at_cs <= 1);
       at_cs--;
       cs_flags[_pid] = false
    fi
}

inline exit_CS(RN) {
    byte next_pid;
    if
    :: else -> skip
    :: token.owner == _pid ->
       token.LN[_pid] = RN[_pid];
       for (enqueue_pid, 0, N)
          if // random polling (typed [] for using as guard, usually <>)
          :: enqueue_pid == _pid || (token.Q ?? [eval(enqueue_pid)]) -> skip
          :: else ->
             if // changed this because SPIN causes other processes to starve
             :: RN[enqueue_pid] <= token.LN[enqueue_pid] + 1 ->
                token.Q ! enqueue_pid
             :: else -> skip
             fi
          fi;
       rof(enqueue_pid);
       if
       :: empty(token.Q) -> skip
       :: nempty(token.Q) ->
          token.Q ? next_pid;
          // changed this because SPIN causes other processes to starve
          assert (RN[next_pid] <= token.LN[next_pid] + 1);
          try_pass_marker(next_pid)
       fi
    fi
}

active [N] proctype P() {
    int RN[N]; // local sequence numbers of last request
end:
    do
    :: if
       :: nempty(requests[_pid]) -> handle_requests(RN)
       :: empty(requests[_pid]) ->
          // changed this because SPIN causes other processes to starve
          if // block token owner on handling request in order to force SPIN to dispatch others
          :: token.owner == _pid -> handle_requests(RN)
          :: else -> skip
          fi;
          request_CS(RN);
          enter_CS();
          exit_CS(RN)
       fi
    od
}

ltl cs_prop { [](at_cs <= 1) }
ltl only_owner_in_cs { []((at_cs == 1) -> cs_flags[token.owner]) }
ltl finite_token_queue { [](len(token.Q) <= N) }
ltl liveness { <>(cs_mask + 1 == (1 << N)) }
