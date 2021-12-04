#include "postgres.h"
#include "access/attnum.h"
#include "utils/relcache.h"
#include "access/reloptions.h"
#include "access/table.h"
#include "access/relation.h"
#include "access/relscan.h"
#include "access/xact.h"
#include "commands/defrem.h"
#include "funcapi.h"
#include "utils/rel.h"
#include "access/nbtree.h"
#include "commands/vacuum.h"
#include "nodes/makefuncs.h"
#include "catalog/dependency.h"
#include "catalog/pg_operator.h"
#include "catalog/index.h"
#include "catalog/namespace.h"
#include "catalog/storage.h"
#include "utils/lsyscache.h"
#include "utils/typcache.h"
#include "utils/builtins.h"
#include "utils/index_selfuncs.h"
#include "miscadmin.h"
#include "tcop/utility.h"
#include "postmaster/bgworker.h"
#include "pgstat.h"
#include "executor/executor.h"
#include "storage/ipc.h"
#include "storage/latch.h"
#include "storage/lock.h"
#include "storage/lmgr.h"
#include "storage/procarray.h"

#include "lsm.h"

#ifdef PG_MODULE_MAGIC
PG_MODULE_MAGIC;
#endif

PG_FUNCTION_INFO_V1(lsm_handler);

static void lsmInit(lsmInfo* lsmInfoPtr, Relation relTableIndex, int n_items)
{	
	elog(LOG, "Initializing LSM");
	lsmInfoPtr -> relTable = relTableIndex -> rd_index -> indrelid;
	lsmInfoPtr -> l0 = relTableIndex -> rd_id;
	lsmInfoPtr -> l01 = InvalidOid;
	lsmInfoPtr -> l1 = InvalidOid;
	lsmInfoPtr -> l0Full = false;
	lsmInfoPtr -> l01Full = false;

	lsmInfoPtr -> n = n_items;
	lsmInfoPtr -> n0 = 0;
	lsmInfoPtr -> n01 = 0;
	lsmInfoPtr -> db = MyDatabaseId;
	lsmInfoPtr -> user = GetUserId();
	elog(LOG, "LSM Initialized");
}

static void lsmTruncate(Oid relTableIndexOid, Oid relTableOid)
{
	elog(LOG, "Truncation started");
	Relation relTableIndex = index_open(relTableIndexOid, AccessExclusiveLock);
	Relation relTable = table_open(relTableOid, AccessShareLock);

	IndexInfo* relTableIndexInfo = BuildDummyIndexInfo(relTableIndex);
	RelationTruncate(relTableIndex, 0);
	index_build(relTable, relTableIndex, relTableIndexInfo, true, false);
	table_close(relTable, AccessShareLock);
	index_close(relTableIndex, AccessExclusiveLock);
	elog(LOG, "Truncation complete");
}

static void lsmMerge(Oid l0Oid, Oid relTableOid, Oid l1Oid)
{
	elog(LOG,"Merge starting");
	Relation l0 = index_open(l0Oid, 3);
	Relation relTable = table_open(relTableOid, AccessShareLock);
	Relation l1 = index_open(l1Oid, 3);

	Oid tempAm;
	tempAm = l1 -> rd_rel -> relam;
	l1 -> rd_rel -> relam = BTREE_AM_OID;
	IndexScanDesc scan;
	scan = index_beginscan(relTable, l0, SnapshotAny, 0, 0);
	scan -> xs_want_itup = true;
	btrescan(scan, NULL, 0, 0, 0);

	bool items;

	for (items = _bt_first(scan, ForwardScanDirection); items; items = _bt_next(scan, ForwardScanDirection))
	{
		IndexTuple iTup = scan -> xs_itup;
		if (BTreeTupleIsPosting(iTup))
		{
			ItemPointerData saveTid = iTup -> t_tid;
			unsigned short saveInfo = iTup -> t_info;
			iTup -> t_info = (saveInfo & ~(INDEX_SIZE_MASK | INDEX_ALT_TID_MASK)) + BTreeTupleGetPostingOffset(iTup);
			iTup -> t_tid = scan -> xs_heaptid;
			_bt_doinsert(l1, iTup, false, relTable);
			iTup -> t_tid = saveTid;
			iTup -> t_info = saveInfo;
		}
		else
			_bt_doinsert(l1, iTup, false, relTable);
	}

	index_endscan(scan);
	
	l1 -> rd_rel -> relam = tempAm;
	index_close(l0, 3);
	table_close(relTable, AccessShareLock);
	index_close(l1, 3);
	elog(LOG, "Merge completed");
}

IndexBuildResult* lsmBuildIndexL0(Relation relTable, Relation relTableIndex, IndexInfo *relTableIndexInfo)
{
	elog(LOG,"Building LSM Index L0");

	Oid tempAm;
	tempAm = relTableIndex -> rd_rel -> relam;
	relTableIndex -> rd_rel -> relam =  BTREE_AM_OID;
	IndexBuildResult* output;
	output = btbuild(relTable, relTableIndex, relTableIndexInfo);
	relTableIndex -> rd_rel -> relam =  tempAm;

	Buffer buf;
	buf = _bt_getbuf(relTableIndex,  BTREE_METAPAGE, BT_WRITE);
	Page pg;
	pg = BufferGetPage(buf);
	BTMetaPageData* pgBtMeta;
	pgBtMeta = BTPageGetMeta(pg);
	lsmInfo* pgLsmInfo;
	pgLsmInfo = (lsmInfo*)(pgBtMeta+1);

	lsmInit(pgLsmInfo, relTableIndex, output -> index_tuples);

	_bt_relbuf(relTableIndex, buf);

	return output;
}

void lsmBuildIndexL1(Relation relTable, Relation relTableIndex, lsmInfo* lsmInfoPtr){
	
	char* relName;
	relName = relTableIndex -> rd_rel -> relname.data;
	
	char* l1Name;
	l1Name = psprintf("%s_l1", relName);
	
	lsmInfoPtr -> l1 = index_concurrently_create_copy(relTable, relTableIndex -> rd_id, l1Name);
	
	Relation l1;
	l1 = index_open(lsmInfoPtr -> l1, AccessShareLock);
	index_build(relTable, l1, BuildIndexInfo(l1), false, false);
	index_close(l1, AccessShareLock);

}

void lsmBuildIndexL01(Relation relTable, Relation relTableIndex, lsmInfo* lsmInfoPtr){
	
	char* relName;
	relName = relTableIndex -> rd_rel -> relname.data;
	
	char* l01Name;
	l01Name = psprintf("%s_l01", relName);
	
	lsmInfoPtr -> l01 = index_concurrently_create_copy(relTable, relTableIndex -> rd_id, l01Name);
	
	Relation l01;
	l01 = index_open(lsmInfoPtr -> l01, AccessShareLock);
	index_build(relTable, l01, BuildIndexInfo(l01), false, false);
	index_close(l01, AccessShareLock);

}

static bool lsmInsert(Relation relTableIndex, Datum *values, bool *isnull, ItemPointer ht_ctid, Relation relTable, IndexUniqueCheck checkUnique, IndexInfo *relTableIndexInfo)
{	
	elog(LOG, "Inserting in LSM");
	bool output;
	Buffer buf;
	buf = _bt_getbuf(relTableIndex, BTREE_METAPAGE, BT_WRITE);
	Page pg;
	pg = BufferGetPage(buf);
	BTMetaPageData* pgBtMeta;
	pgBtMeta = BTPageGetMeta(pg);
	lsmInfo* pgLsmInfo;
	pgLsmInfo = (lsmInfo*)(pgBtMeta+1);
	if (pgLsmInfo -> l0Full == false){
		elog(LOG, "Inserting in LSM L0");
		_bt_relbuf(relTableIndex, buf);		
		Oid tempAm;
		tempAm = relTableIndex -> rd_rel -> relam;
		relTableIndex -> rd_rel -> relam = BTREE_AM_OID;
		output = btinsert(relTableIndex, values, isnull, ht_ctid, relTable, checkUnique, relTableIndexInfo);
		elog(LOG, "Inserted in LSM L0");
		relTableIndex -> rd_rel -> relam = tempAm;

		buf = _bt_getbuf(relTableIndex, BTREE_METAPAGE, BT_WRITE);
		pg = BufferGetPage(buf);
		pgBtMeta = BTPageGetMeta(pg);
		pgLsmInfo = (lsmInfo*)(pgBtMeta+1);

		pgLsmInfo -> n += 1;
		pgLsmInfo -> n0 += 1;
		if (pgLsmInfo -> n0 == 2)
			pgLsmInfo -> l0Full = true;

		_bt_relbuf(relTableIndex, buf);

		elog(LOG, "Inserted in LSM L0");
	}
	else if (pgLsmInfo -> l01Full == false){
		elog(LOG, "LSM L0 full");
		elog(LOG, "Inserting in LSM L01");
		if (pgLsmInfo -> l01 == InvalidOid){
			elog(LOG, "LSM L01 not created");
			lsmBuildIndexL01(relTable, relTableIndex, pgLsmInfo);
			elog(LOG, "LSM L01 created");
		}

		Relation l01;
		l01 = index_open(pgLsmInfo -> l01, AccessShareLock);

		_bt_relbuf(relTableIndex, buf);
		Oid tempAm;
		tempAm = l01 -> rd_rel -> relam;
		l01 -> rd_rel -> relam = BTREE_AM_OID;
		
		output = btinsert(l01, values, isnull, ht_ctid, relTable, checkUnique, BuildIndexInfo(l01));
		l01 -> rd_rel -> relam = tempAm;
		index_close(l01, AccessShareLock);

		buf = _bt_getbuf(relTableIndex, BTREE_METAPAGE, BT_WRITE);
		pg = BufferGetPage(buf);
		pgBtMeta = BTPageGetMeta(pg);
		pgLsmInfo = (lsmInfo*)(pgBtMeta+1);

		pgLsmInfo -> n += 1;
		pgLsmInfo -> n01 += 1;
		if (pgLsmInfo -> n01 == 2)
			pgLsmInfo -> l01Full = true;

		_bt_relbuf(relTableIndex, buf);
		elog(LOG, "Inserted in LSM L01");
	}
	
	else{
		elog(LOG, "LSM L0 and L01 full");
		elog(LOG, "Inserting in LSM L1");
		lsmInfo* pgLsmInfoTemp;		
		pgLsmInfoTemp = (lsmInfo*)palloc(sizeof(lsmInfo));
		memcpy(pgLsmInfoTemp, pgLsmInfo,sizeof(lsmInfo));
		_bt_relbuf(relTableIndex, buf);
		if (pgLsmInfoTemp -> l1 == InvalidOid){
			elog(LOG, "LSM L1 not created");
			lsmBuildIndexL1(relTable, relTableIndex, pgLsmInfoTemp);
			elog(LOG, "LSM L1 created");
		}

		Relation l01;
		l01 = index_open(pgLsmInfoTemp -> l01, AccessShareLock);
		lsmMerge(pgLsmInfoTemp -> l0, pgLsmInfoTemp -> relTable, pgLsmInfoTemp -> l1); // static void lsmMerge(Oid l0Oid, Oid relTableOid, Oid l1Oid)
		lsmMerge(pgLsmInfoTemp -> l01, pgLsmInfoTemp -> relTable, pgLsmInfoTemp -> l1);
		lsmTruncate(pgLsmInfoTemp -> l0, pgLsmInfoTemp -> relTable); // static void lsmTruncate(Oid relTableIndexOid, Oid relTableOid)
		lsmTruncate(pgLsmInfoTemp -> l01, pgLsmInfoTemp -> relTable);
		index_close(l01, AccessShareLock);

		buf = _bt_getbuf(relTableIndex, BTREE_METAPAGE, BT_WRITE);
		pg = BufferGetPage(buf);
		pgBtMeta = BTPageGetMeta(pg);
		pgLsmInfo = (lsmInfo*)(pgBtMeta+1);
		pgLsmInfo -> n = 0;
		pgLsmInfo -> n01 = 0;
		pgLsmInfo -> n0 = 0;
		pgLsmInfo -> l0Full = false;
		pgLsmInfo -> l01Full = false;
		pgLsmInfo -> user = pgLsmInfoTemp -> user;
		pgLsmInfo -> db = pgLsmInfoTemp -> db;
		pgLsmInfo -> relTable = pgLsmInfoTemp -> relTable;
		pgLsmInfo -> l1 = pgLsmInfoTemp -> l1;
		pgLsmInfo -> l0 = pgLsmInfoTemp -> l0;
		pgLsmInfo -> l01 = pgLsmInfoTemp -> l01;
		_bt_relbuf(relTableIndex, buf);
		pfree(pgLsmInfoTemp);
		elog(LOG, "Inserted in LSM L1");
	}

	elog(LOG, "Insertion complete");
	return output;
}


Datum lsm_handler(PG_FUNCTION_ARGS)
{
	IndexAmRoutine *amroutine;
	amroutine= makeNode(IndexAmRoutine);

	amroutine->amstrategies = BTMaxStrategyNumber;
	amroutine->amsupport = BTNProcs;
	amroutine->amoptsprocnum = BTOPTIONS_PROC;
	amroutine->amcanorder = true;
	amroutine->amcanorderbyop = true;
	amroutine->amcanbackward = true;
	amroutine->amcanunique = false;
	amroutine->amcanmulticol = true;
	amroutine->amoptionalkey = true;
	amroutine->amsearcharray = false;
	amroutine->amsearchnulls = true;
	amroutine->amstorage = false;
	amroutine->amclusterable = true;
	amroutine->ampredlocks = true;
	amroutine->amcanparallel = false;
	amroutine->amcaninclude = true;
	amroutine->amusemaintenanceworkmem = false;
	amroutine->amparallelvacuumoptions = 	VACUUM_OPTION_PARALLEL_BULKDEL | VACUUM_OPTION_PARALLEL_COND_CLEANUP;;
	amroutine->amkeytype = InvalidOid;

	amroutine->ambuild = lsmBuildIndexL0;
	amroutine->ambuildempty = btbuildempty;
	amroutine->aminsert = lsmInsert;
	amroutine->ambulkdelete = btbulkdelete;
	amroutine->amvacuumcleanup = btvacuumcleanup;
	amroutine->amcanreturn = btcanreturn;
	amroutine->amcostestimate = btcostestimate;
	amroutine->amoptions = btoptions;
	amroutine->amproperty = btproperty;
	amroutine->ambuildphasename = btbuildphasename;
	amroutine->amvalidate = btvalidate;
	amroutine->ambeginscan = btbeginscan;
	amroutine->amrescan = btrescan;
	amroutine->amgettuple = btgettuple;
	amroutine->amgetbitmap = btgetbitmap;
	amroutine->amendscan = btendscan;
	amroutine->ammarkpos = NULL;
	amroutine->amrestrpos = NULL;
	amroutine->amestimateparallelscan = NULL;
	amroutine->aminitparallelscan = NULL;
	amroutine->amparallelrescan = NULL;

	PG_RETURN_POINTER(amroutine);
}
