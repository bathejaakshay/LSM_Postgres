-- 
CREATE OR REPLACE FUNCTION lsm_handler(internal)
RETURNS index_am_handler
AS 'MODULE_PATHNAME'
LANGUAGE C;

CREATE ACCESS METHOD lsm TYPE INDEX HANDLER lsm_handler;
--Comparision functions are defined in src/backend/access/nbtree/nbtcompare.c

-- operator family create for cross datatype oprerands and null values it is alter later in file
CREATE OPERATOR FAMILY integer_ops USING lsm;
-- Operator class to compare int2 operands it use existing btree oprator function btint2cmp
-- operator class defines operators to be used index of a column
CREATE OPERATOR CLASS int2_ops DEFAULT
	FOR TYPE int2 USING lsm FAMILY integer_ops AS
	OPERATOR 1  <,
	OPERATOR 2  <=,
	OPERATOR 3  =,
	OPERATOR 4  >=,
	OPERATOR 5  >,
	FUNCTION 1  btint2cmp(int2,int2);

-- Operator class to compare int4 operands it use exicting btree oprator function btint4cmp
CREATE OPERATOR CLASS int4_ops DEFAULT
	FOR TYPE int4 USING lsm FAMILY integer_ops AS
	OPERATOR 1  <,
	OPERATOR 2  <=,
	OPERATOR 3  =,
	OPERATOR 4  >=,
	OPERATOR 5  >,
	FUNCTION 1  btint4cmp(int4,int4);
-- Operator class to compare int8 operands it use exicting btree oprator function btint8cmp
CREATE OPERATOR CLASS int8_ops DEFAULT
	FOR TYPE int8 USING lsm FAMILY integer_ops AS
	OPERATOR 1  <,
	OPERATOR 2  <=,
	OPERATOR 3  =,
	OPERATOR 4  >=,
	OPERATOR 5  >,
	FUNCTION 1  btint8cmp(int8,int8);
-- Operator class family to compare int2 operands it use exicting btree oprator function btint2cmp
ALTER OPERATOR FAMILY integer_ops USING lsm ADD
	OPERATOR 1  < (int2,int4),
	OPERATOR 1  < (int2,int8),
	OPERATOR 1  < (int4,int2),
	OPERATOR 1  < (int4,int8),
	OPERATOR 1  < (int8,int2),
	OPERATOR 1  < (int8,int4),

	OPERATOR 2  <= (int2,int4),
	OPERATOR 2  <= (int2,int8),
	OPERATOR 2  <= (int4,int2),
	OPERATOR 2  <= (int4,int8),
	OPERATOR 2  <= (int8,int2),
	OPERATOR 2  <= (int8,int4),

	OPERATOR 3  = (int2,int4),
	OPERATOR 3  = (int2,int8),
	OPERATOR 3  = (int4,int2),
	OPERATOR 3  = (int4,int8),
	OPERATOR 3  = (int8,int2),
	OPERATOR 3  = (int8,int4),

	OPERATOR 4  >= (int2,int4),
	OPERATOR 4  >= (int2,int8),
	OPERATOR 4  >= (int4,int2),
	OPERATOR 4  >= (int4,int8),
	OPERATOR 4  >= (int8,int2),
	OPERATOR 4  >= (int8,int4),

	OPERATOR 5  > (int2,int4),
	OPERATOR 5  > (int2,int8),
	OPERATOR 5  > (int4,int2),
	OPERATOR 5  > (int4,int8),
	OPERATOR 5  > (int8,int2),
	OPERATOR 5  > (int8,int4),

	FUNCTION 1(int2,int4)  btint24cmp(int2,int4),
	FUNCTION 1(int2,int8)  btint28cmp(int2,int8),
	FUNCTION 1(int4,int2)  btint42cmp(int4,int2),
	FUNCTION 1(int4,int8)  btint48cmp(int4,int8),
	FUNCTION 1(int8,int4)  btint84cmp(int8,int4),
	FUNCTION 1(int8,int2)  btint82cmp(int8,int2),

	FUNCTION 2(int2,int2)  btint2sortsupport(internal),
	FUNCTION 2(int4,int4)  btint4sortsupport(internal),
	FUNCTION 2(int8,int8)  btint8sortsupport(internal),

    FUNCTION 3(int2,int8)  in_range(int2,int2,int8,bool,bool),
    FUNCTION 3(int2,int4)  in_range(int2,int2,int4,bool,bool),
    FUNCTION 3(int2,int2)  in_range(int2,int2,int2,bool,bool),
    FUNCTION 3(int4,int8)  in_range(int4,int4,int8,bool,bool),
    FUNCTION 3(int4,int4)  in_range(int4,int4,int4,bool,bool),
    FUNCTION 3(int4,int2)  in_range(int4,int4,int2,bool,bool),
    FUNCTION 3(int8,int8)  in_range(int8,int8,int8,bool,bool),

    FUNCTION 4(int2,int2)  btequalimage(oid),
    FUNCTION 4(int4,int4)  btequalimage(oid),
    FUNCTION 4(int8,int8)  btequalimage(oid);
-- Operator class family for float operands
CREATE OPERATOR FAMILY float_ops USING lsm;
-- Operator class to compare float4 operands it use exicting btree oprator function btfloat4cmp
CREATE OPERATOR CLASS float4_ops DEFAULT
	FOR TYPE float4 USING lsm FAMILY float_ops AS
	OPERATOR 1  <,
	OPERATOR 2  <=,
	OPERATOR 3  =,
	OPERATOR 4  >=,
	OPERATOR 5  >,
	FUNCTION 1  btfloat4cmp(float4,float4);
-- Operator class to compare float8 operands it use exicting btree oprator function btfloat8cmp
CREATE OPERATOR CLASS float8_ops DEFAULT
	FOR TYPE float8 USING lsm FAMILY float_ops AS
	OPERATOR 1  <,
	OPERATOR 2  <=,
	OPERATOR 3  =,
	OPERATOR 4  >=,
	OPERATOR 5  >,
	FUNCTION 1  btfloat8cmp(float8,float8);

-- Operator class family for cross float operators not left operator is always indexed operator
ALTER OPERATOR FAMILY float_ops USING lsm ADD
	OPERATOR 1  < (float4,float8),
	OPERATOR 1  < (float8,float4),

	OPERATOR 2  <= (float4,float8),
	OPERATOR 2  <= (float8,float4),

	OPERATOR 3  = (float4,float8),
	OPERATOR 3  = (float8,float4),

	OPERATOR 4  >= (float4,float8),
	OPERATOR 4  >= (float8,float4),

	OPERATOR 5  > (float4,float8),
	OPERATOR 5  > (float8,float4),

	FUNCTION 1(float4,float8)  btfloat48cmp(float4,float8),
	FUNCTION 1(float8,float4)  btfloat84cmp(float8,float4),

	FUNCTION 2(float4,float4)  btfloat4sortsupport(internal),
	FUNCTION 2(float8,float8)  btfloat8sortsupport(internal),

    FUNCTION 3(float4,float8)  in_range(float4,float4,float8,bool,bool),
    FUNCTION 3(float8,float8)  in_range(float8,float8,float8,bool,bool);
-- Operator class to compare bool operands it use existing btree oprator function btboolcmp
CREATE OPERATOR CLASS bool_ops DEFAULT
	FOR TYPE bool USING lsm AS
	OPERATOR 1  <,
	OPERATOR 2  <=,
	OPERATOR 3  =,
	OPERATOR 4  >=,
	OPERATOR 5  >,
	FUNCTION 1  btboolcmp(bool,bool),
    FUNCTION 4  btequalimage(oid);
-- Operator class to compare bpchar operands it use exicting btree oprator function bpcharcmp
CREATE OPERATOR CLASS bpchar_ops DEFAULT
	FOR TYPE bpchar USING lsm AS
	OPERATOR 1  <,
	OPERATOR 2  <=,
	OPERATOR 3  =,
	OPERATOR 4  >=,
	OPERATOR 5  >,
	FUNCTION 1  bpcharcmp(bpchar,bpchar),
	FUNCTION 2  bpchar_sortsupport(internal),
    FUNCTION 4  btvarstrequalimage(oid);
-- Operator class to compare bytea operands it use exicting btree oprator function byteacmp
CREATE OPERATOR CLASS bytea_ops DEFAULT
	FOR TYPE bytea USING lsm AS
	OPERATOR 1  <,
	OPERATOR 2  <=,
	OPERATOR 3  =,
	OPERATOR 4  >=,
	OPERATOR 5  >,
	FUNCTION 1  byteacmp(bytea,bytea),
	FUNCTION 2  bytea_sortsupport(internal),
    FUNCTION 4  btequalimage(oid);
-- Operator class to compare char operands it use exicting btree oprator function btcharcmp
CREATE OPERATOR CLASS char_ops DEFAULT
	FOR TYPE "char" USING lsm AS
	OPERATOR 1  <,
	OPERATOR 2  <=,
	OPERATOR 3  =,
	OPERATOR 4  >=,
	OPERATOR 5  >,
	FUNCTION 1  btcharcmp("char","char"),
    FUNCTION 4  btequalimage(oid);
-- Operator family dor datetime operands
CREATE OPERATOR FAMILY datetime_ops USING lsm;
-- Operator class to compare date operands it use exicting btree oprator function datecmp
CREATE OPERATOR CLASS date_ops DEFAULT
	FOR TYPE date USING lsm FAMILY datetime_ops AS
	OPERATOR 1  <,
	OPERATOR 2  <=,
	OPERATOR 3  =,
	OPERATOR 4  >=,
	OPERATOR 5  >,
	FUNCTION 1  date_cmp(date,date),
	FUNCTION 2  date_sortsupport(internal),
    FUNCTION 4  btequalimage(oid);
-- Operator class to compare timestamp operands it use exicting btree oprator function timestamp_cmo
CREATE OPERATOR CLASS timestamp_ops DEFAULT
	FOR TYPE timestamp USING lsm FAMILY datetime_ops AS
	OPERATOR 1  <,
	OPERATOR 2  <=,
	OPERATOR 3  =,
	OPERATOR 4  >=,
	OPERATOR 5  >,
	FUNCTION 1  timestamp_cmp(timestamp,timestamp),
	FUNCTION 2  timestamp_sortsupport(internal),
    FUNCTION 4  btequalimage(oid);
-- Operator class to compare timestamptz operands it use exicting btree oprator function timestamptz_cmp
CREATE OPERATOR CLASS timestamptz_ops DEFAULT
	FOR TYPE timestamptz USING lsm FAMILY datetime_ops AS
	OPERATOR 1  <,
	OPERATOR 2  <=,
	OPERATOR 3  =,
	OPERATOR 4  >=,
	OPERATOR 5  >,
	FUNCTION 1  timestamptz_cmp(timestamptz,timestamptz),
	FUNCTION 2  timestamp_sortsupport(internal),
    FUNCTION 4  btequalimage(oid);
-- Operator family to compare date and timestamp
ALTER OPERATOR FAMILY datetime_ops USING lsm ADD
	OPERATOR 1  <  (date,timestamp),
	OPERATOR 2  <= (date,timestamp),
	OPERATOR 3  =  (date,timestamp),
	OPERATOR 4  >= (date,timestamp),
	OPERATOR 5  >  (date,timestamp),
	FUNCTION 1(date,timestamp)   date_cmp_timestamp(date,timestamp),

    OPERATOR 1  <  (date,timestamptz),
	OPERATOR 2  <= (date,timestamptz),
	OPERATOR 3  =  (date,timestamptz),
	OPERATOR 4  >= (date,timestamptz),
	OPERATOR 5  >  (date,timestamptz),
	FUNCTION 1(date,timestamptz) date_cmp_timestamptz(date,timestamptz),

	OPERATOR 1  <  (timestamp,date),
	OPERATOR 2  <= (timestamp,date),
	OPERATOR 3  =  (timestamp,date),
	OPERATOR 4  >= (timestamp,date),
	OPERATOR 5  >  (timestamp,date),
	FUNCTION 1(timestamp,date)   timestamp_cmp_date(timestamp,date),

	OPERATOR 1  <  (timestamptz,date),
	OPERATOR 2  <= (timestamptz,date),
	OPERATOR 3  =  (timestamptz,date),
	OPERATOR 4  >= (timestamptz,date),
	OPERATOR 5  >  (timestamptz,date),
	FUNCTION 1(timestamptz,date)   timestamptz_cmp_date(timestamptz,date),

	OPERATOR 1  <  (timestamp,timestamptz),
	OPERATOR 2  <= (timestamp,timestamptz),
	OPERATOR 3  =  (timestamp,timestamptz),
	OPERATOR 4  >= (timestamp,timestamptz),
	OPERATOR 5  >  (timestamp,timestamptz),
	FUNCTION 1(timestamp,timestamptz)   timestamp_cmp_timestamptz(timestamp,timestamptz),

	OPERATOR 1  <  (timestamptz,timestamp),
	OPERATOR 2  <= (timestamptz,timestamp),
	OPERATOR 3  =  (timestamptz,timestamp),
	OPERATOR 4  >= (timestamptz,timestamp),
	OPERATOR 5  >  (timestamptz,timestamp),
	FUNCTION 1(timestamptz,timestamp)   timestamptz_cmp_timestamp(timestamptz,timestamp),

    FUNCTION 3(date,interval) in_range(date,date,interval,bool,bool),
    FUNCTION 3(timestamp,interval) in_range(timestamp,timestamp,interval,bool,bool),
    FUNCTION 3(timestamptz,interval) in_range(timestamptz,timestamptz,interval,bool,bool);
-- Operator class to compare interval operands it use exicting btree oprator function interval_cmp
CREATE OPERATOR CLASS interval_ops DEFAULT
	FOR TYPE interval USING lsm AS
	OPERATOR 1  <,
	OPERATOR 2  <=,
	OPERATOR 3  =,
	OPERATOR 4  >=,
	OPERATOR 5  >,
	FUNCTION 1  interval_cmp(interval,interval),
    FUNCTION 3  in_range(interval,interval,interval,bool,bool),
    FUNCTION 4  btequalimage(oid);
-- Operator class to compare macaddr_cmp operands it use exicting btree oprator function macaddr_cmp
CREATE OPERATOR CLASS macaddr_ops DEFAULT
	FOR TYPE macaddr USING lsm AS
	OPERATOR 1  <,
	OPERATOR 2  <=,
	OPERATOR 3  =,
	OPERATOR 4  >=,
	OPERATOR 5  >,
	FUNCTION 1  macaddr_cmp(macaddr,macaddr),
	FUNCTION 2  macaddr_sortsupport(internal),
    FUNCTION 4  btequalimage(oid);
-- Operator class to compare numeric operands it use exicting btree oprator function numeric_cmp
CREATE OPERATOR CLASS numeric_ops DEFAULT
	FOR TYPE numeric USING lsm AS
	OPERATOR 1  <,
	OPERATOR 2  <=,
	OPERATOR 3  =,
	OPERATOR 4  >=,
	OPERATOR 5  >,
	FUNCTION 1  numeric_cmp(numeric,numeric),
	FUNCTION 2  numeric_sortsupport(internal),
    FUNCTION 3  in_range(numeric,numeric,numeric,bool,bool),
    FUNCTION 4  btequalimage(oid);
-- Operator class to compare oid_ops operands it use exicting btree oprator function btoidcmp
CREATE OPERATOR CLASS oid_ops DEFAULT
	FOR TYPE oid USING lsm AS
	OPERATOR 1  <,
	OPERATOR 2  <=,
	OPERATOR 3  =,
	OPERATOR 4  >=,
	OPERATOR 5  >,
	FUNCTION 1  btoidcmp(oid,oid),
	FUNCTION 2  btoidsortsupport(internal),
    FUNCTION 4  btequalimage(oid);
-- Operator family to compare text
CREATE OPERATOR FAMILY text_ops USING lsm;
-- Operator class to compare text operands it use exicting btree oprator function bttextcmp
CREATE OPERATOR CLASS text_ops DEFAULT
	FOR TYPE text USING lsm FAMILY text_ops AS
	OPERATOR 1  <,
	OPERATOR 2  <=,
	OPERATOR 3  =,
	OPERATOR 4  >=,
	OPERATOR 5  >,
	FUNCTION 1  bttextcmp(text,text),
	FUNCTION 2  bttextsortsupport(internal),
    FUNCTION 4  btvarstrequalimage(oid);

CREATE OPERATOR CLASS name_ops DEFAULT
	FOR TYPE name USING lsm FAMILY text_ops AS
	OPERATOR 1  <,
	OPERATOR 2  <=,
	OPERATOR 3  =,
	OPERATOR 4  >=,
	OPERATOR 5  >,
	FUNCTION 1  btnamecmp(name,name),
	FUNCTION 2  btnamesortsupport(internal),
    FUNCTION 4  btvarstrequalimage(oid);

ALTER OPERATOR FAMILY text_ops USING lsm ADD
	OPERATOR 1  <  (text,name),
	OPERATOR 2  <= (text,name),
	OPERATOR 3  =  (text,name),
	OPERATOR 4  >= (text,name),
	OPERATOR 5  >  (text,name),
	FUNCTION 1(text,name)   bttextnamecmp(text,name),

	OPERATOR 1  <  (name,text),
	OPERATOR 2  <= (name,text),
	OPERATOR 3  =  (name,text),
	OPERATOR 4  >= (name,text),
	OPERATOR 5  >  (name,text),
	FUNCTION 1(name,text)   btnametextcmp(name,text);

CREATE OPERATOR CLASS time_ops DEFAULT
	FOR TYPE time USING lsm AS
	OPERATOR 1  <,
	OPERATOR 2  <=,
	OPERATOR 3  =,
	OPERATOR 4  >=,
	OPERATOR 5  >,
	FUNCTION 1  time_cmp(time,time),
    FUNCTION 3  in_range(time,time,interval,bool,bool),
    FUNCTION 4  btequalimage(oid);

CREATE OPERATOR CLASS timetz_ops DEFAULT
	FOR TYPE timetz USING lsm AS
	OPERATOR 1  <,
	OPERATOR 2  <=,
	OPERATOR 3  =,
	OPERATOR 4  >=,
	OPERATOR 5  >,
	FUNCTION 1  timetz_cmp(timetz,timetz),
    FUNCTION 3  in_range(timetz,timetz,interval,bool,bool),
    FUNCTION 4  btequalimage(oid);

CREATE OPERATOR CLASS money_ops DEFAULT
	FOR TYPE money USING lsm AS
	OPERATOR 1  <,
	OPERATOR 2  <=,
	OPERATOR 3  =,
	OPERATOR 4  >=,
	OPERATOR 5  >,
	FUNCTION 1  cash_cmp(money,money),
    FUNCTION 4  btequalimage(oid);

CREATE OPERATOR CLASS uuid_ops DEFAULT
	FOR TYPE uuid USING lsm AS
	OPERATOR 1  <,
	OPERATOR 2  <=,
	OPERATOR 3  =,
	OPERATOR 4  >=,
	OPERATOR 5  >,
	FUNCTION 1  uuid_cmp(uuid,uuid),
	FUNCTION 2  uuid_sortsupport(internal),
    FUNCTION 4  btequalimage(oid);


