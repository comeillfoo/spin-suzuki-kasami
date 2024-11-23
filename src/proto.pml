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

typedef procstate_t {
   int RN[N] // local sequence numbers of last request
};

procstate_t pstates[N];
byte cpid = 0;

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
        :: token.owner == cpid ->
           token.owner = next_owner
        fi
    }
}

inline handle_requests() {
    byte j;
    int n;
    requests[cpid] ? j, n;
    pstates[cpid].RN[j] = (pstates[cpid].RN[j] > n -> pstates[cpid].RN[j] : n);
    if
    :: else -> skip
    :: pstates[cpid].RN[j] == token.LN[j] + 1 ->
       try_pass_marker(j)
    fi
}

inline request_CS() {
    if
    :: else -> skip
    :: token.owner != cpid ->
       pstates[cpid].RN[cpid]++;
       for(other_pid, 0, N)
           if
           :: else -> skip
           :: other_pid != cpid ->
              requests[other_pid] ! cpid, pstates[cpid].RN[cpid]
           fi;
       rof(other_pid)
    fi
}

inline enter_CS() {
    if
    :: else -> skip
    :: token.owner == cpid ->
       cs_flags[cpid] = true;
       at_cs++;
       cs_mask = cs_mask | (1 << cpid);
       assert (at_cs <= 1);
       at_cs--;
       cs_flags[cpid] = false
    fi
}

inline exit_CS() {
    byte next_pid;
    if
    :: else -> skip
    :: token.owner == cpid ->
       token.LN[cpid] = pstates[cpid].RN[cpid];
       for (enqueue_pid, 0, N)
          if // random polling (typed [] for using as guard, usually <>)
          :: enqueue_pid == cpid || (token.Q ?? [eval(enqueue_pid)]) -> skip
          :: else ->
             if // changed this because SPIN causes other processes to starve
             :: pstates[cpid].RN[enqueue_pid] == token.LN[enqueue_pid] + 1 ->
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
          assert (pstates[cpid].RN[next_pid] == token.LN[next_pid] + 1);
          try_pass_marker(next_pid)
       fi
    fi
}

active proctype Protocol() {
end:
    do
    :: if
       :: nempty(requests[cpid]) -> handle_requests()
       :: empty(requests[cpid]) ->
          request_CS();
          enter_CS();
          exit_CS()
       fi;
       cpid = (cpid + 1) % N // dispatch next process
    od
}

ltl cs_prop { [](at_cs <= 1) }
ltl only_owner_in_cs { []((at_cs == 1) -> cs_flags[token.owner]) }
ltl finite_token_queue { [](len(token.Q) <= (N - 1)) }
ltl finite_nr_requests { [](len(requests[token.owner]) <= (N - 1)) }

ltl liveness { <>(cs_mask + 1 == (1 << N)) }
