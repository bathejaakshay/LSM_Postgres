# LSM Tree indexing
## _Implementing LSM Tree indexing in Postgres 13_

Log-structured merge(LSM) tree based indexing is a technique used to provide high  write  throughput.   The  main  reason  why  LSM  trees  provide  high  writethroughput is,  it requires less number of disk I/O operations.
For instance if we compare them with B-Tree, the B-Tree index can be poor for write intensive workload.  They can take one I/O per leaf (assuming all internal nodes are in memory).   Whereas in  LSM tree  every  write  request is  performed  in-memory and disk I/O is initiated once the in-memory component(s) are full.

## Installation

This extension of LSM Trees requires [Postgres](https://www.postgresql.org/) v9+ to run.

Make sure postgres installation path is already added in the system path. If not run the following commands in the _bash_ shell:

```sh
export PATH=$POSTGRES_INSTALLDIR/bin:$PATH
export PG_CONFIG=$POSTGRES_INSTAlLDIR/bin/pg_config
```

Then copy the lsm extension to the _/contrib_ directory

```sh
cp -a ./lsm $POSTGRES_SRCDIR/../contrib && cd $POSTGRES_SRCDIR/../contrib
```
Now perform following commands to install the extension
```sh
make && make install
```
## A Guide to use this extension
Make sure that you have installed the lsm extension by following the steps given above. 
Now we can discus how to see if Postgres is actually using lsm index for the sql query submitted.
#### NOTE
If you perform any scan query and want to explain the query, make sure that sequential scanning is off, so that the POSTGRES query planer doesn't use sequentional scans by default.
Now run the Postgres project and input the following commands.

- Register the index using the following sql command;
    ```sql
    CREATE EXTENSION lsm;
    ```
- Now create a dummy table and create an index over the table using the installed extenstion.
    ```sql
    CREATE Table teacher(i int, k int);
    CREATE INDEX ind ON teacher USING lsm(i);
    ```
- Now we will look at the steps of stepped-merge tree indexing , perform Inserts and explain what happens on each insert. 
- We have a two level stepped-merged tree index, where top level consists of two btrees _L00_ and _L01_, and base index consist of one btree _L1_. The max_size for both of the top indices is two.
    ```sql
    INSERT INTO teacher VALUES (1,1);
    INSERT INTO teacher VALUES (2,2);
    ```
- The first two inserts go to the index _L00_.
    ```sql
    INSERT INTO teacher VALUES (3,3);
    INSERT INTO teacher VALUES (4,4);
    ```
- The next two inserts will build the index L01 and insert both into that index. - Now both _L00_ and _L01_ have reached their max_size.
    ```sql
    INSERT INTO teacher VALUES (5,5);
    ```
- Now, the 5th insert builds the L1 btree and inserts the key into that. It also performs a merge operation between _L00_ , _L01_ and _L1_. Now _L00_ and _L01_ are truncated and built again automatically.

- Now to see if lsm is actually used, execute the following sql commands.
    ```sql
    ANALYSE;
    SELECT * FROM teacher WHERE id > 0;
    ```
- This command will show that Postgres uses an index scan over the table _teacher_ using the index _ind_ that we created.

## License

IIT Bombay
