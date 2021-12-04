#include "access/nbtree.h"
typedef struct
{
	Oid relTable;
	Oid l0;
	Oid l01;
	bool l0Full;
	bool l01Full;

	Oid l1;
	int n;
	int n0;
	int n01;
	Oid user;
	Oid db;
	
} lsmInfo;
