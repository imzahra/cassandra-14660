# CA14660

## What are we reproducing?
[CA-14660](https://issues.apache.org/jira/browse/CASSANDRA-14660)


This bug is about cluster membership and lock contending with critical path. Here, there is a O(Peers * Tokens) method call 
taking a lock is colliding with the write path, since the lock is protecting the cached tokens necessary for 
determining the correct replicas. This lock comes in the form of a synchronized block in the TokenMetadata class, 
as in:

```
 public TokenMetadata cachedOnlyTokenMap()
    {
        TokenMetadata tm = cachedTokenMap.get();
        if (tm != null)
            return tm;

        // synchronize to prevent thundering herd (CASSANDRA-6345)
        synchronized (this) 
        {
            if ((tm = cachedTokenMap.get()) != null)
                return tm;

            tm = cloneOnlyTokenMap(); // This is BAD...
            cachedTokenMap.set(tm);
            return tm;
        }
    }
```

cloneOnlyTokenMap is callling an expensive function in the SortedBiMultiValMap class, like this:

```
public static <K, V> SortedBiMultiValMap<K, V> create(BiMultiValMap<K, V> map, Comparator<K> keyComparator, Comparator<V> valueComparator) {
        SortedBiMultiValMap<K, V> newMap = create(keyComparator, valueComparator);
        newMap.forwardMap.putAll(map); // O(Peers * Tokens)
        newMap.reverseMap.putAll(map.inverse());
        return newMap;
}
```


As reported, in a cluster with around 1000 nodes (numbers of tokens not reported) waves of requests fail because this process taking too long. 


## How was this fixed?

Here, 3.0.17 is the buggy version and 3.0.18 is the fixed version. The fix is basically reducing the complexity of the operation 
to O(Peers) taking advantage of some properties of the token list and the data structure.

## How to reproduce?

This package includes a script at both 3.0.18 and 3.0.17 folder named do_ycsb.sh. This script will output the thorughput for a 3 node
cluster when running YCSB (also included in the utils directory) with 8 threads. YCSB needs to be uncompressed and put in the directory 
at the same level as the cassandra versions. 

This bug is reproducing by simulating contention on the cached ring. The goal is to similate this write workload while membership is 
changed and its achieved by intrucing an extra 'contention thread'. For configuration, see start-node.sh in both the buggy and fixed version.
We estimated the contention time for a 1000 node cluster as around 500ms using the test included at the benchmark folder. In the fixed version,
the contention is only about 30ms. It still contends though, but less.

A sample output is for the bugyy version is 

```
...
7986
5
5592
2
5112
3
7371
3
4431
3
8760
3
7124
3
6229
5
2617
2
7235
```

meaning that ops per second are heavily falling. For the fixed version

```
...
7453
7835
7729
7340
7799
7910
7583
7535
7947
7616
```

meaning that there is no thorughput fall.

Additionally, the data folder contains scripts to parse the output files and generate plots.
